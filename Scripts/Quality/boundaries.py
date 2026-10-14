#!/usr/bin/env python3
"""Enforce allowed imports and reject managed/global state in neutral modules."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
allowed = {'DeltaDomain': {'Foundation'}, 'DeltaApplication': {'Foundation', 'DeltaDomain'}}
errors = []
for module, imports in allowed.items():
    for source in (ROOT / 'Modules' / module).rglob('*.swift'):
        text = source.read_text()
        actual = set(re.findall(r'^\s*(?:@\w+\s+)?import\s+(\w+)', text, re.M))
        for dependency in actual - imports:
            errors.append(f'{source.relative_to(ROOT)}: forbidden dependency {dependency}')
        for forbidden in ['DatabaseManager.shared', 'SyncManager.shared', 'NSManagedObject', 'UIViewController', 'UIKit', 'EmulatorBridge']:
            if forbidden in text:
                errors.append(f'{source.relative_to(ROOT)}: forbidden type/service {forbidden}')
project = (ROOT / 'Delta.xcodeproj/project.pbxproj').read_text()
if re.search(r'/\* (?:SystemDescriptor|EmulationSession|StorageArtifact|LaunchCoordinator|CallbackEmulationSession|ImportCoordinator)\.swift in Sources \*/', project):
    errors.append('Neutral module sources must be linked as products, not compiled into Delta')
# Library/gameplay presentation must configure engines through app adapters.
for name in ['Delta/Emulation/GameViewController.swift', 'Delta/Game Selection/GameCollectionViewController.swift']:
    text = (ROOT / name).read_text()
    if re.search(r'^import (?:GBC|GBA|MelonDS|N64|GPGX|NES|SNES)DeltaCore\b', text, re.M):
        errors.append(f'{name}: concrete core import in migrated presentation')
if errors:
    raise SystemExit('\n'.join(errors))
print('Module imports, global-service exclusions and presentation boundaries passed.')
