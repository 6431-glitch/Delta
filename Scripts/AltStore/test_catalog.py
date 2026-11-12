"""Offline metadata tests; no signing keys, Apple access or GitHub writes."""
import copy
import json
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import catalog


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.app = self.root / 'Payload/Epsilon.app'
        self.app.mkdir(parents=True)
        self.info = {'CFBundleIdentifier': catalog.BUNDLE, 'CFBundleShortVersionString': '1.1.1',
                     'CFBundleVersion': '10', 'MinimumOSVersion': '26.0',
                     'NSLocalNetworkUsageDescription': 'Transfer comics to nearby friends.'}
        self.write_info(self.app, self.info)
        self.metadata = {'version': '1.1.1', 'buildVersion': '10', 'minOSVersion': '26.0',
                         'size': 123, 'sha256': 'a' * 64,
                         'appPermissions': {'entitlements': ['com.apple.security.application-groups'],
                                            'privacy': {'NSLocalNetworkUsageDescription': 'Transfer comics.'}}}

    def write_info(self, app, info):
        app.mkdir(parents=True, exist_ok=True)
        (app / 'Info.plist').write_bytes(plistlib.dumps(info))

    def test_metadata_includes_extension_permissions_and_exact_versions(self):
        extension = self.app / 'PlugIns/Share.appex'
        self.write_info(extension, {'NSCameraUsageDescription': 'Scan a code.'})
        def entitlements(app):
            return {'application-identifier': 'TEAM.bundle',
                    'com.apple.developer.team-identifier': 'TEAM',
                    'com.apple.security.application-groups': ['group.example'],
                    **({'keychain-access-groups': ['group.keychain']} if app == extension else {})}
        result = catalog.app_metadata(self.app, entitlements)
        self.assertEqual(result['version'], '1.1.1')
        self.assertEqual(result['buildVersion'], '10')
        self.assertEqual(result['minOSVersion'], '26.0')
        self.assertEqual(result['appPermissions']['entitlements'],
                         ['com.apple.security.application-groups', 'keychain-access-groups'])
        self.assertEqual(result['appPermissions']['privacy']['NSCameraUsageDescription'], 'Scan a code.')

    def test_rejects_wrong_app_invalid_version_and_conflicting_privacy(self):
        for field, value in [('CFBundleIdentifier', 'other.app'), ('CFBundleVersion', 'bad/build'),
                             ('MinimumOSVersion', ''), ('CFBundleShortVersionString', 1)]:
            with self.subTest(field=field):
                self.write_info(self.app, dict(self.info, **{field: value}))
                with self.assertRaises(ValueError):
                    catalog.app_metadata(self.app, lambda _: {})
        self.write_info(self.app, self.info)
        self.write_info(self.app / 'PlugIns/Share.appex', {'NSLocalNetworkUsageDescription': 'Different reason.'})
        with self.assertRaisesRegex(ValueError, 'Conflicting privacy'):
            catalog.app_metadata(self.app, lambda _: {})

    def test_safe_zip_metadata_is_inspected_and_temporary_extraction_removed(self):
        ipa = self.root / 'app.ipa'
        with zipfile.ZipFile(ipa, 'w') as archive:
            archive.write(self.app / 'Info.plist', 'Payload/Epsilon.app/Info.plist')
        extracted = []
        def inspect(app):
            extracted.append(app)
            return copy.deepcopy(self.metadata)
        with patch.object(catalog, 'app_metadata', side_effect=inspect):
            metadata = catalog.inspect_ipa(ipa)
        self.assertEqual(metadata['size'], ipa.stat().st_size)
        self.assertEqual(len(metadata['sha256']), 64)
        self.assertFalse(extracted[0].exists())

    def test_rejects_traversal_symlinks_and_multiple_apps(self):
        for filename in ['../escape', '/tmp/escape', 'Payload\\escape']:
            ipa = self.root / 'unsafe.ipa'
            with zipfile.ZipFile(ipa, 'w') as archive:
                archive.writestr(filename, b'unsafe')
            with self.assertRaisesRegex(ValueError, 'Unsafe path'):
                catalog.inspect_ipa(ipa)
        with zipfile.ZipFile(ipa, 'w') as archive:
            link = zipfile.ZipInfo('Payload/link'); link.external_attr = 0o120777 << 16
            archive.writestr(link, b'/tmp')
        with self.assertRaisesRegex(ValueError, 'symbolic link'):
            catalog.inspect_ipa(ipa)
        with zipfile.ZipFile(ipa, 'w') as archive:
            archive.writestr('Payload/A.app/Info.plist', plistlib.dumps(self.info))
            archive.writestr('Payload/B.app/Info.plist', plistlib.dumps(self.info))
        with self.assertRaisesRegex(ValueError, 'exactly one app'):
            catalog.inspect_ipa(ipa)

    def test_catalog_creates_exact_asset_url_size_and_permissions(self):
        source = {'name': 'Apps', 'apps': [], 'news': []}
        updated = catalog.update_source(source, self.metadata, '2026-10-27T10:00:00Z')
        app = updated['apps'][0]; version = app['versions'][0]
        self.assertEqual(version['downloadURL'], 'https://github.com/6431-glitch/altrepo/releases/download/epsilon-v1.1.1-build.10/Epsilon.ipa')
        self.assertEqual(version['size'], 123)
        self.assertEqual(app['appPermissions'], self.metadata['appPermissions'])
        self.assertEqual(source['apps'], [])
        self.assertEqual(catalog.update_source(updated, self.metadata), updated)
        self.assertNotIn('marketplaceID', app)

    def test_update_preserves_history_other_apps_and_permission_union(self):
        source = catalog.update_source({'apps': [{'bundleIdentifier': 'other.app'}]}, self.metadata)
        new = copy.deepcopy(self.metadata); new['buildVersion'] = '11'
        new['appPermissions'] = {'entitlements': ['other-entitlement'], 'privacy': {}}
        updated = catalog.update_source(source, new)
        app = updated['apps'][1]
        self.assertEqual([v['buildVersion'] for v in app['versions']], ['11', '10'])
        self.assertIn('com.apple.security.application-groups', app['appPermissions']['entitlements'])
        self.assertIn('NSLocalNetworkUsageDescription', app['appPermissions']['privacy'])
        self.assertEqual(updated['apps'][0], {'bundleIdentifier': 'other.app'})

    def test_rejects_older_build_duplicate_app_and_existing_version_conflict(self):
        source = catalog.update_source({'apps': []}, self.metadata)
        older = dict(self.metadata, buildVersion='9')
        with self.assertRaisesRegex(ValueError, 'older build'):
            catalog.update_source(source, older)
        with self.assertRaisesRegex(ValueError, 'Conflicting metadata'):
            catalog.update_source(source, dict(self.metadata, size=456))
        source['apps'].append(copy.deepcopy(source['apps'][0]))
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            catalog.update_source(source, self.metadata)


if __name__ == '__main__':
    unittest.main()
