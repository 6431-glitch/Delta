"""Exercise production save policy/metadata and actual v13 → v14 SQLite migration."""
from pathlib import Path
import argparse, subprocess, tempfile
parser = argparse.ArgumentParser()
parser.add_argument("--model", type=Path, required=True, help="Built Delta.momd directory")
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
source = (root / 'Delta/Database/Model/Human/SaveState.swift').read_text()
rules = source[source.index('enum SaveStateRules'):source.index('@objc(SaveState)')]
tags = source[source.index('    var tags:'):source.index('    static func autosaveLimit')]
with tempfile.TemporaryDirectory(prefix='delta-save-upgrade-') as directory:
    path = Path(directory)
    swift = path / 'main.swift'
    swift.write_text('import Foundation\nimport CoreData\n' + rules + '\nclass TagFixture { var tagsRaw: String?\n' + tags + '\n}\n' + Path(__file__).with_name('fixtures.swift').read_text())
    subprocess.run(['swiftc', '-module-cache-path', '/private/tmp/DeltaNukeSwiftCache', str(swift), '-o', str(path / 'verify')], check=True)
    subprocess.run([str(path / 'verify'), str(root), str(args.model.resolve()), str(path)], check=True)
