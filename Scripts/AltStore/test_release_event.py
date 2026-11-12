import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from release_event import associated_pulls, main, should_deploy


class ReleaseEventTests(unittest.TestCase):
    sha = 'a' * 40
    repository = 'owner/reader'
    def pull(self, **changes):
        value = dict(merged_at='2026-10-26T10:00:00Z', state='closed', merge_commit_sha=self.sha,
                     base={'ref': 'main', 'repo': {'full_name': self.repository}})
        return dict(value, **changes)
    def allowed(self, pulls, event='push', ref='refs/heads/main', payload=None):
        return should_deploy(event, ref, self.sha, payload or {'after': self.sha}, self.repository, lambda: pulls, wait=lambda _: None)
    def test_merged_pr_deploys_with_release_execution_ref(self):
        self.assertTrue(self.allowed([self.pull()]))
    def test_direct_push_unmerged_closed_wrong_sha_base_and_repository_skip(self):
        for pulls in [[], [self.pull(merged_at=None)], [self.pull(state='open')], [self.pull(merge_commit_sha='b' * 40)],
                      [self.pull(base={'ref': 'release/1.1.1', 'repo': {'full_name': self.repository}})],
                      [self.pull(base={'ref': 'release/1.1.1', 'repo': {'full_name': 'different/repo'}})]]:
            with self.subTest(pulls=pulls): self.assertFalse(self.allowed(pulls))
    def test_nonrelease_pr_refs_deleted_and_mismatched_pushes_skip(self):
        for ref in ['refs/heads/development', 'refs/pull/34/merge', 'refs/tags/release/1.1.1', 'refs/heads/release/']:
            self.assertFalse(self.allowed([self.pull()], ref=ref))
        self.assertFalse(self.allowed([self.pull()], payload={'after': self.sha, 'deleted': True}))
        self.assertFalse(self.allowed([self.pull()], payload={'after': 'b' * 40}))
        self.assertFalse(self.allowed([self.pull()], event='pull_request'))
    def test_manual_dispatch_requires_release_ref_and_does_not_query_api(self):
        def unavailable(): raise AssertionError('Manual dispatch must not query associated PRs')
        self.assertTrue(should_deploy('workflow_dispatch', 'refs/heads/main', self.sha, {}, self.repository, unavailable))
        self.assertFalse(self.allowed([], event='workflow_dispatch', ref='refs/heads/development'))
    def test_association_delay_is_retried_and_api_failure_aborts(self):
        values = iter([[], [self.pull()]])
        self.assertTrue(should_deploy('push', 'refs/heads/main', self.sha, {'after': self.sha}, self.repository, lambda: next(values), wait=lambda _: None))
        def failed(): raise OSError('GitHub unavailable')
        with self.assertRaises(OSError):
            should_deploy('push', 'refs/heads/main', self.sha, {'after': self.sha}, self.repository, failed)
    def test_paginated_associations_and_authentication(self):
        with patch('release_event.urlopen') as request:
            request.return_value.__enter__.return_value.read.side_effect = [json.dumps([{}] * 100).encode(), b'[]']
            self.assertEqual(len(list(associated_pulls(self.repository, self.sha, 'fixture-token', 'https://api.github.com'))), 100)
            self.assertEqual(request.call_count, 2)
            self.assertEqual(request.call_args_list[0].args[0].get_header('Authorization'), 'Bearer fixture-token')
            self.assertIn('page=2', request.call_args_list[1].args[0].full_url)

    def test_main_writes_job_output_without_api_lookup_for_manual_release(self):
        with tempfile.TemporaryDirectory() as folder:
            event, output = Path(folder) / 'event.json', Path(folder) / 'output'
            event.write_text('{}')
            env = {'GITHUB_EVENT_NAME': 'workflow_dispatch', 'GITHUB_REF': 'refs/heads/main',
                   'GITHUB_SHA': self.sha, 'GITHUB_REPOSITORY': self.repository,
                   'GITHUB_EVENT_PATH': str(event), 'GITHUB_OUTPUT': str(output)}
            with patch.dict(os.environ, env, clear=True), patch('release_event.associated_pulls') as lookup:
                main(); lookup.assert_not_called()
            self.assertEqual(output.read_text(), 'deploy=true\n')
