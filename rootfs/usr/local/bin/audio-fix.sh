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
