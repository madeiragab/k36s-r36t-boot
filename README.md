# K36S / R36T (RK3326) — análise da partição BOOT

Análise completa da partição `BOOT` (FAT32, 112 MB) de um portátil vendido como
R36S "com Wi-Fi", que roda **ArkOS4Clone** e se identifica como **K36S / R36T**.

É o irmão mais novo do clone documentado em
[darkos-ga36-port](https://github.com/madeiragab/darkos-ga36-port). Ao contrário daquele
(Allwinner A33 remarcado), **este usa um RK3326 de verdade**.

Tudo aqui foi lido sem alterar o cartão. Os binários de terceiros (kernel, initrd, DTBs,
`dtb_selector`) **não** estão no repositório, só a análise deles.

---

## Resumo técnico (confirmado lendo o cartão)

| Item | Valor | Fonte |
|---|---|---|
| Modelo (DT) | `R36T/K36S`, compatible `rockchip,rk3326-k36s-linux` | `rk3326-k36s-linux.dtb` |
| SoC | Rockchip **RK3326**, 4× Cortex-A35 (ARMv8, 64-bit) | nós `/cpus` |
| CPU | 1008 → **1512 MHz** (6 OPPs) | `/cpu0-opp-table` |
| GPU | Mali-G31 (Bifrost; no DT como `arm,mali-midgard` legado), 400/480/**520 MHz** | `/gpu@ff400000` |
| DDR | DMC 528 / 666 / **786 MHz** | `/dmc-opp-table` |
| Tela | MIPI-DSI 4 lanes, **640×480**, init `elida,kd35t133`, 153×85 mm, pixel clock 30 MHz | `/dsi@ff450000/panel@0` |
| PMIC / áudio / bateria | RK817 (codec + carregador), bateria de projeto **2775 mAh** | `/i2c@ff180000/pmic@20` |
| **Wi-Fi** | **Rockchip RK915** em SDIO (`dwmmc@ff380000`), driver `rk915.ko` | `/wireless-wlan`, `clone_log.txt` |
| Controles | `odroidgo3-joypad` ("GO-Super Gamepad"), 2 analógicos via ADC + mux | `/odroidgo3-joypad` |
| Kernel | **Linux 4.4.189** (`lcdyk@Lcdyk`, Linaro GCC 6.3, build #62, 13/12/2025) | `Image` |
| Boot | U-Boot estilo ODROID-GO (`odroidgoa-uboot-config`), `booti` com Image + uInitrd + DTB | `boot.ini` |
| Rootfs | `root=UUID=e139ce78-…` (ext4, partição 2, ~11 GB) | `boot.ini` |
| Userland | ArkOS (Python 3.7 → base Ubuntu 19.10 aarch64), EmulationStation, RetroArch, DraStic, PPSSPP | `drastic_diag/info.txt` |

### Layout do cartão (94 GB)

| # | Offset | Tamanho | Tipo | Rótulo |
|---|---|---|---|---|
| — | 0 – 16 MiB | 16 MiB | raw | idbloader / U-Boot / trust (Rockchip) |
| 1 | 16 MiB | 112 MiB | FAT32 | `BOOT` |
| 2 | 128 MiB | 10,4 GiB | ext4 | rootfs (ArkOS) |
| 3 | 10,5 GiB | 77,4 GiB | exFAT | `EASYROMS` |

---

## Cadeia de boot

```
BootROM → idbloader/U-Boot (raw, antes de 16 MiB) → boot.ini
  → load Image @0x02000000, uInitrd @0x01100000, rk3326-k36s-linux.dtb @0x01f00000
  → booti → kernel 4.4.189 → rootfs ext4 → firstboot.sh (clone.sh) → ajustes.sh → EmulationStation
```

- `boot.ini` é igual ao `consoles/k36s/boot.ini` e ao `boot.ini.default`. Ou seja, o modelo foi
  escolhido com o `dtb_selector`, que copia a pasta `consoles/<modelo>/` para a raiz.
- `Image` é o mesmo de `consoles/kernel/common/Image`. **Um único kernel serve todos os ~40
  clones**. O que muda entre eles é só o DTB.
- `arkos4clone-uboot.dtb` é o DTB que o U-Boot usa e é idêntico ao de fábrica.
- `firstboot.sh` (o "clone.sh" do ArkOS4Clone) roda a cada boot. Ele lê o nome do DTB no
  `boot.ini`, escreve o rótulo em `/boot/.console` (`k36s`), carrega o `rk915.ko` e desliga
  o `adckeys.service` (só o D007 usa). A única mudança local é chamar o `ajustes.sh` no fim
  ([boot/firstboot.sh.patch](boot/firstboot.sh.patch)).

## O DTB foi modificado

O `rk3326-k36s-linux.dtb` em uso **não é o de fábrica**. O `.bak` é idêntico ao original.
Diferenças ([analysis/dtb-diff-original-vs-atual.txt](analysis/dtb-diff-original-vs-atual.txt)):

| Nó | Mudança | Efeito |
|---|---|---|
| `dwmmc@ff370000` (slot do SD) | + `no-sd-uhs-sdr104`, `no-sd-uhs-sdr25`, `no-mmc-hs200` | Força o cartão a rodar mais devagar. É a correção clássica para erros de leitura e corrupção em SDs ruins ou em trilhas fracas da placa. |
| `odroidgo3-joypad` | + `invert-absrx`, `invert-absry`; − `skip-absr` | Liga o analógico direito (antes ignorado) e corrige os eixos invertidos. |

A pasta `EASYROMS` tem `_setores_ruins_NAO_APAGAR` e `FOUND.000`, o que reforça que o
cartão já teve setores ruins. O ajuste do slot SD faz sentido nesse contexto.

---

## Ajustes locais (`ajustes.sh`, v1 → v16)

Sistema próprio de patches versionados: o `firstboot.sh` chama `/boot/ajustes.sh`, que aplica
só as versões que ainda não rodaram (`ajustes.done` = `16`), faz backup em
`/opt/ajustes-backup/<data>/` e grava o log em `ajustes_log.txt`. O histórico completo está em
[ajustes/historico/](ajustes/historico/).

| Versão | O que fez |
|---|---|
| v1 | LED do joystick (`breath_red`), atalhos do DraStic, fuso `America/Sao_Paulo`, NTP.br, RTC sincronizado ao conectar, `MaxVRAM` 1000→200 |
| v2 | `drastickeydemon.py`: FN+START sai, FN+R2/L2 salva/carrega, FN+R3 menu; PPSSPP com FN = menu |
| v3–v4 | RetroArch (64 e 32 bits) e Atari800, `sysctl`, `salvar-jogo.sh`, `finish.sh`/`pause.sh` salvam ao desligar; CPU/GPU/DDR em *performance* só durante o jogo |
| v5–v9 | Áudio: o codec RK817 acorda mudo. `audio-fix.sh` força `Playback Path` OFF→SPK_HP e volume raw 201 (−20 dB) depois de um ciclo de suspensão (`rtcwake`) que reseta o chip |
| v10 | Ícone do Wi-Fi não reinicia mais o ES com jogo aberto; `wifi-diag.sh` |
| v11 | O NetworkManager tentava conectar pela `p2p0` (Wi-Fi Direct) e travava sem IP → `99-k36s-wifi.conf` |
| v12 | `wifi-conexoes.py`: normaliza as redes salvas a cada boot para conectarem sozinhas |
| v13 | PMF volta ao padrão (o hotspot do celular exige PMF e recusava com `code=31`) |
| v14 | **Quebrou**: desligar o Wi-Fi durante o reset do áudio travou o boot (`nmcli` + suspensão) |
| v15 | Volta ao fluxo da v9, com `timeout` na suspensão e log do resultado |
| v16 | Só leitura: copia a configuração do DraStic para `/boot/drastic_diag/` |

---

## Problemas conhecidos (pelos logs)

### Wi-Fi RK915 instável
[logs/wifi_log.txt](logs/wifi_log.txt): `wlan0` **DOWN**, sem conexão, apesar de rfkill
liberado e de 4 redes salvas. O `dmesg` mostra o motivo:

```
RK915: ERROR: sdio_writeb_comp: error -110
RK915: ERROR: rk915_signal_io_error
RK915: ERROR: -------- fw error recovery (0) start --------
```

O erro `-110` (`ETIMEDOUT`) no SDIO aparece **logo depois de `sdio_resume`**, ou seja, o chip
não volta da suspensão. Essa suspensão vem do próprio `audio-fix.sh` (`rtcwake -m mem`, o
reset do codec). Os dois consertos brigam entre si: o reset do áudio derruba o Wi-Fi. O
firmware até se recupera (`download firmware success`), mas o NetworkManager fica em
`disconnected`.

Caminhos possíveis, do mais simples ao mais trabalhoso:
1. Depois do `rtcwake`, recarregar o módulo (`modprobe -r rk915 && modprobe rk915`) e só então
   `nmcli radio wifi on`, com `timeout` (sem repetir o erro da v14).
2. Trocar o reset por suspensão por um reset só do codec, sem suspender o sistema inteiro.
3. Testar `keep-power-in-suspend` já presente no `dwmmc@ff380000` junto de
   `wakeup-source`/`non-removable`. Precisa mexer no DTB, então só com backup.

### Áudio RK817 mudo no boot
[logs/audio_log.txt](logs/audio_log.txt): o `simple-audio-card` não acha os widgets
`MIC_IN`/`HPOL`/`HPOR` (rotas declaradas no DT com nomes que o driver do codec não expõe).
Por isso o caminho de saída precisa ser forçado à mão. Hoje a v15 funciona: SPK_HP, −20 dB,
`Headphone Jack` detectado.

---

## E rodar PokeBonk (ou outro jogo web) nele?

O PokeBonk de PC é só um Electron que abre `pokebonk.com`. O jogo é three.js/WebGL.
Neste console:

- **Rodar direto: não.** O ArkOS não tem X11 nem Wayland (EmulationStation e SDL2 direto no
  KMS), não há Chromium para esse userland, e com ~1 GB de RAM (típico da linha; o DT não
  declara a memória, o U-Boot preenche) e uma Mali-G31 a 520 MHz um
  jogo 3D em WebGL dentro de um navegador não ficaria jogável.
- **Streaming do PC (Moonlight):** é o caminho realista. O PC roda o jogo e o console só
  decodifica vídeo 640×480. **Antes, o Wi-Fi RK915 precisa ficar estável** (seção acima).

---

## Conteúdo do repositório

```
analysis/   DTBs decodificados (.dts) e diff do DTB modificado
boot/       boot.ini em uso e o patch aplicado no firstboot.sh
ajustes/    ajustes.sh atual + histórico v1..v16
logs/       logs do console (redes e MACs anonimizados)
drastic_diag/  diagnóstico do DraStic (v16)
docs/rootfs.md      análise do rootfs (partição 2)
rootfs/     arquivos que os ajustes escreveram no sistema
tools/fdt_dump.py        decodifica/compara DTB sem dtc (Python puro)
tools/ext4_reader.py     leitor ext4 só leitura (do darkos-ga36-port, com symlink rápido corrigido)
tools/rootfs_extract.py  lista o rootfs inteiro e copia configs, sem segredos
```

```bash
python tools/fdt_dump.py rk3326-k36s-linux.dtb > saida.dts
python tools/fdt_dump.py --diff original.dtb modificado.dtb
```

## Rootfs (partição 2)

Analisado em **[docs/rootfs.md](docs/rootfs.md)**: ArkOS 2.0 (15012026) sobre Ubuntu 19.10, 1193
pacotes, serviços próprios do K36S, arquivos dos ajustes em [rootfs/](rootfs/), e o que
roda nele. Em resumo: **LÖVE roda**, pelo sistema `love2d` nativo do ArkOS e pelo runtime
`love_11.5` do PortMaster. Navegador e WebGL não rodam.

Para extrair de novo (só leitura, PowerShell **como administrador**):

```bash
python -I tools/rootfs_extract.py \\.\PhysicalDrive1 0x8000000 SAIDA
```

## Fora do escopo (ainda)

- **U-Boot/idbloader** (os 16 MiB antes da partição 1).
