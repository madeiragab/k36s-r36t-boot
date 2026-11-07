#!/usr/bin/env python3
"""Despeja um DTB (Flattened Device Tree) como texto parecido com .dts, sem precisar do dtc.

Uso:  python fdt_dump.py arquivo.dtb [> saida.dts]
      python fdt_dump.py --diff a.dtb b.dtb      (so as propriedades que mudaram)
Somente leitura; Python puro.
"""
import struct
import sys

FDT_BEGIN_NODE, FDT_END_NODE, FDT_PROP, FDT_NOP, FDT_END = 1, 2, 3, 4, 9


def parse(path):
    d = open(path, "rb").read()
    magic, total, off_struct, off_strings = struct.unpack(">IIII", d[:16])
    if magic != 0xD00DFEED:
        raise SystemExit(f"{path}: nao e um DTB (magic {magic:#x})")
    props = {}  # caminho -> {nome: bytes}
    order = []
    stack = []
    p = off_struct
    while True:
        tok = struct.unpack(">I", d[p:p + 4])[0]
        p += 4
        if tok == FDT_BEGIN_NODE:
            end = d.index(b"\0", p)
            name = d[p:end].decode()
            p = (end + 4) & ~3
            stack.append(name)
            path_ = "/" + "/".join(s for s in stack if s)
            props[path_] = {}
            order.append(path_)
        elif tok == FDT_END_NODE:
            stack.pop()
        elif tok == FDT_PROP:
            ln, nameoff = struct.unpack(">II", d[p:p + 8])
            p += 8
            val = d[p:p + ln]
            p = (p + ln + 3) & ~3
            ne = d.index(b"\0", off_strings + nameoff)
            pname = d[off_strings + nameoff:ne].decode()
            props["/" + "/".join(s for s in stack if s)][pname] = val
        elif tok == FDT_NOP:
            continue
        elif tok == FDT_END:
            break
        else:
            raise SystemExit(f"token invalido {tok} em {p}")
    return order, props


def fmt(val):
    if not val:
        return None
    # lista de strings imprimiveis?
    if val[-1] == 0 and all(32 <= b < 127 or b == 0 for b in val) and b"\0\0" not in val and val[0] != 0:
        return ", ".join('"%s"' % s for s in val[:-1].decode().split("\0"))
    if len(val) % 4 == 0:
        cells = struct.unpack(">%dI" % (len(val) // 4), val)
        return "<" + " ".join("0x%x" % c for c in cells) + ">"
    return "[" + " ".join("%02x" % b for b in val) + "]"


def dump(path):
    order, props = parse(path)
    for node in order:
        print(node + " {")
        for k, v in props[node].items():
            f = fmt(v)
            print(f"    {k};" if f is None else f"    {k} = {f};")
        print("};")


def show(v):
    if v is None:
        return "(ausente)"
    return fmt(v) or "(presente, sem valor)"


def diff(a, b):
    _, pa = parse(a)
    _, pb = parse(b)
    for node in sorted(set(pa) | set(pb)):
        if node not in pa:
            print(f"+ no {node}")
            continue
        if node not in pb:
            print(f"- no {node}")
            continue
        for k in sorted(set(pa[node]) | set(pb[node])):
            va, vb = pa[node].get(k), pb[node].get(k)
            if va != vb:
                print(f"~ {node}:{k}\n    antes:  {show(va)}\n    depois: {show(vb)}")


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--diff":
        diff(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 2:
        dump(sys.argv[1])
    else:
        print(__doc__)
