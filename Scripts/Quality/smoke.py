#!/usr/bin/env python3
"""Exercise original fixtures in an isolated simulator; delete only the device this run creates."""
import argparse
import json
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import time

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--app', type=Path, required=True)
parser.add_argument('--output', type=Path, default=Path('.build/quality-smoke'))
args = parser.parse_args()
app, output = args.app.resolve(), args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
subprocess.run(['python3', 'Tests/QualitySmoke/fixtures.py', str(output / 'fixtures')], cwd=root, check=True)
with (app / 'Info.plist').open('rb') as file:
    bundle = plistlib.load(file)['CFBundleIdentifier']

def sim(*arguments, **kwargs):
    return subprocess.check_output(['xcrun', 'simctl', *arguments], text=True, **kwargs).strip()

types = json.loads(sim('list', 'devicetypes', '-j'))['devicetypes']
device_type = next(item['identifier'] for item in types if item['name'] == 'iPhone 17 Pro')
runtimes = json.loads(sim('list', 'runtimes', '-j'))['runtimes']
runtime = next(item['identifier'] for item in runtimes if item.get('isAvailable') and item['name'] == 'iOS 26.5')
device = sim('create', 'Delta Quality Smoke', device_type, runtime)
try:
    print('Smoke simulator: ' + device, flush=True)
    sim('boot', device)
    subprocess.run(['open', '-a', 'Simulator', '--args', '-CurrentDeviceUDID', device], check=True)
    sim('bootstatus', device, '-b')
    sim('install', device, str(app))
    data = Path(sim('get_app_container', device, bundle, 'data'))
    previous_rms_files = None
    for label, kind, filename in [('console', 'console', 'Quality.nes'), ('java', 'java', 'Quality.jar'), ('java-repeat', 'java', 'Quality.jar')]:
        original = output / 'fixtures' / filename
        identifier = hashlib.sha1(original.read_bytes()).hexdigest()
        incoming = output / 'incoming'
        incoming.mkdir(exist_ok=True)
        fixture = incoming / (label + original.suffix)
        shutil.copy2(original, fixture)
        result = data / 'Documents/QualitySmoke' / (kind + '.json')
        result.unlink(missing_ok=True)
        environment = os.environ.copy()
        environment.update(SIMCTL_CHILD_DELTA_QUALITY_SMOKE='1', SIMCTL_CHILD_DELTA_QUALITY_TEST_GAME=str(fixture))
        with (output / (label + '.log')).open('w') as log:
            process = subprocess.Popen(['xcrun', 'simctl', 'launch', '--terminate-running-process', '--console', device, bundle], env=environment, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 90
                while not result.exists() and time.monotonic() < deadline:
                    if process.poll() is not None: raise RuntimeError(f'{kind} app exited; inspect {kind}.log')
                    time.sleep(1)
                if not result.exists(): raise RuntimeError(f'{kind} timed out; inspect {kind}.log')
                report = json.loads(result.read_text())
                shutil.copy2(result, output / (label + '.json'))
                frame = result.with_name(kind + '-frame.png')
                if frame.exists(): shutil.copy2(frame, output / (label + '-frame.png'))
                sim('io', device, 'screenshot', str(output / (label + '-simulator.png')))
                if not report['passed']: raise RuntimeError(str(report))
                if kind == 'java':
                    archives = list((data / 'Documents').rglob(identifier + '.sav'))
                    if len(archives) != 1: raise RuntimeError('Expected one persistent Java save archive')
                    backup = json.loads(archives[0].read_text())
                    if backup['gameID'] != identifier or not backup['files']: raise RuntimeError('Missing Java RMS save artifacts')
                    if label == 'java-repeat' and backup['files'] == previous_rms_files: raise RuntimeError('RMS launch counter did not change after restoration')
                    previous_rms_files = backup['files']
                print(label + ': ' + str(report), flush=True)
            finally:
                try: sim('terminate', device, bundle)
                except subprocess.CalledProcessError: pass
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
finally:
    try: sim('shutdown', device)
    except subprocess.CalledProcessError: pass
    sim('delete', device)
