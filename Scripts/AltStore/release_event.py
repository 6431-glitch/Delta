#!/usr/bin/env python3
"""Run deployment in a release branch context, without treating direct pushes as releases."""
import json
import os
from pathlib import Path
import re
import time
from urllib.request import Request, urlopen


def associated_pulls(repository, sha, token, api_url):
    for page in range(1, 21):
        request = Request(f'{api_url}/repos/{repository}/commits/{sha}/pulls?per_page=100&page={page}', headers={
            'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
        })
        with urlopen(request, timeout=30) as response:
            values = json.load(response)
        if not isinstance(values, list):
            raise ValueError('Expected a list of associated pull requests')
        yield from values
        if len(values) < 100:
            return
    raise ValueError('Too many associated pull requests to verify safely')


def should_deploy(event_name, ref, sha, event, repository, lookup, wait=time.sleep):
    prefix = 'refs/heads/'
    if ref != prefix + 'main' or not re.fullmatch(r'[0-9a-f]{40}', sha):
        return False
    if event_name == 'workflow_dispatch':
        return True
    if event_name != 'push' or event.get('deleted') or event.get('after') != sha:
        return False
    for attempt in range(3):
        for pull in lookup():
            base = pull.get('base', {})
            if (pull.get('merged_at') and pull.get('state') == 'closed'
                    and pull.get('merge_commit_sha') == sha and base.get('ref') == ref[len(prefix):]
                    and base.get('repo', {}).get('full_name') == repository):
                return True
        if attempt < 2:
            wait(2 ** attempt)  # Allow GitHub's commit/PR association to catch up with the push event.
    return False


def main():
    repository, sha = os.environ['GITHUB_REPOSITORY'], os.environ['GITHUB_SHA']
    event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text())
    allowed = should_deploy(os.environ['GITHUB_EVENT_NAME'], os.environ['GITHUB_REF'], sha, event, repository,
        lambda: associated_pulls(repository, sha, os.environ['GH_TOKEN'], os.environ['GITHUB_API_URL']))
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write(f'deploy={str(allowed).lower()}\n')
    print('Merged main PR or explicit main dispatch verified.' if allowed else 'No merged PR at this main tip; deployment skipped.')


if __name__ == '__main__':
    main()
