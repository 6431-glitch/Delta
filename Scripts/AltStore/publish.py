#!/usr/bin/env python3
"""Publish public IPA assets before atomically updating the cross-repo catalog."""
import base64
import json
import os
import re
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile

from catalog import REPO, inspect_ipa, tag_for, update_source


def gh(*args, input_text=None):
    result = subprocess.run(['gh', *args], input=input_text, text=True, capture_output=True)
    if result.returncode:
        # Report a bounded operation label and HTTP status, never CLI output or arguments.
        if args[:2] == ('release', 'create'):
            operation = 'creating the draft release'
        elif args[:2] == ('release', 'upload'):
            operation = 'uploading draft assets'
        elif args[:2] == ('release', 'edit'):
            operation = 'publishing the verified release'
        elif args and args[0] == 'api' and '--paginate' in args:
            operation = 'listing releases'
        elif args and args[0] == 'api' and '--method' in args:
            operation = 'updating the catalog'
        else:
            operation = 'reading GitHub repository data'
        status = re.search(r'\bHTTP (\d{3})\b', result.stderr)
        detail = f' (HTTP {status.group(1)})' if status else ''
        raise RuntimeError(f'GitHub publishing failed while {operation}{detail}. '
                           'Check repository access and network; credentials are never logged.')
    return result.stdout


def find_release(tag):
    # GitHub's /releases/tags endpoint does not return drafts; authenticated listing does.
    pages = json.loads(gh('api', '--paginate', '--slurp', f'repos/{REPO}/releases?per_page=100'))
    return next((item for page in pages for item in page if item['tag_name'] == tag), None)


def api(path, **payload):
    args = ['api', f'repos/{REPO}/{path}']
    if payload:
        args += ['--method', 'PUT', '--input', '-']
    return json.loads(gh(*args, input_text=json.dumps(payload) if payload else None))


def publish(ipa):
    if not os.environ.get('GH_TOKEN'):
        raise ValueError('Missing ALTSTORE_PUBLISH_TOKEN (passed as GH_TOKEN).')
    metadata = inspect_ipa(ipa)
    tag = tag_for(metadata)
    # Verify catalog/read permission and validate ordering before publishing any release.
    catalog = api('contents/source.json?ref=main')
    source = json.loads(base64.b64decode(catalog['content']))
    updated = update_source(source, metadata)
    release = find_release(tag)
    checksum = metadata['sha256'] + '  Epsilon.ipa\n'
    with tempfile.TemporaryDirectory(prefix='epsilon-publish-') as directory:
        root = Path(directory)
        if release and not release['draft']:
            assets = {asset['name']: asset for asset in release['assets']}
            if (assets.get('Epsilon.ipa', {}).get('size') != metadata['size']
                    or assets.get('Epsilon.ipa', {}).get('digest') != 'sha256:' + metadata['sha256']
                    or 'SHA256SUMS' not in assets):
                raise ValueError('Existing release has conflicting or missing assets; use a new build number.')
            remote_checksum = gh('api', '-H', 'Accept: application/octet-stream',
                                 f"repos/{REPO}/releases/assets/{assets['SHA256SUMS']['id']}")
            if remote_checksum != checksum:
                raise ValueError('Existing release checksum differs; released assets are immutable. Use a new build number.')
        else:
            if not release:
                gh('release', 'create', tag, '--repo', REPO, '--target', 'main', '--draft',
                   '--title', f"Epsilon {metadata['version']} ({metadata['buildVersion']})",
                   '--notes', 'AltStore Classic sideload release. Re-sign with your own Apple account using AltStore. Requires iOS ' + metadata['minOSVersion'] + ' or later.')
            asset = root / 'Epsilon.ipa'
            try:
                os.link(ipa, asset)
            except OSError:
                shutil.copyfile(ipa, asset)
            sums = root / 'SHA256SUMS'
            sums.write_text(checksum)
            # The public release is immutable; clobber is used only while repairing our draft.
            gh('release', 'upload', tag, str(asset), str(sums),
               '--repo', REPO, '--clobber')
            draft = find_release(tag)
            if not draft or not draft.get('draft'):
                raise ValueError('Uploaded draft release is unavailable; catalog was not changed.')
            assets = {asset['name']: asset for asset in draft['assets']}
            if (assets.get('Epsilon.ipa', {}).get('size') != metadata['size']
                    or assets.get('Epsilon.ipa', {}).get('digest') != 'sha256:' + metadata['sha256']
                    or 'SHA256SUMS' not in assets):
                raise ValueError('Draft asset verification failed; catalog was not changed.')
            gh('release', 'edit', tag, '--repo', REPO, '--draft=false', '--latest=false')
        if updated != source:
            api('contents/source.json', message=f'Publish Epsilon {tag}',
                content=base64.b64encode((json.dumps(updated, indent=2) + '\n').encode()).decode(),
                sha=catalog['sha'], branch='main')
    print(f'AltStore published: https://github.com/{REPO}/releases/tag/{tag}')
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as handle:
            handle.write(f'\n### AltStore Classic published\nRelease: https://github.com/{REPO}/releases/tag/{tag}\nSource: https://6431-glitch.github.io/altrepo/source.json\n')


if __name__ == '__main__':
    try:
        export = Path(sys.argv[1])
        ipas = list(export.glob('*.ipa'))
        if len(ipas) != 1:
            raise ValueError('Expected exactly one IPA in the AltStore export directory.')
        publish(ipas[0])
    except (ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
