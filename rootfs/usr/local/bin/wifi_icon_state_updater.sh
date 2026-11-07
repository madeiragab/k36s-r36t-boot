#!/bin/bash
THEMES_DIR="/roms/themes"
UPDATE_INTERVAL=0.5
prev_state=""
while true; do
    current_state="disconnected"
    if nmcli -t -f DEVICE,STATE dev | grep -qE "^wlan.*:connected$"; then
        current_state="connected"
    elif ip link show | grep -qE "wlan[0-9]+.*state UP"; then
        current_state="connecting"
    fi
    if [[ "$current_state" != "$prev_state" ]]; then
        need_restart=false
        for theme_path in "$THEMES_DIR"/*; do
            [ -d "$theme_path" ] || continue
            art_dir="$theme_path/_art"
            [ -d "$art_dir" ] || art_dir="$theme_path/art"
            [ -d "$art_dir" ] || continue
            icon_file="$art_dir/wifi.svg"
            on_bak="$art_dir/wifi_on.bak.svg"
            off_bak="$art_dir/wifi_off.bak.svg"
            if [[ "$current_state" == "connected" ]]; then
                if [[ -f "$on_bak" ]]; then
                    if [[ ! -f "$icon_file" ]] || ! cmp -s "$on_bak" "$icon_file"; then
                        cp "$on_bak" "$icon_file"
                        need_restart=true
                    fi
                fi
            else
                if [[ -f "$off_bak" ]]; then
                    if [[ ! -f "$icon_file" ]] || ! cmp -s "$off_bak" "$icon_file"; then
                        cp "$off_bak" "$icon_file"
                        need_restart=true
                    fi
                fi
            fi
        done
        if [ "$need_restart" = true ]; then
            # nao derruba jogo aberto: espera o ES ficar sem processo filho (jogo)
            while es=$(pidof -s emulationstation) && [ -n "$es" ] && pgrep -P "$es" >/dev/null; do sleep 2; done
            systemctl restart emulationstation
        fi
        prev_state="$current_state"
    fi
    sleep "$UPDATE_INTERVAL"
done
