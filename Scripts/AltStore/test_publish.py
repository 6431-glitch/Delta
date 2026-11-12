"""Exercise publication ordering, immutability, failures and temporary-file cleanup."""
import base64
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import publish


class PublishingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.ipa = Path(self.temp.name) / 'XcodeExport.ipa'; self.ipa.write_bytes(b'fixture')
        self.metadata = {'version': '1.1.1', 'buildVersion': '10', 'minOSVersion': '26.0',
                         'size': 7, 'sha256': 'a' * 64,
                         'appPermissions': {'entitlements': [], 'privacy': {}}}
        self.source = {'name': 'Apps', 'apps': [], 'news': []}
        self.release = None; self.calls = []; self.payload = None; self.staging = None
        self.fail_upload = False; self.fail_catalog = False; self.uploaded = False
        self.environment = patch.dict(os.environ, {'GH_TOKEN': 'fixture-secret'})
        self.environment.start(); self.addCleanup(self.environment.stop)
        self.inspect = patch.object(publish, 'inspect_ipa', return_value=self.metadata)
        self.inspect.start(); self.addCleanup(self.inspect.stop)
        self.mock_gh = patch.object(publish, 'gh', side_effect=self.gh)
        self.mock_gh.start(); self.addCleanup(self.mock_gh.stop)

    def gh(self, *args, input_text=None):
        self.calls.append(args)
        if args[0] == 'api' and 'contents/source.json' in args[1]:
            if '--method' in args:
                if self.fail_catalog: raise RuntimeError('catalog conflict')
                self.payload = json.loads(input_text)
                return '{}'
            return json.dumps({'sha': 'old-sha', 'content': base64.b64encode(json.dumps(self.source).encode()).decode()})
        if args[0] == 'api' and '--paginate' in args:
            draft = {'tag_name': 'epsilon-v1.1.1-build.10', 'draft': True,
                     'assets': [{'name': 'Epsilon.ipa', 'size': 7,
                                 'digest': 'sha256:' + 'a' * 64}, {'name': 'SHA256SUMS'}]}
            return json.dumps([[draft] if self.uploaded else ([self.release] if self.release else [])])
        if args[:2] == ('release', 'upload'):
            self.staging = Path(args[3]).parent
            self.assertEqual(Path(args[3]).name, 'Epsilon.ipa')
            self.assertEqual(Path(args[3]).read_bytes(), b'fixture')
            if self.fail_upload: raise RuntimeError('upload failed')
            self.uploaded = True
        if args[0] == 'api' and '/releases/tags/' in args[1]:
            raise RuntimeError('GitHub does not return drafts by tag')
        if args[0] == 'api' and 'Accept: application/octet-stream' in args:
            return self.metadata['sha256'] + '  Epsilon.ipa\n'
        return ''

    def test_asset_upload_and_release_publication_precede_catalog_write(self):
        publish.publish(self.ipa)
        actions = [(c[0], c[1]) for c in self.calls]
        self.assertLess(actions.index(('release', 'upload')), actions.index(('release', 'edit')))
        self.assertEqual(self.calls[-1][0], 'api')
        self.assertIn('--method', self.calls[-1])
        updated = json.loads(base64.b64decode(self.payload['content']))
        self.assertEqual(updated['apps'][0]['versions'][0]['size'], 7)
        self.assertEqual(self.payload['sha'], 'old-sha')
        self.assertFalse(self.staging.exists())
        self.assertTrue(self.ipa.exists())

    def test_upload_failure_never_publishes_release_or_catalog_and_cleans_files(self):
        self.fail_upload = True
        with self.assertRaises(RuntimeError): publish.publish(self.ipa)
        self.assertFalse(any(c[:2] == ('release', 'edit') for c in self.calls))
        self.assertIsNone(self.payload)
        self.assertFalse(self.staging.exists())

    def test_catalog_conflict_preserves_public_release_for_retry(self):
        self.fail_catalog = True
        with self.assertRaises(RuntimeError): publish.publish(self.ipa)
        self.assertTrue(any(c[:2] == ('release', 'edit') for c in self.calls))
        self.assertFalse(self.staging.exists())
        self.assertFalse(any(c[:2] == ('release', 'delete') for c in self.calls))

    def existing_release(self):
        self.release = {'tag_name': 'epsilon-v1.1.1-build.10', 'draft': False,
                        'assets': [{'name': 'Epsilon.ipa', 'size': 7, 'digest': 'sha256:' + 'a' * 64}, {'name': 'SHA256SUMS', 'id': 42}]}

    def test_identical_public_release_is_reused_without_replacing_assets(self):
        self.existing_release()
        publish.publish(self.ipa)
        self.assertFalse(any(c[0] == 'release' for c in self.calls))
        self.assertIsNotNone(self.payload)

    def test_changed_ipa_for_public_release_fails_without_catalog_mutation(self):
        self.existing_release()
        self.release['assets'][0]['size'] = 999
        with self.assertRaisesRegex(ValueError, 'conflicting'): publish.publish(self.ipa)
        self.assertIsNone(self.payload)
        self.assertFalse(any(c[0] == 'release' for c in self.calls))

    def test_same_size_but_wrong_server_digest_blocks_catalog_update(self):
        self.existing_release()
        self.release['assets'][0]['digest'] = 'sha256:' + 'b' * 64
        with self.assertRaisesRegex(ValueError, 'conflicting'): publish.publish(self.ipa)
        self.assertIsNone(self.payload)
        self.assertFalse(any(c[0] == 'release' for c in self.calls))

    def test_draft_digest_mismatch_never_publishes_release_or_catalog(self):
        self.mock_gh.stop()
        original = self.gh
        def wrong_digest(*args, **kwargs):
            value = original(*args, **kwargs)
            if args[0] == 'api' and '--paginate' in args and self.uploaded:
                result = json.loads(value)
                result[0][0]['assets'][0]['digest'] = 'sha256:' + 'b' * 64
                return json.dumps(result)
            return value
        with patch.object(publish, 'gh', side_effect=wrong_digest):
            with self.assertRaisesRegex(ValueError, 'Draft asset verification failed'):
                publish.publish(self.ipa)
        self.assertIsNone(self.payload)
        self.assertFalse(any(c[:2] == ('release', 'edit') for c in self.calls))
        self.assertFalse(self.staging.exists())

    def test_checksum_mismatch_fails_without_replacing_public_assets(self):
        self.existing_release()
        original = self.gh
        def changed_checksum(*args, **kwargs):
            if 'Accept: application/octet-stream' in args: return 'different checksum'
            return original(*args, **kwargs)
        self.mock_gh.stop()
        with patch.object(publish, 'gh', side_effect=changed_checksum):
            with self.assertRaisesRegex(ValueError, 'checksum differs'): publish.publish(self.ipa)
        self.assertIsNone(self.payload)

    def test_missing_token_aborts_before_ipa_inspection_or_network(self):
        with patch.dict(os.environ, {'GH_TOKEN': ''}):
            with self.assertRaisesRegex(ValueError, 'Missing ALTSTORE'): publish.publish(self.ipa)
        self.assertEqual(self.calls, [])

    def test_existing_draft_can_be_repaired(self):
        self.release = {'tag_name': 'epsilon-v1.1.1-build.10', 'draft': True, 'assets': []}
        publish.publish(self.ipa)
        self.assertFalse(any(c[:2] == ('release', 'create') for c in self.calls))
        self.assertTrue(any(c[:2] == ('release', 'upload') for c in self.calls))

    def test_failed_draft_lookup_reports_operation_and_http_without_secret(self):
        self.mock_gh.stop()
        import subprocess
        response = subprocess.CompletedProcess([], 1, '', 'HTTP 404: fixture-secret')
        with patch.object(publish.subprocess, 'run', return_value=response):
            with self.assertRaises(RuntimeError) as error:
                publish.find_release('epsilon-v1.1.1-build.10')
        self.assertIn('listing releases', str(error.exception))
        self.assertIn('HTTP 404', str(error.exception))
        self.assertNotIn('fixture-secret', str(error.exception))

    def test_missing_uploaded_draft_does_not_publish(self):
        self.mock_gh.stop()
        original = self.gh
        def missing_draft(*args, **kwargs):
            value = original(*args, **kwargs)
            if args[0] == 'api' and '--paginate' in args and self.uploaded:
                return '[[]]'
            return value
        with patch.object(publish, 'gh', side_effect=missing_draft):
            with self.assertRaisesRegex(ValueError, 'draft release is unavailable'):
                publish.publish(self.ipa)
        self.assertIsNone(self.payload)
        self.assertFalse(any(c[:2] == ('release', 'edit') for c in self.calls))
        self.assertFalse(self.staging.exists())

    def test_github_error_does_not_echo_credentials(self):
        self.mock_gh.stop()
        import subprocess
        with patch.object(publish.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, '', 'fixture-secret')):
            with self.assertRaises(RuntimeError) as error: publish.gh('api', 'anything')
        self.assertNotIn('fixture-secret', str(error.exception))


if __name__ == '__main__':
    unittest.main()
