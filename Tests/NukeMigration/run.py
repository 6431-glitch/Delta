#!/usr/bin/env python3
"""Run the production cache helper against Nuke with AppKit as the image adapter.
Usage: python3 Tests/NukeMigration/run.py <Nuke 12.8.0 checkout>
The adapter changes only UIKit/UIImage imports; request/cache logic is unchanged.
"""
import functools
import http.server
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time

repo = Path(__file__).resolve().parents[2]
nuke = Path(sys.argv[1]).resolve()
revision = subprocess.check_output(['git', '-C', str(nuke), 'rev-parse', 'HEAD'], text=True).strip()
assert revision == '0ead44350d2737db384908569c012fe67c421e4d', 'Use the pinned Nuke 12.8.0 revision.'
with tempfile.TemporaryDirectory(prefix='delta-nuke-checks-') as scratch:
    root = Path(scratch)
    sources = root / 'Sources/Checks'
    sources.mkdir(parents=True)
    helper = (repo / 'Delta/Components/Loading/ArtworkImagePipeline.swift').read_text()
    helper = helper.replace('import UIKit', 'import AppKit\ntypealias UIImage = NSImage')
    helper = helper.replace('page.ducnguyen.Delta.artwork', 'Delta.NukeMigration.Tests')
    (sources / 'ArtworkImagePipeline.swift').write_text(helper)
    (sources / 'Checks.swift').write_text((Path(__file__).parent / 'verify.swift').read_text())
    (root / 'Package.swift').write_text('''// swift-tools-version: 5.7
import PackageDescription
let package = Package(name: "DeltaNukeChecks", platforms: [.macOS(.v10_15)], dependencies: [.package(path: %s)], targets: [.executableTarget(name: "Checks", dependencies: [.product(name: "Nuke", package: %s)])])
''' % (json.dumps(str(nuke)), json.dumps(nuke.name)))
    requests = []
    class Handler(http.server.SimpleHTTPRequestHandler):
        def do_GET(self):
            requests.append(self.path)
            if self.path == '/slow.png':
                time.sleep(0.3)
                self.path = '/remote.png'
            try:
                super().do_GET()
            except (BrokenPipeError, ConnectionResetError):
                pass  # Expected when cancelling an in-flight fixture request.
        def log_message(self, *args):
            pass
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Handler, directory=str(root)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        subprocess.run(['swift', 'build', '--package-path', str(root)], check=True, stdout=subprocess.DEVNULL)
        subprocess.run([str(root / '.build/debug/Checks'), str(root), str(server.server_port)], check=True)
        assert requests.count('/remote.png') == 1, 'Disk cache must avoid downloading the image again.'
        print('Passed disk-cache HTTP request-count check (16 total checks).')
    finally:
        server.shutdown()
        server.server_close()
