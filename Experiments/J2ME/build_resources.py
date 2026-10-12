#!/usr/bin/env python3
"""Rebuild bundled Java API with the tested initial Canvas paint correction.
Requires javac/jar on PATH. Keeps the pinned JarBox checkout unchanged.
"""
from pathlib import Path
import shutil, subprocess, tempfile
root = Path(__file__).resolve().parent
vendor = root / 'JarBox'
resources = root.parents[1] / 'Delta/J2ME/Resources'
resources.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='delta-j2me-api-') as scratch:
    scratch = Path(scratch)
    src = scratch / 'src'
    shutil.copytree(vendor / 'j2me_api/src', src)
    canvas = src / 'javax/microedition/lcdui/Canvas.java'
    original = canvas.read_text()
    needle = '            graphics.reset(clipX, clipY, clipW, clipH);'
    assert original.count(needle) == 1, 'Review upstream Canvas before rebuilding.'
    canvas.write_text(original.replace(needle, '            if (fullRepaint) { clipX = 0; clipY = 0; clipW = width; clipH = height; }\n' + needle))
    text = canvas.read_text()
    needle = '    public int getGameAction(int keyCode) {'
    assert text.count(needle) == 1
    mappings = """
        String[] names = {"up", "down", "left", "right", "fire"};
        int[] actions = {UP, DOWN, LEFT, RIGHT, FIRE};
        for (int i = 0; i < names.length; i++) {
            String value = System.getProperty("delta.key." + names[i]);
            if (value != null) try { if (keyCode == Integer.parseInt(value)) return actions[i]; } catch (NumberFormatException ignored) {}
        }
"""
    text = text.replace(needle, needle + mappings)
    needle = '    public int getKeyCode(int gameAction) {'
    assert text.count(needle) == 1
    text = text.replace(needle, needle + """
        String[] names = {"up", "down", "left", "right", "fire"};
        int[] actions = {UP, DOWN, LEFT, RIGHT, FIRE};
        for (int i = 0; i < names.length; i++) if (gameAction == actions[i]) {
            String value = System.getProperty("delta.key." + names[i]);
            if (value != null) try { return Integer.parseInt(value); } catch (NumberFormatException ignored) {}
        }
""")
    canvas.write_text(text)
    runner = src / 'javax/microedition/shell/MIDletRunner.java'
    text = runner.read_text()
    text = text.replace('catch (Exception e)', 'catch (Throwable e)')
    text = text.replace('            e.printStackTrace();', '            System.setProperty("delta.j2me.error", e.getClass().getName() + ": " + e.getMessage());\n            e.printStackTrace();')
    text = text.replace('            System.out.println("[MIDletRunner] MIDletStateChangeException: " + e.getMessage());', '            System.setProperty("delta.j2me.error", e.getClass().getName() + ": " + e.getMessage());')
    runner.write_text(text)
    classes = scratch / 'classes'
    classes.mkdir()
    runtime = vendor / 'J2MEEmulator/Resources/jars/minijvm_rt.jar'
    sources = scratch / 'sources.txt'
    sources.write_text('\n'.join(str(p) for p in sorted(src.rglob('*.java'))))
    subprocess.run(['javac', '--release', '8', '-cp', str(runtime), '-d', str(classes), '@' + str(sources)], check=True)
    subprocess.run(['jar', 'cf', str(resources / 'j2me_api.jar'), '-C', str(classes), '.'], check=True)
    shutil.copy2(runtime, resources / 'minijvm_rt.jar')
    shutil.copy2(vendor / 'J2MEEmulator/Resources/sound_fonts/gs_instruments.sf2', resources / 'gs_instruments.sf2')
