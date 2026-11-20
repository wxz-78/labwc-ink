#!/usr/bin/env bash
# 2-optimize.sh — memoria, disco, arranque y (solo en portátiles) batería.
# Ejecútalo con:  ./2-optimize.sh [--country MX]   (pide sudo). Es idempotente.
#   --country CÓDIGO  espejos de pacman solo de ese país (código de 2 letras: MX, ES, AR, CO…; lista: `reflector --list-countries`;
#                     varios separados por coma: MX,US). Sin él se eligen los 20 más rápidos y recientes del mundo.
set -euo pipefail
case "${1:-}" in
  -h|--help) sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
# Sin `-E`: no hay variables que propagar y el env_reset de sudoers puede descartarlas.
[[ $EUID -eq 0 ]] || exec sudo bash "$0" "$@"
COUNTRY=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --country) COUNTRY="${2:-}"; shift; [[ $# -gt 0 ]] && shift ;;
    *) echo "Opción desconocida: $1"; exit 1 ;;
  esac
done
# --country llega a un archivo de configuración: solo se admiten códigos de 2 letras (MX, ES, MX,US).
if [[ -n $COUNTRY && ! $COUNTRY =~ ^[A-Za-z]{2}(,[A-Za-z]{2})*$ ]]; then
  echo "--country: usa códigos de 2 letras separados por coma (ej.: MX o MX,US)." >&2; exit 1
fi
ok()   { printf '\e[32m[ok]\e[0m %s\n' "$*"; }
note() { printf '\e[2m     %s\e[0m\n' "$*"; }

# ¿Es un portátil? (batería del equipo o chasis portátil según la BIOS/UEFI) → TLP tiene sentido; en un PC de escritorio solo añade ruido
# shellcheck source=lib/hwscan.sh
source "$(dirname "$(readlink -f "$0")")/lib/hwscan.sh"
LAPTOP=$(hw_is_laptop)
if [[ $(hw_virt) != none ]]; then
  note "Máquina virtual ($(hw_virt)): se omiten los ajustes de batería aunque el anfitrión simule una."
  LAPTOP=0
fi
(( LAPTOP )) && [[ $(hw_charge_limit) == 1 ]] && note "Tu batería admite límite de carga: al terminar, edita /etc/tlp.d/10-ink.conf (START/STOP_CHARGE_THRESH_BAT0)."

# --- pacman: descargas en paralelo y color (antes de instalar, para que ya surtan efecto) ---
grep -qE '^ParallelDownloads' /etc/pacman.conf || sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
grep -qE '^Color'             /etc/pacman.conf || sed -i 's/^#Color$/Color/' /etc/pacman.conf

PKGS=(zram-generator earlyoom pacman-contrib reflector fwupd)   # fwupd: firmware (BIOS/UEFI, SSD, periféricos) desde LVFS
if (( LAPTOP )); then
  # TLP no convive con power-profiles-daemon
  if pacman -Qq power-profiles-daemon &>/dev/null; then
    systemctl disable --now power-profiles-daemon.service 2>/dev/null || true
    pacman -Rns --noconfirm power-profiles-daemon
    ok "power-profiles-daemon eliminado (choca con TLP)"
  fi
  PKGS+=(tlp)
fi
pacman -S --needed --noconfirm "${PKGS[@]}"

# --- TLP (solo portátiles; valores seguros, el resto usa los defaults de TLP) ---
if (( LAPTOP )); then
  install -Dm644 /dev/stdin /etc/tlp.d/10-ink.conf <<'CONF'
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power
PLATFORM_PROFILE_ON_AC=balanced
PLATFORM_PROFILE_ON_BAT=low-power
# PCIe ASPM: se deja el valor del firmware/kernel (default). «powersupersave» ahorra algo más, pero en algunos
# portátiles congela el NVMe o la Wi-Fi. Si tu equipo lo aguanta: PCIE_ASPM_ON_BAT=powersupersave
PCIE_ASPM_ON_BAT=default
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on
USB_AUTOSUSPEND=1
USB_EXCLUDE_BTUSB=1
# Umbrales de carga (solo si tu portátil los soporta: `sudo tlp-stat -b`)
#START_CHARGE_THRESH_BAT0=75
#STOP_CHARGE_THRESH_BAT0=80
CONF
  systemctl mask systemd-rfkill.service systemd-rfkill.socket   # lo exige TLP
  systemctl enable --now tlp.service
  tlp start >/dev/null || true
  ok "TLP configurado (portátil detectado)"
else
  note "Sin batería: se omite TLP (no aporta nada en un PC de escritorio)."
fi

# --- Tapa y botón de encendido (solo portátiles) ---
# La tapa usa los valores de systemd, dejados explícitos: cerrar suspende y, con monitor externo o base, no hace nada.
# El botón es lo único distinto: un toque suspende (no apaga de golpe por un roce) y mantenerlo pulsado apaga.
# Se recarga logind con SIGHUP (reiniciarlo cerraría la sesión). Para volver a lo de fábrica: borra el archivo.
if (( LAPTOP )); then
  install -Dm644 /dev/stdin /etc/systemd/logind.conf.d/10-ink.conf <<'CONF'
[Login]
HandleLidSwitch=suspend
HandleLidSwitchExternalPower=suspend
HandleLidSwitchDocked=ignore
HandlePowerKey=suspend
HandlePowerKeyLongPress=poweroff
CONF
  systemctl kill -s HUP systemd-logind 2>/dev/null || true
  ok "Tapa y botón de encendido configurados (/etc/systemd/logind.conf.d/10-ink.conf)"
fi

# --- zram: swap comprimido en RAM (la mitad de la RAM, máx. 4 GiB) ---
install -Dm644 /dev/stdin /etc/systemd/zram-generator.conf <<'CONF'
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
CONF

# --- sysctl: zram + SSD + red (valores de la wiki de Arch) ---
install -Dm644 /dev/stdin /etc/sysctl.d/99-ink-performance.conf <<'CONF'
vm.swappiness = 180
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.vfs_cache_pressure = 50
kernel.nmi_watchdog = 0
# Escritura a disco sin tirones: con los valores por defecto (20 % de la RAM) copiar a un USB lento deja el equipo
# «pegado» al vaciar el caché. Límites absolutos: empieza a escribir en segundo plano a 64 MiB y frena al proceso a 256 MiB.
vm.dirty_background_bytes = 67108864
vm.dirty_bytes = 268435456
CONF
# BBR + fq: mejor throughput y latencia en redes con pérdidas. Solo si el kernel trae el módulo.
if modprobe tcp_bbr 2>/dev/null; then
  echo tcp_bbr > /etc/modules-load.d/ink-bbr.conf
  install -Dm644 /dev/stdin /etc/sysctl.d/99-ink-network.conf <<'CONF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
CONF
fi

# vm.max_map_count: Wine/Proton, Unity y muchos juegos se cierran al cargar si es bajo. Arch ya trae 1048576;
# solo se toca si el valor actual es menor (otra distro, o un valor antiguo en /etc/sysctl.d).
if (( $(sysctl -n vm.max_map_count 2>/dev/null || echo 0) < 1048576 )); then
  install -Dm644 /dev/stdin /etc/sysctl.d/99-ink-gaming.conf <<'CONF'
vm.max_map_count = 1048576
CONF
  ok "vm.max_map_count subido a 1048576 (juegos con Wine/Proton)"
fi

# --- planificador de E/S según el tipo de disco (wiki de Arch): NVMe sin cola extra, SSD/eMMC mq-deadline, HDD bfq ---
# Solo toca discos enteros; si el kernel no trae el planificador, udev lo ignora y deja el que había.
install -Dm644 /dev/stdin /etc/udev/rules.d/60-ink-ioschedulers.rules <<'CONF'
ACTION=="add|change", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
CONF
udevadm control --reload 2>/dev/null && udevadm trigger --subsystem-match=block --action=change 2>/dev/null || true

# --- earlyoom: mata lo más pesado antes de que el equipo se congele; nunca el escritorio ---
# -m 10 / -s 10: avisa al bajar del 10 % de memoria disponible o de swap libre.
# -r 3600: un informe de memoria por hora (sin esto earlyoom escribe uno por segundo en el journal).
# --avoid: el escritorio (labwc, waybar, terminal, systemd) se evita como víctima;
#          si hay que matar, se sacrifica otra aplicación antes. (OJO: «--ignore» no existe en earlyoom:
#          getopt lo abrevia a --ignore-root-user y la regex se perdía sin avisar.)
install -Dm644 /dev/stdin /etc/default/earlyoom <<'CONF'
EARLYOOM_ARGS="-r 3600 -m 10 -s 10 --avoid (^|/)(labwc|waybar|greetd|systemd|Xwayland|foot)$"
CONF

# --- espejos de pacman: los más rápidos, solo HTTPS, renovados cada semana (reflector.timer) ---
[[ -f /etc/pacman.d/mirrorlist.ink-bak ]] || cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.ink-bak
install -Dm644 /dev/stdin /etc/xdg/reflector/reflector.conf <<CONF
--save /etc/pacman.d/mirrorlist
--protocol https
--latest 20
--age 12
--sort rate
${COUNTRY:+--country $COUNTRY}
CONF
note "Espejos: copia de tu lista anterior en /etc/pacman.d/mirrorlist.ink-bak"

# --- makepkg (paru compila del AUR): todos los núcleos al compilar y al comprimir ---
install -Dm644 /dev/stdin /etc/makepkg.conf.d/10-ink.conf <<'CONF'
MAKEFLAGS="-j$(nproc)"
COMPRESSZST=(zstd -c -T0 -)
CONF

# --- sin watchdog de hardware: menos despertares de CPU y un apagado sin esperas (en un escritorio no hace falta) ---
install -Dm644 /dev/stdin /etc/modprobe.d/ink-nowatchdog.conf <<'CONF'
blacklist iTCO_wdt
blacklist iTCO_vendor_support
blacklist sp5100_tco
CONF

# --- journal limitado y apagado rápido ---
install -Dm644 /dev/stdin /etc/systemd/journald.conf.d/10-ink.conf <<'CONF'
[Journal]
SystemMaxUse=100M
CONF
install -Dm644 /dev/stdin /etc/systemd/system.conf.d/10-ink.conf <<'CONF'
[Manager]
DefaultTimeoutStopSec=10s
CONF
# lo mismo para los servicios de tu sesión: sin esto, uno colgado retrasa 90 s el cierre de sesión o el apagado
install -Dm644 /dev/stdin /etc/systemd/user.conf.d/10-ink.conf <<'CONF'
[Manager]
DefaultTimeoutStopSec=10s
CONF

sysctl --system >/dev/null || note "Algún sysctl no se pudo aplicar; revisa el aviso anterior."
systemctl daemon-reload

# --- servicios: TRIM semanal, limpieza de caché de pacman, hora sincronizada, OOM ---
systemctl enable --now fstrim.timer paccache.timer reflector.timer earlyoom.service systemd-timesyncd.service
systemctl start --no-block reflector.service || true   # primera lista de espejos en segundo plano
# fwupd solo descarga la lista de firmware disponible (metadatos de LVFS); no instala nada solo. Para aplicar: fwupdmgr update
systemctl enable --now fwupd-refresh.timer 2>/dev/null || note "fwupd-refresh.timer no disponible: usa  fwupdmgr refresh  a mano."

# --- btrfs: scrub mensual (detecta corrupción silenciosa de datos; solo si la raíz es btrfs) ---
if [[ $(findmnt -no FSTYPE /) == btrfs ]]; then
  pacman -S --needed --noconfirm btrfs-progs
  systemctl enable --now 'btrfs-scrub@-.timer' && ok "btrfs scrub mensual activado (btrfs-scrub@-.timer)"
fi

# --- arranque más rápido: no esperar a la red para llegar al login ---
# (si montas unidades de red en fstab, quita esta línea o añade _netdev)
systemctl disable NetworkManager-wait-online.service 2>/dev/null || true

systemctl restart systemd-zram-setup@zram0.service 2>/dev/null || systemctl start systemd-zram-setup@zram0.service || true
ok "Listo. Comprueba: zramctl · systemctl list-timers · systemd-analyze · fwupdmgr get-updates$( ((LAPTOP)) && echo ' · sudo tlp-stat -s')"
