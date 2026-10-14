#!/usr/bin/env python3
"""Run dependency-free contracts; optional built-schema and Nuke integration checks."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--model', type=Path, help='Built Delta.momd directory')
parser.add_argument('--nuke', type=Path, help='Pinned Nuke checkout for HTTP/cache integration')
args = parser.parse_args()
env = os.environ.copy()
with tempfile.TemporaryDirectory(prefix='delta-quality-') as scratch:
    cache = Path(scratch) / 'cache'
    env.update(CLANG_MODULE_CACHE_PATH=str(cache), SWIFTPM_MODULECACHE_OVERRIDE=str(cache))
    def run(*command):
        subprocess.run(command, cwd=ROOT, env=env, check=True)
    run('python3', 'Scripts/Quality/boundaries.py')
    run('swift', 'test', '--disable-sandbox', '--scratch-path', str(Path(scratch) / 'swift'))
    for name in ['ArtworkImportValidation', 'ArtworkCoverLayout', 'GameFileReplacement']:
        source = ROOT / 'Delta/Components/Loading' / (name + '.swift')
        executable = str(Path(scratch) / name)
        run('swiftc', '-module-cache-path', str(cache), str(source), str(ROOT / 'Tests' / name / 'verify.swift'), '-o', executable)
        run(executable)
    run('python3', 'Tests/SaveStateSnapshot/run.py')
    audio = str(Path(scratch) / 'audio')
    run('xcrun', 'clang', '-fobjc-arc', '-fmodules', '-fmodules-cache-path=' + str(cache), '-framework', 'Foundation', '-I', str(ROOT / 'Delta/J2ME/Native'), 'Tests/J2MEAudioHandles/verify.m', '-o', audio)
    run(audio)
    rendering = str(Path(scratch) / 'rendering')
    run('swiftc', '-module-cache-path', str(cache), 'Tests/RenderingServices/verify.swift',
        'Cores/DeltaCore/DeltaCore/UI/Game/EmulatorCore+Presentation.swift', '-o', rendering)
    run(rendering)
    if args.model:
        run('swift', '-module-cache-path', str(cache), 'Tests/ArtworkMigration/verify.swift', str(args.model.resolve()))
        run('python3', 'Tests/SaveStateUpgrade/run.py', '--model', str(args.model.resolve()))
    else:
        print('SKIPPED schema migrations: supply --model pointing to built Delta.momd', flush=True)
    if args.nuke:
        run('python3', 'Tests/NukeMigration/run.py', str(args.nuke.resolve()))
    else:
        print('SKIPPED HTTP/cache integration: supply --nuke pinned checkout', flush=True)
