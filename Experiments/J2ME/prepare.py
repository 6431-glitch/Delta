#!/usr/bin/env python3
"""Create a disposable JarBox smoke app without modifying the pinned vendor source."""
from pathlib import Path
import shutil, subprocess, sys
root = Path(__file__).resolve().parent
output = Path(sys.argv[1] if len(sys.argv) > 1 else '/private/tmp/DeltaJ2MEPrototype').resolve()
if output.exists():
    raise SystemExit(f'Output already exists: {output}; choose a fresh directory.')
shutil.copytree(root / 'JarBox', output, ignore=shutil.ignore_patterns('.git', 'xcuserdata', '*.xcuserstate'))
# Overlay local UI sources while keeping the pinned engine checkout pristine.
for ui in (root / 'Aurora').glob('*.swift'):
    destination = output / 'J2MEEmulator' / ('JARMetadata.swift' if ui.name == 'JARMetadata.swift' else 'UI/' + ui.name)
    shutil.copy2(ui, destination)
project = output / 'J2MEEmulator.xcodeproj/project.pbxproj'
s = project.read_text().replace('appstore.wp.ifresh.jar-box.app', 'page.ducnguyen.Delta.J2MESmoke')
s = s.replace('INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace = YES;', 'INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace = YES;\n\t\t\t\tINFOPLIST_KEY_UIFileSharingEnabled = YES;\n\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "Delta J2ME";')
s = s.replace('\t\t\t\tResources/jars/j2me_api.jar,', '\t\t\t\tResources/jars/delta_smoke.jar,\n\t\t\t\tResources/jars/j2me_api.jar,')
project.write_text(s)
# The upstream Java build scripts point outside the repository. Compile our own
# fixture against the versioned API/runtime JARs instead.
jars = output / 'J2MEEmulator/Resources/jars'
# Fix upstream's zero-sized initial paint clip and rebuild API from its sources.
canvas = output / 'j2me_api/src/javax/microedition/lcdui/Canvas.java'
source = canvas.read_text()
source = source.replace('            graphics.reset(clipX, clipY, clipW, clipH);',
    '            if (fullRepaint) { clipX = 0; clipY = 0; clipW = width; clipH = height; }\n'
    '            graphics.reset(clipX, clipY, clipW, clipH);')
canvas.write_text(source)
api_classes = output / 'api-classes'
api_classes.mkdir()
sources = output / 'api-sources.txt'
sources.write_text('\n'.join(str(p) for p in sorted((output / 'j2me_api/src').rglob('*.java'))))
subprocess.run(['javac', '--release', '8', '-cp', str(jars / 'minijvm_rt.jar'), '-d', str(api_classes), '@' + str(sources)], check=True)
subprocess.run(['jar', 'cf', str(jars / 'j2me_api.jar'), '-C', str(api_classes), '.'], check=True)
classes = output / 'smoke-classes'
classes.mkdir()
subprocess.run(['javac', '--release', '8', '-cp', f'{jars / "minijvm_rt.jar"}:{jars / "j2me_api.jar"}', '-d', str(classes), str(root / 'Smoke/DeltaSmoke.java')], check=True)
subprocess.run(['jar', 'cfm', str(jars / 'delta_smoke.jar'), str(root / 'Smoke/MANIFEST.MF'), '-C', str(classes), '.'], check=True)
scene = output / 'J2MEEmulator/SceneDelegate.swift'
s = scene.read_text()
needle = '        let vc = AppsListViewController()'
replacement = '''        let vc: UIViewController
        if ProcessInfo.processInfo.environment["DELTA_J2ME_SMOKE"] == "1",
           let jar = Bundle.main.url(forResource: "delta_smoke", withExtension: "jar") {
            vc = GameViewController(jarPath: jar.path, appName: "Delta Smoke",
                appIcon: UIImage(), canvasWidth: 240, canvasHeight: 320,
                render3dScale: 1, fpsLimit: 60)
        } else {
            vc = AppsListViewController()
        }'''
assert needle in s
scene.write_text(s.replace(needle, replacement))
# Runtime proof that the iOS interpreter configuration was selected.
bridge = output / 'J2MEEmulator/NativeBridge/jvm_bridge.c'
s = bridge.read_text().replace('#include "jvm.h"', '#include "jvm.h"\n#include "jit.h"')
s = s.replace('    g_jvm->jdwp_enable = 0;', '    printf("DELTA_SMOKE JIT_ENABLE=%d\\n", JIT_ENABLE);\n    g_jvm->jdwp_enable = 0;')
bridge.write_text(s)
print(output)
