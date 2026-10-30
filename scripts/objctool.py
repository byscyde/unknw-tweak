#!/usr/bin/env python3
# Minimal ObjC metadata resolver + annotated disassembler for an arm64 Mach-O
# that uses DYLD_CHAINED_FIXUPS (rebase target = low 36 bits). My own code,
# run on data only.
import sys, struct

LC_SEGMENT_64 = 0x19
MH_MAGIC_64 = 0xFEEDFACF
PTRMASK = (1 << 36) - 1  # chained rebase target = low 36 bits

def read(path):
    with open(path, 'rb') as f:
        return f.read()

class Macho:
    def __init__(self, data):
        self.d = data
        assert struct.unpack_from('<I', data, 0)[0] == MH_MAGIC_64, "not thin arm64 macho"
        self.secs = []   # (seg,sec,addr,size,offset)
        ncmds = struct.unpack_from('<I', data, 16)[0]
        off = 32
        for _ in range(ncmds):
            cmd, cmdsize = struct.unpack_from('<II', data, off)
            if cmd == LC_SEGMENT_64:
                nsects = struct.unpack_from('<I', data, off+64)[0]
                so = off + 72
                for _s in range(nsects):
                    sname = data[so:so+16].split(b'\0')[0].decode()
                    segn = data[so+16:so+32].split(b'\0')[0].decode()
                    addr, size = struct.unpack_from('<QQ', data, so+32)
                    offset = struct.unpack_from('<I', data, so+48)[0]
                    self.secs.append((segn, sname, addr, size, offset))
                    so += 80
            off += cmdsize

    def va2off(self, va):
        va &= PTRMASK
        for seg, sec, addr, size, offset in self.secs:
            if addr <= va < addr + size:
                return offset + (va - addr)
        return None

    def ptr(self, va):
        # read 8 bytes at va (via file), return rebase target va (low 36 bits)
        o = self.va2off(va)
        if o is None: return 0
        return struct.unpack_from('<Q', self.d, o)[0] & PTRMASK

    def cstr(self, va):
        o = self.va2off(va)
        if o is None: return ''
        end = self.d.find(b'\0', o)
        return self.d[o:end].decode('utf-8', 'replace')

    def section(self, segn, secn):
        for seg, sec, addr, size, offset in self.secs:
            if seg == segn and sec == secn:
                return addr, size, offset
        return None

    def selref_map(self):
        # va of each selref slot -> selector string
        m = {}
        s = self.section('__DATA', '__objc_selrefs') or self.section('__DATA_CONST', '__objc_selrefs')
        if not s: return m
        addr, size, offset = s
        for i in range(0, size, 8):
            slotva = addr + i
            target = struct.unpack_from('<Q', self.d, offset + i)[0] & PTRMASK
            m[slotva] = self.cstr(target)
        return m

    def methods_of_class(self, cls_va):
        # returns (classname, [(selector, imp_va)])
        o = self.va2off(cls_va)
        if o is None: return None, []
        data_ptr = struct.unpack_from('<Q', self.d, o+32)[0] & PTRMASK  # class_t.data (bits<<2 cleared)
        data_ptr &= ~0x7
        ro = self.va2off(data_ptr)
        if ro is None: return None, []
        name_va = struct.unpack_from('<Q', self.d, ro+24)[0] & PTRMASK
        name = self.cstr(name_va)
        baseMethods = struct.unpack_from('<Q', self.d, ro+32)[0] & PTRMASK
        out = []
        if baseMethods:
            mo = self.va2off(baseMethods)
            if mo is not None:
                entsize = struct.unpack_from('<I', self.d, mo)[0]
                count = struct.unpack_from('<I', self.d, mo+4)[0]
                relative = (entsize & 0x80000000) != 0
                esize = entsize & 0xFFFF
                base = mo + 8
                base_va = baseMethods + 8
                for i in range(count):
                    if relative:
                        ent_off = base + i*esize
                        ent_va = base_va + i*esize
                        name_rel = struct.unpack_from('<i', self.d, ent_off)[0]
                        imp_rel = struct.unpack_from('<i', self.d, ent_off+8)[0]
                        # name field points to a selref slot (ptr to selector)
                        selref_va = ent_va + name_rel
                        selp = self.ptr(selref_va)
                        sel = self.cstr(selp)
                        imp_va = (ent_va + 8) + imp_rel
                        out.append((sel, imp_va & PTRMASK))
                    else:
                        ent_off = base + i*esize
                        name_p = struct.unpack_from('<Q', self.d, ent_off)[0] & PTRMASK
                        imp_p = struct.unpack_from('<Q', self.d, ent_off+16)[0] & PTRMASK
                        out.append((self.cstr(name_p), imp_p))
        return name, out

    def class_name_only(self, cls_va):
        o = self.va2off(cls_va)
        if o is None: return None
        data_ptr = struct.unpack_from('<Q', self.d, o+32)[0] & PTRMASK
        data_ptr &= ~0x7
        ro = self.va2off(data_ptr)
        if ro is None: return None
        name_va = struct.unpack_from('<Q', self.d, ro+24)[0] & PTRMASK
        return self.cstr(name_va)

    def all_classes(self, filt=None):
        s = self.section('__DATA_CONST', '__objc_classlist') or self.section('__DATA', '__objc_classlist')
        res = {}
        if not s: return res
        addr, size, offset = s
        for i in range(0, size, 8):
            cls_va = struct.unpack_from('<Q', self.d, offset + i)[0] & PTRMASK
            if filt:
                nm = self.class_name_only(cls_va)
                if not nm or filt.lower() not in nm.lower(): continue
            name, methods = self.methods_of_class(cls_va)
            if name:
                res[name] = (cls_va, methods)
        return res

    def classref_map(self):
        m = {}
        for secn in ('__objc_classrefs', '__objc_superrefs'):
            s = self.section('__DATA', secn) or self.section('__DATA_CONST', secn)
            if not s: continue
            addr, size, offset = s
            for i in range(0, size, 8):
                slotva = addr + i
                clsva = struct.unpack_from('<Q', self.d, offset + i)[0] & PTRMASK
                name, _ = self.methods_of_class(clsva)
                if name: m[slotva] = name
        return m

    def imp_map(self):
        m = {}
        for name, (cls_va, methods) in self.all_classes().items():
            for sel, imp in methods:
                m[imp] = f"[{name} {sel}]"
        return m

