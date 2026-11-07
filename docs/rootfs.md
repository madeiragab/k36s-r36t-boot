# Rootfs (partição 2, ext4) — análise

Lido sem montar e sem gravar nada, direto do disco bruto (`\\.\PhysicalDrive1`, offset
`0x8000000`), com [tools/rootfs_extract.py](../tools/rootfs_extract.py) rodando como
administrador. Resultado: **135.861 entradas** listadas e 66.745 arquivos de texto pequenos
copiados para análise. A cópia bruta **não** está no repositório. Aqui ficam só a análise, a
lista de pacotes e os arquivos que foram escritos para este console.

Segredos nunca são copiados: `shadow`, chaves SSH, redes Wi-Fi salvas (`system-connections`),
`machine-id`, históricos de shell.

## Identidade

| Item | Valor |
|---|---|
| Sistema | **ArkOS 2.0 (15012026) "GOGOCAT"** (build ArkOS4Clone) |
| Base | Ubuntu **19.10 Eoan** (`debian_version` = `buster/sid`), aarch64 + armhf (multiarch) |
| ext4 | label `root`, bloco 4096, 2.732.368 blocos (~10,4 GiB), 688.128 inodes |
| Uso | ~7,4 GB em arquivos (2,0 GB só de configs/cheats do RetroArch 64 e 0,85 GB do RetroArch32) |
| Pacotes | **1193** (`dpkg`), lista em [analysis/rootfs-pacotes.txt](../analysis/rootfs-pacotes.txt) |
| Kernel/módulos | `/usr/lib/modules/4.4.189` (igual ao `Image` da BOOT) |
| Wi-Fi | `rockchip_wlan/rk915/rk915.ko` + `/usr/lib/firmware/rk915_fw.bin` e `rk915_patch.bin` |
| GPU | `libmali-rk-bifrost-g31-rxp0-wayland-gbm` (blob da ARM, GBM/KMS, sem X11) |
| SDL2 | várias versões lado a lado: 2.0.10, 2.0.16, 2.26.5, 2.28.2, **2.30.3** |
| Python | 3.7 |

### Montagens (`/etc/fstab`)

```
UUID=e139ce78-…  /                    ext4   defaults,noatime
/dev/mmcblk0p1   /boot                vfat
/dev/mmcblk0p3   /roms                exfat  uid=1002,gid=1002,umask=000,noatime
/roms/tools      /opt/system/Tools    bind
```

**Cuidado com o `bind`:** `/opt/system/Tools` no rootfs é só a pasta *por baixo* da montagem.
Em uso, quem vale é **`EASYROMS/tools/`**. É ali que estão o PortMaster de verdade (versão
`2026.09.13-0343`) e o runtime `love_11.5`. Mexer no `/opt/system/Tools` do rootfs não muda nada.

## Serviços próprios deste console

| Unidade | Faz |
|---|---|
| `audio-resume.service` | roda `audio-fix.sh` no boot ("Fix R36S V5 Audio via RTCWake") — o reset do RK817 por suspensão |
| `k36s-led.service` | LED do joystick (`k36s_joyled.sh`, `breath_red`) |
| `wifi-icon-updater.service` | troca o ícone do Wi-Fi no tema, reinicia o ES (desde a v10, espera o jogo fechar) |
| `wifi_importer.service` | antes do ES abrir, importa redes de um `wifikeyfile.txt` colocado em `EASYROMS/tools/` |
| `firstboot.service` | o `firstboot.sh` da BOOT (clone.sh → `ajustes.sh`) |
| `adckeys.service` | só para o D007; o clone.sh desliga no K36S |

Os arquivos escritos pelos ajustes estão em [rootfs/](../rootfs/):

- `etc/NetworkManager/conf.d/99-k36s-wifi.conf`: `p2p0` fora do NetworkManager, `wifi.powersave=2`
- `etc/sysctl.d/99-salvar-rapido.conf`: `dirty_expire` 2 s, para o save ir ao cartão antes de o botão de power cortar a energia
- `usr/local/bin/`: `audio-fix.sh`, `wifi-conexoes.py`, `wifi-diag.sh`, `k36s_joyled.sh`, `salvar-jogo.sh`, `wifi_icon_state_updater.sh`

O `/opt/ajustes-backup/` tem **14 backups** (18/09/2026, um por versão aplicada), então dá para
desfazer qualquer ajuste copiando o arquivo de volta.

## O que roda aqui (e o que não roda)

- **LÖVE (love2d):** roda. Há dois caminhos:
  1. **Sistema nativo do ArkOS:** `/opt/love2d/love` + `love.sh`, e o EmulationStation tem o sistema
     `love2d` lendo `/roms/love2d/*.love`. Um jogo `.love` copiado para `EASYROMS/love2d/` aparece no menu.
  2. **Runtime do PortMaster** `love_11.5` (em `EASYROMS/tools/PortMaster/runtimes/`), usado pelo
     port do Friday Night Funkin. O `log.txt` dele confirma que o runtime sobe; o erro registrado lá
     (`spooky.lua: attempt to call global 'modify'`) é do script da fase, não do LÖVE.
- **Ports do PortMaster já instalados:** Binding of Isaac Rebirth, Fallout 2, Friday Night Funkin,
  MK Brasileiro (Ikemen), Stardew Valley, Undertale.
- **Navegador / jogos web (WebGL):** não. Não há X11, Wayland compositor nem Chromium; a Mali só
  expõe GBM/KMS para SDL2.

## Limitações desta leitura

- Symlinks curtos ("fast symlinks", alvo guardado dentro do inode) davam `Errno 22` no leitor
  original e ficaram de fora da listagem (por exemplo os links de `*.target.wants` e
  `/lib → usr/lib`). **Já corrigido** em [tools/ext4_reader.py](../tools/ext4_reader.py); uma
  próxima extração lista todos.
- `/var/lib/dpkg/status` (1,1 MB) passou do limite de cópia; a lista de pacotes saiu dos
  `dpkg/info/*.list`, então tem nome e arquitetura, mas não a versão.
