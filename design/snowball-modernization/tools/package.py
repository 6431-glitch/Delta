"""Build a separate personal artwork variant. No gameplay methods are rewritten."""
from pathlib import Path
import hashlib
import struct
import subprocess
import tempfile
import zipfile
from patch_title import patch
root=Path(__file__).resolve().parents[3]
folder=root/'design/snowball-modernization'
original=Path('/Users/ducnguyen/Downloads/Snowball-Fight_J2ME_EN_v112.jar')
output=root/'output/snowball-modernized/Snowball-Fight-Modernized-HD.jar'
assets=folder/'assets'
replacement_names=set()

def methods(data):
    count=int.from_bytes(data[8:10],'big');p=10;i=1;strings={}
    while i<count:
        tag=data[p];p+=1
        if tag==1:
            n=int.from_bytes(data[p:p+2],'big');p+=2;strings[i]=data[p:p+n].decode('utf8');p+=n
        elif tag in (7,8):p+=2
        elif tag in (3,4,9,10,11,12):p+=4
        elif tag in (5,6):p+=8;i+=1
        else:raise ValueError(tag)
        i+=1
    def skip_attrs(at):
        n=int.from_bytes(data[at:at+2],'big');at+=2
        for _ in range(n):at+=6+int.from_bytes(data[at+2:at+6],'big')
        return at
    p+=6;n=int.from_bytes(data[p:p+2],'big');p+=2+n*2
    n=int.from_bytes(data[p:p+2],'big');p+=2
    for _ in range(n):p=skip_attrs(p+6)
    n=int.from_bytes(data[p:p+2],'big');p+=2;result={}
    for _ in range(n):
        start=p;_,name,desc=struct.unpack('>HHH',data[p:p+6]);p=skip_attrs(p+6)
        result[(strings[name],strings[desc])]=data[start:p]
    return result

with tempfile.TemporaryDirectory(prefix='snowball-modern-') as temp:
    temp=Path(temp)
    subprocess.run(['javac','--release','8','-Xlint:-options','-cp',str(root/'Delta/J2ME/Resources/j2me_api.jar'),'-d',str(temp),str(folder/'tools/ModernTitle.java')],check=True)
    with zipfile.ZipFile(original) as source:
        assert source.testzip() is None
        data={name:source.read(name) for name in source.namelist()}
        replacement_names={name for name in source.namelist() if name.endswith(".png")}
        for name in replacement_names:
            replacement=(assets/name).read_bytes()
            assert replacement[:8]==b'\x89PNG\r\n\x1a\n'
            assert struct.unpack('>II',replacement[16:24])==tuple(n*3 for n in struct.unpack('>II',data[name][16:24])),name+' density mismatch'
            data[name]=replacement
        title='com/westofpluto/snowball/StartScreen.class'
        data[title]=patch(data[title])
        before=methods(source.read(title));after=methods(data[title])
        for key,value in before.items():
            if key[0]!='paint':assert after[key]==value,'Gameplay/loading method changed: '+str(key)
        data['delta/snowball/ModernTitle.class']=(temp/'delta/snowball/ModernTitle.class').read_bytes()
        manifest=data['META-INF/MANIFEST.MF'].decode('utf8')
        manifest=manifest.replace('MIDlet-Name: Snowball Fight','MIDlet-Name: Snowball Fight Modernized')
        manifest=manifest.replace('MIDlet-1: Snowball Fight,','MIDlet-1: Snowball Fight Modernized,')
        manifest += 'Nokia-MIDlet-Original-Display-Size: 176,208\r\nDelta-J2ME-Render-Scale: 3\r\nDelta-J2ME-Asset-Scale: 3\r\n'
        data['META-INF/MANIFEST.MF']=manifest.encode('utf8')
        output.parent.mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as target:
            for name,contents in data.items():target.writestr(name,contents)
        with zipfile.ZipFile(output) as target:
            assert target.testzip() is None
            changed={n for n in source.namelist() if source.read(n)!=target.read(n)}
            assert changed==replacement_names|{title,'META-INF/MANIFEST.MF'},changed
            print('Validated: all 29 PNGs at exact 3x density; original loading and gameplay methods preserved; all other entries unchanged.')
            print('Original SHA-256:',hashlib.sha256(original.read_bytes()).hexdigest())
            print('Output:',output)
            print('Output SHA-256:',hashlib.sha256(output.read_bytes()).hexdigest())
