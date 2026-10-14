"""macOS miniJVM + real Core Graphics checks; native forms/audio/input are stubbed."""
from pathlib import Path
import struct
import subprocess
import tempfile
root=Path(__file__).resolve().parents[3]
folder=root/'design/snowball-modernization'
vendor=root/'Experiments/J2ME/JarBox/J2MEEmulator'
mini=vendor/'minijvm'
resources=root/'Delta/J2ME/Resources'
hd=root/'output/snowball-modernized/Snowball-Fight-Modernized-HD.jar'
original=Path('/Users/ducnguyen/Downloads/Snowball-Fight_J2ME_EN_v112.jar')
with tempfile.TemporaryDirectory(prefix='snowball-hd-checks-') as name:
    scratch=Path(name);classes=scratch/'classes';classes.mkdir();saves=scratch/'saves';saves.mkdir()
    subprocess.run(['javac','--release','8','-Xlint:-options','-cp',f'{resources}/j2me_api.jar:{hd}','-d',str(classes),str(folder/'tools/headless/javax/microedition/lcdui/NativeBridge.java'),str(folder/'tools/DensityProbe.java'),str(folder/'tools/MenuProbe.java')],check=True)
    render=scratch/'render.m';render.write_text((root/'Delta/J2ME/Native/J2MERender.m').read_text().replace('#import <UIKit/UIKit.h>',''))
    files=[str(p) for sub in ('jvm','utils','utils/https','utils/https/mbedtls/library') for p in (mini/sub).glob('*.c')]
    compiler=['clang','-O0','-w','-fobjc-arc','-D__JVM_OS_IOS__=1']+['-I'+str(mini/p) for p in ('jvm','utils','utils/https','utils/https/mbedtls/include')]
    compiler+=['-I'+str(vendor/'NativeBridge'),str(folder/'tools/headless/runner.c'),str(render)]+files
    for framework in ('Foundation','CoreGraphics','CoreText','ImageIO','CoreHaptics'):compiler+=['-framework',framework]
    binary=scratch/'verify';compiler+=['-lm','-o',str(binary)]
    subprocess.run(compiler,check=True)
    reports=[]
    for scale,asset,jar,main in [(1,1,original,'DensityProbe'),(3,3,hd,'DensityProbe'),(3,3,hd,'MenuProbe')]:
        png=scratch/'menu.png'
        result=subprocess.run([str(binary),str(resources/'minijvm_rt.jar'),f'{classes}:{resources}/j2me_api.jar:{jar}',main,str(scale),str(asset),str(saves),str(png)],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=30)
        assert result.returncode==0,result.stdout
        assert 'PASS:' in result.stdout,result.stdout
        reports.append(f'Scale {scale}, asset density {asset}, {main}:\n'+result.stdout)
        if main=='MenuProbe':
            image=png.read_bytes();assert struct.unpack('>II',image[16:24])==(528,624)
            (folder/'verification/title-menu-hd.png').write_bytes(image)
    text='\n'.join(reports)
    (folder/'verification/hd-checks.log').write_text(text)
    print('\n'.join(line for line in text.splitlines() if line.startswith(('Scale','PASS:'))))
    print('PASS: rendered framebuffer is exactly 528 x 624; ratio remains 176:208')
