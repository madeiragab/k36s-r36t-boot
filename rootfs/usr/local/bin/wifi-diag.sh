#!/bin/bash
# Estado do Wi-Fi ~60 s depois do boot, para leitura no PC.
{
  echo "==== $(date) ===="
  echo "--- nmcli general ---";  nmcli general 2>&1
  echo "--- nmcli dev ---";      nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev 2>&1
  echo "--- conexoes salvas ---"; nmcli -t -f NAME,TYPE,AUTOCONNECT con show 2>&1
  echo "--- redes visiveis ---"; nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>&1 | head -15
  echo "--- ip ---";             ip -br addr 2>&1
  echo "--- rota ---";           ip route 2>&1
  echo "--- ping 8.8.8.8 ---";   ping -c 2 -W 3 8.8.8.8 2>&1 | tail -2
  echo "--- dns ---";            ping -c 1 -W 3 pool.ntp.org 2>&1 | head -1
  echo "--- rfkill ---";         rfkill list 2>&1
  echo "--- iw ---";             iw dev 2>&1
  echo "--- hora ---";           timedatectl status 2>&1 | grep -E "Local time|synchronized|NTP service"
  echo "--- icone ---";          md5sum /roms/themes/es-theme-nes-box/art/wifi*.svg 2>&1
  echo "--- dmesg wifi ---";     dmesg | grep -iE "rk915|wlan|wifi|80211|sdio" | tail -30
} > /boot/wifi_log.txt 2>&1
sync
