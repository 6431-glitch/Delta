#!/usr/bin/env python3
"""Create original smoke-JAR variants for resolution detection UI checks."""
from pathlib import Path
import sys, zipfile
base, output = Path(sys.argv[1]), Path(sys.argv[2])
output.mkdir(parents=True, exist_ok=True)
with zipfile.ZipFile(base) as archive:
    entries = {name: archive.read(name) for name in archive.namelist()}
manifest = entries['META-INF/MANIFEST.MF'].decode().replace('\r\n', '\n')
for filename, title, hint in [
    ('ScreenMetadata_320x240.jar', 'Screen Metadata Test', '176,220'),
    ('ScreenFilename_128x160.jar', 'Screen Filename Test', None),
    ('ScreenDescriptor.jar', 'Screen JAD Test', '176,208'),
]:
    text = manifest.replace('Delta Smoke', title)
    if hint:
        text = text.rstrip() + '\nNokia-MIDlet-Original-Display-Size: ' + hint + '\n\n'
    with zipfile.ZipFile(output / filename, 'w', compression=zipfile.ZIP_STORED) as fixture:
        for name, data in entries.items():
            fixture.writestr(name, text.encode() if name == 'META-INF/MANIFEST.MF' else data)
(output / 'ScreenDescriptor.jad').write_text('MIDlet-Name: Screen JAD Test\nMIDlet-Jar-URL: ScreenDescriptor.jar\nNokia-MIDlet-Original-Display-Size: 240,400\n')
print(output)
