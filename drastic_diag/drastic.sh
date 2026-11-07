#!/bin/bash

directory="$(dirname "$1" | cut -d "/" -f2)"

if  [[ ! -d "/${directory}/nds/backup" ]]; then
  mkdir /${directory}/nds/backup
fi
if  [[ ! -d "/${directory}/nds/cheats" ]]; then
  mkdir /${directory}/nds/cheats
fi
if  [[ ! -d "/${directory}/nds/savestates" ]]; then
  mkdir /${directory}/nds/savestates
fi
if  [[ ! -d "/${directory}/nds/slot2" ]]; then
  mkdir /${directory}/nds/slot2
fi

sudo /usr/local/bin/drastickeydemon.py &

cd /opt/drastic

if grep -q '<string name="Language" value="zh-CN" />' /home/ark/.emulationstation/es_settings.cfg; then
    export LANG=zh_CN.UTF-8
    target="/opt/drastic/resources/cheats/zh_CN/usrcheat.dat"
else
    target="/opt/drastic/resources/cheats/es_EN/usrcheat.dat"
fi

if [ -L /opt/drastic/usrcheat.dat ]; then
    if [ "$(readlink /opt/drastic/usrcheat.dat)" != "$target" ]; then
        sudo rm -f /opt/drastic/usrcheat.dat
        sudo ln -sf "$target" /opt/drastic/usrcheat.dat
    fi
else
    sudo ln -sf "$target" /opt/drastic/usrcheat.dat
fi

sudo ./gptokeyb &

if [[ -f "/boot/.console" ]]; then
  CUR_VAL="$(tr -d '\r\n' < "/boot/.console" || true)"
  if [[ "$CUR_VAL" == "u8" || "$CUR_VAL" == "dr28s" || "$CUR_VAL" == "r50s" ]]; then
    LD_PRELOAD=./libs/libSDL2-2.0.so.0.3200.10.rotated ./drastic "$1"
  else
    LD_PRELOAD=./libs/libSDL2-2.0.so.0.3200.10 ./drastic "$1"
  fi
fi

sudo kill -9 $(pidof gptokeyb)

sudo killall python3

sudo systemctl restart oga_events &
