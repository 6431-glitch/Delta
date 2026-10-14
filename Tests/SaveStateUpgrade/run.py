"""Exercise production save policy/metadata and actual v13 → v14 SQLite migration."""
from pathlib import Path
import subprocess, tempfile
root = Path(__file__).resolve().parents[2]
source = (root / 'Delta/Database/Model/Human/SaveState.swift').read_text()
rules = source[source.index('enum SaveStateRules'):source.index('@objc(SaveState)')]
tags = source[source.index('    var tags:'):source.index('    static func autosaveLimit')]
with tempfile.TemporaryDirectory(prefix='delta-save-upgrade-') as directory:
    path = Path(directory)
    swift = path / 'main.swift'
    swift.write_text('import Foundation\nimport CoreData\n' + rules + '\nclass TagFixture { var tagsRaw: String?\n' + tags + '\n}\n' + Path(__file__).with_name('fixtures.swift').read_text())
    subprocess.run(['swiftc', '-module-cache-path', '/private/tmp/DeltaNukeSwiftCache', str(swift), '-o', str(path / 'verify')], check=True)
    subprocess.run([str(path / 'verify'), str(root), '/private/tmp/DeltaNukeBuild/Build/Products/Debug-iphonesimulator/Delta.app/Delta.momd', str(path)], check=True)
