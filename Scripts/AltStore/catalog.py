#!/usr/bin/env python3
"""Build AltStore Classic metadata from the exact exported app and extensions."""
import copy
import datetime as dt
import hashlib
import plistlib
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile

REPO = '6431-glitch/altrepo'
BASE = 'https://6431-glitch.github.io/altrepo'
BUNDLE = 'page.ducnguyen.Delta'
DEFAULT_ENTITLEMENTS = {'application-identifier', 'com.apple.developer.team-identifier'}


def read_plist(path):
    with path.open('rb') as handle:
        return plistlib.load(handle)


def signed_entitlements(app):
    result = subprocess.run(['codesign', '-d', '--entitlements', ':-', str(app)],
                            capture_output=True, check=True)
    return plistlib.loads(result.stdout)


def app_metadata(app, entitlements_reader=signed_entitlements):
    info = read_plist(app / 'Info.plist')
    if info.get('CFBundleIdentifier') != BUNDLE:
        raise ValueError('Unexpected IPA bundle identifier.')
    metadata = {}
    for source, target in [('CFBundleShortVersionString', 'version'),
                           ('CFBundleVersion', 'buildVersion'), ('MinimumOSVersion', 'minOSVersion')]:
        value = info.get(source)
        if not isinstance(value, str) or not re.fullmatch(r'[0-9]+(?:\.[0-9]+){0,2}', value):
            raise ValueError(f'Invalid or missing IPA field: {source}')
        metadata[target] = value
    entitlements, privacy = set(), {}
    for executable in [app, *sorted((app / 'PlugIns').glob('*.appex'))]:
        for key in entitlements_reader(executable):
            if key not in DEFAULT_ENTITLEMENTS:
                entitlements.add(key)
        for key, value in read_plist(executable / 'Info.plist').items():
            if key.startswith('NS') and key.endswith('UsageDescription'):
                if not isinstance(value, str) or not value.strip():
                    raise ValueError(f'Empty privacy description: {key}')
                if key in privacy and privacy[key] != value:
                    raise ValueError(f'Conflicting privacy description across targets: {key}')
                privacy[key] = value
    metadata['appPermissions'] = {'entitlements': sorted(entitlements), 'privacy': privacy}
    return metadata


def inspect_ipa(ipa):
    with tempfile.TemporaryDirectory(prefix='epsilon-ipa-') as directory:
        root = Path(directory)
        with zipfile.ZipFile(ipa) as archive:
            for member in archive.infolist():
                path = Path(member.filename)
                if path.is_absolute() or '..' in path.parts or '\\' in member.filename:
                    raise ValueError('Unsafe path in IPA archive.')
                # zipfile extracts symlink payloads as ordinary files; reject them explicitly.
                if (member.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError('Unexpected symbolic link in IPA archive.')
            archive.extractall(root)
        apps = list((root / 'Payload').glob('*.app'))
        if len(apps) != 1:
            raise ValueError('IPA must contain exactly one app in Payload.')
        metadata = app_metadata(apps[0])
    metadata['size'] = ipa.stat().st_size
    with ipa.open('rb') as handle:
        digest = hashlib.sha256()
        for chunk in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(chunk)
        metadata['sha256'] = digest.hexdigest()
    return metadata


def tag_for(metadata):
    return f"epsilon-v{metadata['version']}-build.{metadata['buildVersion']}"


def update_source(source, metadata, now=None):
    source = copy.deepcopy(source)
    tag = tag_for(metadata)
    version = {key: metadata[key] for key in ['version', 'buildVersion', 'minOSVersion', 'size']}
    version.update(date=now or dt.datetime.now(dt.timezone.utc).isoformat(),
                   downloadURL=f'https://github.com/{REPO}/releases/download/{tag}/Epsilon.ipa',
                   localizedDescription=f"Epsilon {metadata['version']} ({metadata['buildVersion']}).")
    apps = source.setdefault('apps', [])
    matching = [app for app in apps if app.get('bundleIdentifier') == BUNDLE]
    if len(matching) > 1:
        raise ValueError('Duplicate Epsilon catalog entries.')
    app = matching[0] if matching else {'name': 'Epsilon', 'bundleIdentifier': BUNDLE,
        'developerName': 'Duc Nguyen', 'subtitle': 'A home for your games.',
        'localizedDescription': 'Epsilon is based on Delta, created by Riley Testut and the Delta contributors.',
        'iconURL': 'https://raw.githubusercontent.com/6431-glitch/Delta/main/Resources/AppIcon.icon/Assets/epsilon.png', 'tintColor': '#7649d6', 'category': 'entertainment',
        'versions': []}
    previous = app.get('versions', [])
    identity = (metadata['version'], metadata['buildVersion'])
    if previous:
        newest = previous[0]
        number = lambda text: tuple(int(part) for part in text.split('.')) + (0,) * (3 - len(text.split('.')))
        if number(metadata['buildVersion']) < number(newest['buildVersion']):
            raise ValueError('Refusing to publish an older build over the newest catalog entry.')
        for old in previous:
            if (old['version'], old.get('buildVersion')) == identity:
                if old['downloadURL'] != version['downloadURL'] or old['size'] != version['size']:
                    raise ValueError('Conflicting metadata for an existing catalog version.')
                version['date'] = old['date']
    app['versions'] = [version] + [old for old in previous
        if (old['version'], old.get('buildVersion')) != identity]
    # Older versions may request different permissions; AltStore validates any selected IPA.
    existing = app.get('appPermissions', {})
    privacy = dict(existing.get('privacy', {}))
    privacy.update(metadata['appPermissions']['privacy'])
    app['appPermissions'] = {
        'entitlements': sorted(set(existing.get('entitlements', [])) | set(metadata['appPermissions']['entitlements'])),
        'privacy': privacy}
    if not matching:
        apps.append(app)
    return source
