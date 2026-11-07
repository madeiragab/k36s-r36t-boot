#!/bin/bash
# Chamado pelos scripts do botao de power.  $1 = suspend | poweroff
# O quickmode.sh do ArkOS so cuida do RetroArch e do PICO-8; aqui fecham os demais.
sync
[ "$1" = "poweroff" ] || exit 0
EMUS="drastic PPSSPPSDL mupen64plus flycast yabasanshiro hypseus hypseus-singe solarus-run scummvm OpenBOR dosbox amiberry lzdoom gzdoom ecwolf piemu ti99sim-sdl linapple openmsx mvem fake08 easyrpg-player love"
running=""
for e in $EMUS; do pgrep -x "$e" >/dev/null && running="$running $e"; done
if [ -n "$running" ]; then
    for e in $running; do sudo pkill -TERM -x "$e"; done      # SDL transforma SIGTERM em "sair" normal
    for i in $(seq 1 40); do                                   # espera ate 8 s
        alive=""
        for e in $running; do pgrep -x "$e" >/dev/null && alive=1; done
        [ -z "$alive" ] && break
        sleep 0.2
    done
fi
sync
exit 0
