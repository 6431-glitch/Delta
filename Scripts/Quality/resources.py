#!/usr/bin/env python3
"""Check skin assets; optionally hydrate known public LFS objects without installing a client."""
import argparse
import hashlib
import json
from pathlib import Path
import urllib.request
import urllib.parse

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--hydrate', action='store_true', help='Download and verify known public controller skins')
args = parser.parse_args()
repositories = {'NESDeltaCore': 'rileytestut/NESDeltaCore', 'MelonDSDeltaCore': 'rileytestut/MelonDSDeltaCore'}
missing = []
for path in (root / 'Cores').rglob('*.deltaskin'):
    with path.open('rb') as file:
        pointer = file.read(1024)
    if not pointer.startswith(b'version https://git-lfs.github.com/spec/v1'):
        continue
    if args.hydrate:
        core = path.relative_to(root / 'Cores').parts[0]
        if core not in repositories:
            raise SystemExit('No public LFS source configured for ' + str(path.relative_to(root)))
        metadata = dict(line.split(' ', 1) for line in pointer.decode().strip().splitlines())
        algorithm, oid = metadata['oid'].split(':', 1)
        size = int(metadata['size'])
        if algorithm != 'sha256' or size <= 0 or size > 64 * 1024 * 1024:
            raise SystemExit('Unsupported LFS asset identity/size')
        endpoint = 'https://github.com/' + repositories[core] + '.git/info/lfs/objects/batch'
        request = urllib.request.Request(endpoint, data=json.dumps({'operation': 'download', 'transfers': ['basic'], 'objects': [{'oid': oid, 'size': size}]}).encode(), headers={'Content-Type': 'application/vnd.git-lfs+json', 'Accept': 'application/vnd.git-lfs+json'})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                objects = json.load(response)['objects']
            item = next(item for item in objects if item['oid'] == oid)
            action = item['actions']['download']
            if urllib.parse.urlparse(action['href']).scheme != 'https':
                raise ValueError('Non-HTTPS LFS response')
            request = urllib.request.Request(action['href'], headers=action.get('header', {}))
            with urllib.request.urlopen(request, timeout=30) as response:
                content = response.read(size + 1)
            if len(content) != size or hashlib.sha256(content).hexdigest() != oid:
                raise ValueError('LFS identity mismatch')
            backup = root / '.build/quality-lfs-pointers' / core
            backup.parent.mkdir(parents=True, exist_ok=True)
            if not backup.exists(): backup.write_bytes(pointer)
            path.write_bytes(content)
            print('Hydrated verified public skin: ' + str(path.relative_to(root)), flush=True)
        except Exception as error:
            # Signed LFS download URLs/tokens must never be included in diagnostics.
            raise SystemExit('LFS hydration failed for ' + core + ': ' + type(error).__name__) from None
    else:
        missing.append(str(path.relative_to(root)))
if missing:
    raise SystemExit('Unhydrated Git LFS skins (run resources.py --hydrate or pull with Git LFS):\n' + '\n'.join(missing))
print('Controller skin resources are hydrated.')
