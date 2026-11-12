#!/usr/bin/env python3
"""Prove game-transfer round trips on original fixtures in an owned simulator."""
import argparse
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import time

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--app', required=True, type=Path)
parser.add_argument('--output', type=Path, default=Path('.build/game-transfer-smoke'))
parser.add_argument('--keep', action='store_true', help='Keep the owned simulator for interactive UI checks; caller must clean it up')
args = parser.parse_args()
app, output = args.app.resolve(), args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
for name in ['transfer.json', 'transfer-expected.json', 'transfer-actual.json']:
    (output / name).unlink(missing_ok=True)
subprocess.run(['python3', 'Tests/QualitySmoke/fixtures.py', str(output / 'fixtures')], cwd=root, check=True)
bundle = plistlib.loads((app / 'Info.plist').read_bytes())['CFBundleIdentifier']
def sim(*arguments):
    return subprocess.check_output(['xcrun', 'simctl', *arguments], text=True).strip()
device = sim('create', 'Delta Transfer QA', 'com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro', 'com.apple.CoreSimulator.SimRuntime.iOS-26-5')
(output / 'device.txt').write_text(device)
try:
    print('Transfer simulator: ' + device, flush=True)
    sim('boot', device)
    sim('bootstatus', device, '-b')
    sim('install', device, str(app))
    data = Path(sim('get_app_container', device, bundle, 'data'))
    environment = os.environ.copy()
    environment.update(SIMCTL_CHILD_DELTA_QUALITY_TRANSFER_ROUNDTRIP='1',
                       SIMCTL_CHILD_DELTA_QUALITY_TEST_GAME=str(output / 'fixtures/Quality.nes'),
                       SIMCTL_CHILD_DELTA_QUALITY_TRANSFER_JAR=str(output / 'fixtures/Quality.jar'))
    with (output / 'app.log').open('w') as log:
        process = subprocess.Popen(['xcrun', 'simctl', 'launch', '--console', device, bundle], env=environment, stdout=log, stderr=subprocess.STDOUT)
        try:
            result = data / 'Documents/QualitySmoke/transfer.json'
            deadline = time.monotonic() + 120
            while not result.exists() and time.monotonic() < deadline:
                if process.poll() is not None:
                    raise RuntimeError('App exited before the transfer result; inspect app.log')
                time.sleep(1)
            for filename in ['transfer-expected.json', 'transfer-actual.json']:
                path = data / 'tmp' / filename
                if path.exists(): shutil.copy2(path, output / filename)
            if not result.exists(): raise RuntimeError('Transfer round trip timed out; inspect app.log')
            report = json.loads(result.read_text())
            shutil.copy2(result, output / 'transfer.json')
            package = result.with_name('Transfer.deltatransfer')
            if package.exists(): shutil.copy2(package, output / package.name)
            sim('io', device, 'screenshot', str(output / 'library.png'))
            print(json.dumps(report), flush=True)
            if not report['passed']: raise RuntimeError(report['detail'])
        finally:
            try: sim('terminate', device, bundle)
            except subprocess.CalledProcessError: pass
            process.terminate()
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired: process.kill(); process.wait()
    if args.keep:
        sim('launch', device, bundle)
        subprocess.run(['open', '-a', 'Simulator', '--args', '-CurrentDeviceUDID', device], check=True)
finally:
    if not args.keep:
        try: sim('shutdown', device)
        finally: sim('delete', device)
