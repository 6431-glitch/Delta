"""Run the production FRC delegate with real Core Data and a collection-view spy."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[2]
source = (root / 'Delta/Pause Menu/Save States/SaveStatesViewController.swift').read_text()
delegate = source[source.index('extension SaveStatesViewController: NSFetchedResultsControllerDelegate'):]
with tempfile.TemporaryDirectory(prefix='delta-state-snapshot-') as directory:
    path = Path(directory)
    swift = path / 'main.swift'
    swift.write_text((Path(__file__).with_name('fixtures.swift')).read_text() + '\n' + delegate + '\nrunChecks()\n')
    subprocess.run(['swiftc', '-module-cache-path', '/private/tmp/DeltaNukeSwiftCache', str(swift), '-o', str(path / 'verify')], check=True)
    subprocess.run([str(path / 'verify')], check=True)
