"""Patch only StartScreen presentation methods, preserving other method bytes."""
from pathlib import Path
import struct
import sys
u2=lambda n: struct.pack('>H',n)
u4=lambda n: struct.pack('>I',n)

def patch(source):
    data=source; count=int.from_bytes(data[8:10],'big'); p=10; i=1; strings={}; entries=[]
    while i<count:
        start=p; tag=data[p]; p+=1
        if tag==1:
            n=int.from_bytes(data[p:p+2],'big'); p+=2; strings[i]=data[p:p+n].decode('utf8'); p+=n
        elif tag in (7,8): p+=2
        elif tag in (3,4,9,10,11,12): p+=4
        elif tag in (5,6): p+=8; i+=1
        else: raise ValueError(tag)
        entries.append(data[start:p]); i+=1
    cp_end=p; additions=[]; next_index=count
    def add(raw):
        nonlocal next_index
        idx=next_index;next_index+=1;additions.append(raw);return idx
    def text(value):
        if value in strings.values(): return next(k for k,v in strings.items() if v==value)
        b=value.encode('utf8');return add(b'\x01'+u2(len(b))+b)
    def cls(value): return add(b'\x07'+u2(text(value)))
    def member(tag, owner, name, desc):
        owner=cls(owner); pair=add(b'\x0c'+u2(text(name))+u2(text(desc)))
        return add(bytes([tag])+u2(owner)+u2(pair))
    field=member(9,'com/westofpluto/snowball/StartScreen','a602','Z')
    paintref=member(10,'delta/snowball/ModernTitle','paint','(Ljavax/microedition/lcdui/Canvas;Ljavax/microedition/lcdui/Graphics;Z)V')
    keyref=member(10,'delta/snowball/ModernTitle','key','(Ljavax/microedition/lcdui/Canvas;I)V')
    code_name=text('Code'); key_name=text('keyPressed'); key_desc=text('(I)V')
    def skip_attributes(at):
        n=int.from_bytes(data[at:at+2],'big');at+=2
        for _ in range(n):
            size=int.from_bytes(data[at+2:at+6],'big');at+=6+size
        return at
    p=cp_end+6; n=int.from_bytes(data[p:p+2],'big');p+=2+n*2
    fields=int.from_bytes(data[p:p+2],'big');p+=2
    for _ in range(fields):p=skip_attributes(p+6)
    method_count_offset=p; methods=int.from_bytes(data[p:p+2],'big');p+=2;new_methods=[];found=False
    def code_attribute(code,stack,locals):
        payload=u2(stack)+u2(locals)+u4(len(code))+code+u2(0)+u2(0)
        return u2(code_name)+u4(len(payload))+payload
    for _ in range(methods):
        start=p; access,name,desc=struct.unpack('>HHH',data[p:p+6]);end=skip_attributes(p+6)
        if strings.get(name)=='paint' and strings.get(desc)=='(Ljavax/microedition/lcdui/Graphics;)V':
            code=b'\x2a\x2b\x2a\xb4'+u2(field)+b'\xb8'+u2(paintref)+b'\xb1'
            new_methods.append(data[start:start+6]+u2(1)+code_attribute(code,3,2));found=True
        else:
            assert strings.get(name)!='keyPressed','Review existing title key handler before patching'
            new_methods.append(data[start:end])
        p=end
    assert found
    code=b'\x2a\xb4'+u2(field)+b'\x9a\x00\x08\x2a\x1b\xb8'+u2(keyref)+b'\xb1'
    new_methods.append(u2(4)+u2(key_name)+u2(key_desc)+u2(1)+code_attribute(code,2,2))
    return data[:8]+u2(next_index)+data[10:cp_end]+b''.join(additions)+data[cp_end:method_count_offset]+u2(len(new_methods))+b''.join(new_methods)+data[p:]

if __name__=='__main__': Path(sys.argv[2]).write_bytes(patch(Path(sys.argv[1]).read_bytes()))