import re
def annotate(mobj, start_va, disasm_path):
    selmap = mobj.selref_map()
    clsmap = mobj.classref_map()
    impmap = mobj.imp_map()
    nexts = sorted(v for v in impmap if v > start_va)
    end_va = nexts[0] if nexts else start_va + 0x2000
    lines = open(disasm_path, 'r', errors='replace').read().splitlines()
    # find start line
    pat = re.compile(r'^\s*([0-9a-f]+):\t(\S+)\s*(.*)$')
    out = []
    regpage = {}; regval = {}
    started = False
    for ln in lines:
        mm = pat.match(ln)
        if not mm: continue
        addr = int(mm.group(1), 16)
        if addr == start_va: started = True
        if not started: continue
        if addr >= end_va: break
        mn = mm.group(2); ops = mm.group(3)
        note = ''
        # adrp xN, imm ; 0xPAGE
        a = re.match(r'(x\d+), \d+ ; (0x[0-9a-f]+)', ops)
        if mn == 'adrp' and a:
            regpage[a.group(1)] = int(a.group(2), 16);
        elif mn == 'ldr':
            l = re.match(r'(x\d+), \[(x\d+)(?:, #(0x[0-9a-f]+))?\]', ops)
            if l:
                dst, base, off = l.group(1), l.group(2), l.group(3)
                off = int(off, 16) if off else 0
                if base in regpage:
                    slot = regpage[base] + off
                    if slot in selmap: regval[dst] = ('sel', selmap[slot]); note = '  ; sel=%s' % selmap[slot]
                    elif slot in clsmap: regval[dst] = ('cls', clsmap[slot]); note = '  ; class=%s' % clsmap[slot]
                    else: regval.pop(dst, None)
                else: regval.pop(dst, None)
        elif mn == 'mov':
            l = re.match(r'(x\d+), (x\d+)', ops)
            if l and l.group(2) in regval: regval[l.group(1)] = regval[l.group(2)]
            elif l: regval.pop(l.group(1), None)
        elif mn == 'bl':
            t = re.match(r'(0x[0-9a-f]+)', ops)
            if 'objc_msgSend' in ops:
                sel = regval.get('x1'); recv = regval.get('x0')
                note = '  => ' + (('[%s ' % recv[1]) if recv and recv[0]=='cls' else '-[? ') + (sel[1] if sel and sel[0]=='sel' else '?') + ']'
            elif t:
                tv = int(t.group(1), 16)
                if tv in impmap: note = '  => ' + impmap[tv]
        if note: ln = ln + note
        out.append(ln)
    return '\n'.join(out)

def main():
    path = sys.argv[1]
    mode = sys.argv[2] if len(sys.argv) > 2 else 'classes'
    m = Macho(read(path))
    if mode == 'dis':
        start = int(sys.argv[3], 16)
        print(annotate(m, start, sys.argv[4]))
        return
    if mode == 'classes':
        filt = sys.argv[3] if len(sys.argv) > 3 else ''
        classes = m.all_classes(filt or None)
        for name in sorted(classes):
            cls_va, methods = classes[name]
            print(f"@ {name}  ({len(methods)} methods)")
            for sel, imp in methods:
                print(f"    {sel}\t0x{imp:x}")
    elif mode == 'selrefs':
        for va, sel in sorted(m.selref_map().items()):
            print(f"0x{va:x}\t{sel}")

if __name__ == '__main__':
    main()
