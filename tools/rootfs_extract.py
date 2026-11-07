#!/usr/bin/env python3
"""Extrai, SOMENTE LEITURA, o que interessa do rootfs ext4 do cartao para uma pasta.

Uso (Windows, como Administrador, para ler o disco bruto):
    python rootfs_extract.py \\\\.\\PhysicalDrive1 0x8000000 SAIDA

Gera em SAIDA/:
    listing.tsv   todos os arquivos do rootfs (caminho, tipo, modo, uid, tamanho, link)
    files/...     copia de arquivos pequenos de texto das pastas de interesse
    extract.log   o que foi pulado e por que

Nunca copia segredos: senhas do sistema, chaves SSH, redes Wi-Fi salvas.
Nao escreve nada no cartao (abre o dispositivo em modo "rb").
"""
import os
import struct
import sys
from functools import lru_cache

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ext4_reader import Ext4, FTYPE  # noqa: E402

SKIP_TREES = {"/proc", "/sys", "/dev", "/run", "/tmp", "/roms", "/roms2", "/lost+found"}
COPY_TREES = ["/etc", "/usr/local/bin", "/usr/local/sbin", "/opt", "/home/ark",
              "/root", "/var/lib/dpkg/status", "/usr/lib/os-release", "/lib/systemd/system",
              "/usr/share/plymouth/themes"]
SECRET = ("/etc/shadow", "/etc/gshadow", "/etc/shadow-", "/etc/gshadow-",
          "/etc/NetworkManager/system-connections", "/etc/ssh/ssh_host_",
          "/etc/wpa_supplicant", "/root/.ssh", "/home/ark/.ssh", "/etc/machine-id",
          "/var/lib/dbus/machine-id", "/home/ark/.bash_history", "/root/.bash_history",
          "/home/ark/.config/retroarch/retroarch.cfg.bak_cheevos")
MAX_COPY = 512 * 1024


class CachedExt4(Ext4):
    """Mesmo leitor, com cache de blocos (o disco bruto e lento sem buffer)."""

    @lru_cache(maxsize=65536)
    def _blk(self, n):
        return Ext4.block(self, n, 1)

    def block(self, n, count=1):
        if count == 1:
            return self._blk(n)
        return Ext4.block(self, n, count)


def is_secret(p):
    return any(p == s or p.startswith(s) for s in SECRET) or "cheevos_password" in p


def wanted(p):
    return any(p == t or p.startswith(t + "/") for t in COPY_TREES)


def looks_text(b):
    if not b:
        return True
    if b"\0" in b[:4096]:
        return False
    return True


def main():
    dev, off, out = sys.argv[1], int(sys.argv[2], 0), sys.argv[3]
    fs = CachedExt4(dev, off)
    os.makedirs(os.path.join(out, "files"), exist_ok=True)
    lst = open(os.path.join(out, "listing.tsv"), "w", encoding="utf-8")
    log = open(os.path.join(out, "extract.log"), "w", encoding="utf-8")
    lst.write("caminho\ttipo\tmodo\tuid\ttamanho\tlink\n")
    log.write(f"ext4 bs={fs.bs} blocos={fs.blocks_count} inodes={fs.inodes_count} label={fs.label!r}\n")
    n = copied = 0
    stack = [("/", 2)]
    seen = set()
    while stack:
        path, ino = stack.pop()
        if ino in seen:
            continue
        seen.add(ino)
        try:
            entries = fs.listdir(ino)
        except Exception as e:  # diretorio corrompido nao derruba o resto
            log.write(f"ERRO listdir {path}: {e}\n")
            continue
        for name, child, t in entries:
            p = (path.rstrip("/") + "/" + name)
            tag = FTYPE.get(t, "?")
            try:
                ind = fs.inode(child)
                mode, uid = struct.unpack("<HH", ind[0:4])
                size = struct.unpack("<I", ind[4:8])[0] | (struct.unpack("<I", ind[0x6C:0x70])[0] << 32)
                link = ""
                if tag == "l":
                    link = fs.read_inode_data(child).decode("utf-8", "replace")
            except Exception as e:
                log.write(f"ERRO inode {p}: {e}\n")
                continue
            lst.write(f"{p}\t{tag}\t{oct(mode & 0o7777)}\t{uid}\t{size}\t{link}\n")
            n += 1
            if n % 20000 == 0:
                print(f"  {n} entradas...", flush=True)
            if tag == "d":
                if p not in SKIP_TREES:
                    stack.append((p, child))
                continue
            if tag != "-" or not wanted(p):
                continue
            if is_secret(p):
                log.write(f"SEGREDO (nao copiado) {p}\n")
                continue
            if size > MAX_COPY:
                log.write(f"GRANDE (nao copiado) {p} {size}\n")
                continue
            try:
                data = fs.read_inode_data(child)
            except Exception as e:
                log.write(f"ERRO leitura {p}: {e}\n")
                continue
            if not looks_text(data):
                log.write(f"BINARIO (nao copiado) {p} {size}\n")
                continue
            dst = os.path.join(out, "files", *p.strip("/").split("/"))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            try:
                with open(dst, "wb") as f:
                    f.write(data)
                copied += 1
            except OSError as e:
                log.write(f"ERRO gravar {p}: {e}\n")
    log.write(f"FIM: {n} entradas, {copied} arquivos copiados\n")
    print(f"FIM: {n} entradas, {copied} arquivos copiados")


if __name__ == "__main__":
    main()
