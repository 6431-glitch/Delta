"""Generate an original mapper-0 NES ROM and compile the repository's original MIDlet."""
from pathlib import Path
import subprocess
import sys
root = Path(__file__).resolve().parents[2]
output = Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
program = bytes.fromhex('78 D8 A2 FF 9A A9 00 8D 00 20 8D 01 20 A9 3F 8D 06 20 A9 00 8D 06 20 A9 21 8D 07 20 A9 00 8D 05 20 8D 05 20 A9 08 8D 01 20')
loop = 0x8000 + len(program)
program += bytes([0x4C, loop & 255, loop >> 8])
prg = bytearray([0xEA] * 16384)
prg[:len(program)] = program
prg[-6:] = bytes([0, 128, 0, 128, 0, 128])
(output / 'Quality.nes').write_bytes(b'NES\x1a\x01\x01' + bytes(10) + prg + bytes(8192))
classes = output / 'classes'
classes.mkdir(exist_ok=True)
resources = root / 'Delta/J2ME/Resources'
subprocess.run(['javac', '--release', '8', '-cp', str(resources / 'minijvm_rt.jar') + ':' + str(resources / 'j2me_api.jar'), '-d', str(classes), str(root / 'Experiments/J2ME/Smoke/DeltaSmoke.java')], check=True)
subprocess.run(['jar', 'cfm', str(output / 'Quality.jar'), str(root / 'Experiments/J2ME/Smoke/MANIFEST.MF'), '-C', str(classes), '.'], check=True)
print(output)
