#!/bin/bash
# LED dos analogicos no boot. Usa a escolha salva pelo menu JoyLED.
# Sem escolha salva -> breathing red. Escolha "off" (arquivo vazio) -> apagado.
STATE=/var/lib/joyled/state
if [ -e "$STATE" ]; then MODE="$(tr -d '\r\n ' < "$STATE")"; [ -z "$MODE" ] && MODE=off; else MODE=breath_red; fi
case "$MODE" in
  red) C=3;; green) C=1;; blue) C=2;; white) C=7;; orange) C=5;; purple) C=6;; cyan) C=4;;
  breath_red) C=19;; breath_green) C=17;; breath_blue) C=18;; breath_white) C=23;;
  breath_orange) C=21;; breath_purple) C=22;; breath_cyan) C=20;; breath) C=24;; flow) C=8;;
  off) C=off;; *) C=19;;
esac
[ -d /sys/class/gpio/gpio65 ] || echo 65 > /sys/class/gpio/export 2>/dev/null
echo out > /sys/class/gpio/gpio65/direction 2>/dev/null
if [ "$C" = off ]; then echo 0 > /sys/class/gpio/gpio65/value 2>/dev/null; exit 0; fi
echo 1 > /sys/class/gpio/gpio65/value 2>/dev/null
for i in 1 2 3; do /usr/bin/mcu_led /dev/ttyS2 chgmode "$C" 1 >/dev/null 2>&1; sleep 2; done
exit 0
