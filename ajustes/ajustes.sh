#!/bin/bash
# Ajustes aplicados no boot (chamado pelo /boot/firstboot.sh, como root).
# Aplica, em ordem, as versoes que ainda nao rodaram. Log: /boot/ajustes_log.txt
# v1-v9 (ja aplicadas): LED, controles, hora, ES, save no power, desempenho, audio
# v10: icone do Wi-Fi nao reinicia o ES com jogo aberto + diagnostico do Wi-Fi
# v11: Wi-Fi conectava pela p2p0 (Wi-Fi Direct) e travava sem IP; rk915 nao suporta PMF
# v12: redes conhecidas conectam sozinhas no boot (normaliza as redes salvas todo boot)
# v13: PMF volta ao padrao (o hotspot exige PMF e recusava com code=31)
# v14: audio mudo de novo: o Wi-Fi conectando no boot cancelava a suspensao que reseta o codec.
#      audio-fix desliga o Wi-Fi so durante o reset, confere se suspendeu de verdade e tenta de novo.
# v15: v14 TRAVAVA o boot (nmcli + suspensao) -> jogos nao abriam e volume ficava voltando.
#      Volta ao audio-fix da v9, com timeout na suspensao e log; Wi-Fi religado uma vez.
# v16: SO LEITURA: copia a config do DraStic (toque na tela) para /boot para diagnostico. Nao altera nada.
VER=16
DONE=/boot/ajustes.done
LOG=/boot/ajustes_log.txt
VOL_INICIAL=201     # ~ -20 dB: baixo mas audivel (85% na escala crua)
CUR="$(cat "$DONE" 2>/dev/null)"; CUR=${CUR:-0}
# todo boot, antes do EmulationStation abrir: saida e volume inicial
amixer -q sset 'Playback Path' SPK_HP 2>/dev/null
amixer -q sset 'Playback' $VOL_INICIAL 2>/dev/null
# todo boot: diagnostico do Wi-Fi 60 s depois (grava /boot/wifi_log.txt)
[ -x /usr/local/bin/wifi-diag.sh ] && systemd-run --on-active=60 --unit=wifi-diag-$$ /usr/local/bin/wifi-diag.sh >/dev/null 2>&1
# todo boot: arruma as redes salvas (inclusive as criadas pelo menu) e recarrega
if [ -f /usr/local/bin/wifi-conexoes.py ]; then
  python3 /usr/local/bin/wifi-conexoes.py /etc/NetworkManager/system-connections >/dev/null 2>&1
  chmod 600 /etc/NetworkManager/system-connections/*.nmconnection 2>/dev/null
  nmcli con reload >/dev/null 2>&1
fi
[ "$CUR" -ge "$VER" ] && exit 0

BK=/opt/ajustes-backup/$(date +%Y%m%d-%H%M%S)
mkdir -p "$BK"
exec >>"$LOG" 2>&1
echo "==== ajustes v$((CUR+1))..v$VER  $(date)  console=$(cat /boot/.console 2>/dev/null) ===="
bk()   { [ -e "$1" ] && mkdir -p "$BK$(dirname "$1")" && cp -a "$1" "$BK$1" && echo "  backup: $1"; }
ok()   { echo "OK   $*"; }

if [ "$CUR" -lt 15 ]; then
echo "[1] audio-fix.sh v15: igual a v9 (sem mexer no Wi-Fi), suspensao com timeout, log do resultado"
F=/usr/local/bin/audio-fix.sh
bk "$F"
cat > "$F" <<'EOS'
#!/bin/bash
# Reinicia o codec RK817 e deixa o audio num estado conhecido. Roda no boot pelo audio-resume.service.
# Escala do chip: 'Playback' raw 0..237 = -95.00..-6.75 dB.
# v15: mesmo fluxo da v9; a suspensao tem timeout (nunca trava o boot) e o resultado vai pro log.
VOL_INICIAL=201     # ~ -20 dB (baixo mas audivel)
sleep 5
antes=$(cat /sys/power/suspend_stats/success 2>/dev/null)
timeout 15 rtcwake -m mem -s 1 >/tmp/rtcwake.log 2>&1
rc=$?
sleep 2
depois=$(cat /sys/power/suspend_stats/success 2>/dev/null)
# o driver ignora valor repetido: depois do reset e preciso MUDAR o valor para reprogramar o chip
amixer -q sset 'Playback Path' OFF
sleep 0.3
amixer -q sset 'Playback Path' SPK_HP
amixer -q sset 'Playback' $((VOL_INICIAL - 1))
amixer -q sset 'Playback' $VOL_INICIAL
alsactl store
iw dev wlan0 set power_save off 2>/dev/null
# religa o Wi-Fi uma unica vez (a v14 pode ter deixado desligado)
if [ ! -f /boot/wifi_religado_v15 ]; then
  (sleep 15; timeout 10 nmcli radio wifi on; touch /boot/wifi_religado_v15; sync) >/dev/null 2>&1 &
fi
{
  echo "==== $(date) ===="
  echo "rtcwake rc=$rc  suspensoes ok antes=$antes depois=$depois"
  cat /tmp/rtcwake.log
  echo "--- dmesg PM ---"; dmesg | grep -i -E "PM: suspend|suspend entry|suspend exit|abort|rk817" | tail -12
  echo "--- sget Playback ---";      amixer sget 'Playback' 2>&1 | tail -2
  echo "--- sget Playback Path ---"; amixer sget 'Playback Path' 2>&1 | tail -1
  echo "--- Headphone Jack ---";     amixer cget iface=CARD,name='Headphone Jack' 2>&1 | tail -1
} > /boot/audio_log.txt 2>&1
sync
exit 0
EOS
chmod 755 "$F"
bash -n "$F" && ok "audio-fix.sh v15 instalado"
fi

if [ "$CUR" -lt 16 ]; then
echo "[2] diagnostico DraStic (somente leitura): copia para /boot/drastic_diag/"
mkdir -p /boot/drastic_diag
timeout 10 cp /opt/drastic/config/drastic.cfg /boot/drastic_diag/drastic.cfg 2>&1
timeout 10 cp /opt/drastic/drastic.gptk /boot/drastic_diag/drastic.gptk 2>&1
{ echo "--- /opt/drastic"; ls -la /opt/drastic; echo "--- procura de scripts"; timeout 10 find /opt /usr/local/bin -maxdepth 2 -iname '*drastic*' 2>/dev/null; echo "--- es_systems nds"; timeout 5 grep -n -i -B2 -A8 'drastic' /etc/emulationstation/es_systems.cfg 2>/dev/null | head -40; echo "--- dispositivos de entrada"; timeout 5 cat /proc/bus/input/devices 2>/dev/null | grep -E 'Name|Handlers'; } > /boot/drastic_diag/info.txt 2>&1
for f in /opt/drastic/drastic.sh /usr/local/bin/drastic.sh /usr/local/bin/drastickeydemon.py; do [ -f "$f" ] && timeout 5 cp "$f" /boot/drastic_diag/ 2>/dev/null; done
ok "diagnostico DraStic copiado"
fi

sync
echo "$VER" > "$DONE"
echo "==== fim $(date) ===="
echo
exit 0
