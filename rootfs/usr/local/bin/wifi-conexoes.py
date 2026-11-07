import os, re, sys
d = sys.argv[1]
changed = 0
for f in sorted(os.listdir(d)):
    if not f.endswith(".nmconnection"): continue
    p = os.path.join(d, f)
    s0 = s = open(p, newline="").read()
    if not re.search(r"^type=wifi$", s, re.M):
        continue
    def put(sec, key, val):
        global s
        if re.search(rf"^{key}=.*$", s, re.M):
            s = re.sub(rf"^{key}=.*$", f"{key}={val}", s, flags=re.M)
        elif f"[{sec}]\n" in s:
            s = s.replace(f"[{sec}]\n", f"[{sec}]\n{key}={val}\n", 1)
        else:
            s = s.rstrip("\n") + f"\n\n[{sec}]\n{key}={val}\n"
    put("connection", "interface-name", "wlan0")    # nunca a p2p0 (Wi-Fi Direct)
    put("connection", "autoconnect", "true")
    put("connection", "autoconnect-retries", "0")   # tenta para sempre, conecta quando a rede aparecer
    s = re.sub(r"^(mac-address|cloned-mac-address)=.*\n", "", s, flags=re.M)  # MAC do rk915 muda todo boot
    s = re.sub(r"^pmf=.*\n", "", s, flags=re.M)  # PMF no padrao: o hotspot exige (code=31 se desligado)
    if s != s0:
        open(p, "w", newline="").write(s); changed += 1
        print("ajustada:", f)
print("redes ajustadas:", changed)
