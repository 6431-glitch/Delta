"""Add app sources without reformatting existing Xcode project entries."""
import hashlib
from pathlib import Path
import re
import sys

project = Path('Delta.xcodeproj/project.pbxproj')
text = project.read_text()
for source in sys.argv[1:]:
    name = Path(source).name
    reference = hashlib.sha256(('quality-ref:' + source).encode()).hexdigest()[:24].upper()
    build = hashlib.sha256(('quality-build:' + source).encode()).hexdigest()[:24].upper()
    if reference in text:
        continue
    text = text.replace('/* Begin PBXFileReference section */\n', f'/* Begin PBXFileReference section */\n\t\t{reference} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{source}"; sourceTree = SOURCE_ROOT; }};\n')
    text = text.replace('/* Begin PBXBuildFile section */\n', f'/* Begin PBXBuildFile section */\n\t\t{build} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {reference} /* {name} */; }};\n')
    group = re.search(r'mainGroup = (\w+)', text).group(1)
    pattern = r'(' + group + r' = \{\n\s*isa = PBXGroup;\n\s*children = \(\n)'
    text, count = re.subn(pattern, lambda match: match.group(1) + f'\t\t\t\t{reference} /* {name} */,\n', text, count=1)
    assert count == 1, 'Root group not found'
    pattern = r'(BFFA71D31AAC406100EE9DD1 /\* Sources \*/ = \{\n\s*isa = PBXSourcesBuildPhase;.*?files = \(\n)'
    text, count = re.subn(pattern, lambda match: match.group(1) + f'\t\t\t\t{build} /* {name} in Sources */,\n', text, count=1, flags=re.S)
    assert count == 1, 'App source phase not found'
project.write_text(text)
