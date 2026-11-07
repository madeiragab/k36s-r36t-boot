#!/usr/bin/env python3
# Atalhos do NDS (DraStic) com FN, lidos direto do controle. Lancado pelo drastic.sh.
#   FN+START  sair               FN+R2  salvar state (F5)
#   FN+L2     carregar state (F7) FN+R3  menu do DraStic (m)
#   FN+SELECT trocar layout da tela (a)
import subprocess, time
import evdev
from evdev import ecodes as e, UInput

FN, START, SELECT, L2, R2, R3 = 708, 705, 704, 312, 313, 707
COMBO = {R2: e.KEY_F5, L2: e.KEY_F7, R3: e.KEY_M, SELECT: e.KEY_A}

def find_pad():
    for path in evdev.list_devices():
        try:
            dev = evdev.InputDevice(path)
            if dev.name in ("GO-Super Gamepad", "OpenSimHardware OSH PB Controller"):
                return dev
        except OSError:
            pass
    return evdev.InputDevice("/dev/input/event2")

pad = find_pad()
kbd = UInput({e.EV_KEY: list(range(1, 249))}, name="drastic-fn-atalhos")

def tap(key):
    kbd.write(e.EV_KEY, key, 1); kbd.syn()
    time.sleep(0.05)
    kbd.write(e.EV_KEY, key, 0); kbd.syn()

for ev in pad.read_loop():
    if ev.type != e.EV_KEY or ev.value != 1:
        continue
    if FN not in pad.active_keys():
        continue
    if ev.code == START:
        subprocess.call(["pkill", "-x", "drastic"])
    elif ev.code in COMBO:
        tap(COMBO[ev.code])
