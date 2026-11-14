#!/usr/bin/env bash
# ============================================================
# 1-install.sh — paquetes, login (greetd) y scripts de apoyo.
# Úsalo como usuario normal (pide sudo):  ./1-install.sh
# Es idempotente. paru se compila desde el AUR si no hay ayudante AUR. Detecta tu hardware (CPU, GPU, Bluetooth, portátil) e instala solo lo que hace falta.
# Variables opcionales:  OFFICE=1 (LibreOffice) · IMAGEMAGICK=0 (sin miniaturas de fondos) · INK_YES=1 (sin preguntas, lo usa install.sh --yes)
#                        INK_32BIT=1|0 (drivers de 32 bits sin preguntar: 1 = sí, activa multilib · 0 = no)
# Después copia los dotfiles con ./dotfiles.sh (ver README).
# ============================================================
set -euo pipefail
case "${1:-}" in
  -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
[ "$EUID" -eq 0 ] && { echo "No lo ejecutes como root."; exit 1; }
cd "$(dirname "$0")" || exit 1
source lib/common.sh
command -v pacman >/dev/null 2>&1 || { echo "Este instalador es para Arch Linux (o derivados con pacman)."; exit 1; }
YES=${INK_YES:-0}
PACMAN_FLAGS=(--needed); [ "$YES" = 1 ] && PACMAN_FLAGS+=(--noconfirm)
say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
note() { printf '    \033[2m%s\033[0m\n' "$*"; }
# ---------- 32 bits (multilib) ----------
# Hace falta para Steam, Wine, juegos antiguos y apps de 32 bits. Convive con los 64 bits: es un repositorio extra
# de pacman (multilib) con paquetes lib32-*; no sustituye nada de lo que ya tienes. Se pregunta ANTES de sincronizar.
WANT32=0
if [ "${INK_32BIT:-}" = 1 ]; then WANT32=1
elif [ "${INK_32BIT:-}" = 0 ]; then WANT32=0
elif confirm "¿Desea agregar drivers de 32 bits? (necesita activar multilib para que convivan 64 y 32 bits)" n; then WANT32=1; fi

if [ "$WANT32" = 1 ]; then
  if grep -q '^\[multilib\]' /etc/pacman.conf; then
    note "multilib ya está activo en /etc/pacman.conf."
  else
    say "Activando el repositorio multilib (32 bits)"
    [ -e /etc/pacman.conf.ink-bak ] || sudo cp /etc/pacman.conf /etc/pacman.conf.ink-bak   # copia de seguridad (solo la primera vez)
    if grep -q '^#\[multilib\]' /etc/pacman.conf; then
      # descomenta «[multilib]» y su línea «Include» (las dos primeras líneas del bloque comentado)
      sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    else
      printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf >/dev/null
    fi
    grep -q '^\[multilib\]' /etc/pacman.conf || { echo "ERROR: no se pudo activar multilib; revisa /etc/pacman.conf."; exit 1; }
  fi
fi

# Arch no admite instalar con bases de datos desactualizadas (actualización parcial): se sincroniza y actualiza primero.
# (con multilib recién activado, este -Syu también descarga su base de datos)
SYU_FLAGS=(); [ "$YES" = 1 ] && SYU_FLAGS+=(--noconfirm)
sudo pacman -Syu "${SYU_FLAGS[@]}"
REPO_PKGS=$(pacman -Slq)   # una sola consulta a las bases de datos; in_repo ya no lanza pacman por paquete
in_repo() { grep -qxF -- "$1" <<<"$REPO_PKGS"; }
# Paquete opcional o dudoso: repos oficiales si existe; si no, AUR. Así un nombre que no esté en los repos no aborta toda la instalación.
AUR=(helium-browser-bin)
pkg_or_aur() { if in_repo "$1"; then PKGS+=("$1"); else AUR+=("$1"); fi; }

# ---------- paquetes base (repos oficiales) ----------
PKGS=(
  # escritorio
  labwc waybar fuzzel foot mako swaylock swayidle swaybg wf-recorder
  cliphist wl-clipboard grim slurp brightnessctl libnotify yt-dlp
  wlsunset libpulse           # luz nocturna · pactl (audio-switch)
  udiskie arch-audit          # montaje automático de USB · avisos de CVE (ink-doctor)
  xorg-xwayland qt6-wayland dconf polkit-gnome xdg-utils wlr-randr
  xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-user-dirs
  # audio y red (TUIs en vez de apps GTK: wiremix sustituye a pavucontrol)
  pipewire-audio pipewire-alsa pipewire-pulse wireplumber rtkit
  networkmanager
  # archivos y discos
  thunar thunar-archive-plugin file-roller tumbler ffmpegthumbnailer gvfs gvfs-mtp udisks2 yazi 7zip unzip zip fd ripgrep   # archive-plugin+file-roller: extraer/comprimir desde Thunar · tumbler: miniaturas · gvfs-mtp: móviles Android
  exfatprogs dosfstools ntfs-3g                                                           # formatear, reparar y leer USB/discos (exFAT, FAT, NTFS)
  poppler jq imagemagick                                                                  # vistas previas en yazi (PDF, JSON, imágenes) · miniaturas de fondos (wallpaper pick)
  # terminal y herramientas
  fish eza bat fzf zoxide btop fastfetch neovim git
  rsync wget curl pciutils usbutils lsof                                                  # copias, descargas y diagnóstico de hardware (lspci, lsusb)
  # visor / medios
  imv zathura zathura-pdf-mupdf mpv
  # login y secretos (gnome-keyring: Helium guarda contraseñas y cookies cifradas con libsecret; sin él usa una clave fija débil)
  greetd greetd-tuigreet gnome-keyring libsecret
  # apariencia
  adw-gtk-theme papirus-icon-theme
  ttf-jetbrains-mono-nerd ttf-liberation ttf-dejavu noto-fonts noto-fonts-emoji
  # mantenimiento
  pacman-contrib playerctl
  man-db man-pages            # `man` (fish usa bat como MANPAGER)
)

# ---------- paquetes que pueden estar en repos o en el AUR (se resuelve solo) ----------
pkg_or_aur wiremix          # mezclador de audio en terminal (sustituye a pavucontrol)
pkg_or_aur adwaita-qt6      # tema oscuro para apps Qt
pkg_or_aur swappy           # anotar capturas (W-Print)
pkg_or_aur phinger-cursors  # tema de cursor

# ImageMagick (miniaturas del selector de fondos y vistas previas de yazi) pesa poco; se puede quitar con IMAGEMAGICK=0
if [ "${IMAGEMAGICK:-1}" = 0 ]; then
  for i in "${!PKGS[@]}"; do [ "${PKGS[i]}" = imagemagick ] && unset 'PKGS[i]'; done
fi

# Ofimática: LibreOffice pesa más de 1 GB y no hace falta para el escritorio. Solo si lo pides:
#   OFFICE=1 ./1-install.sh
[ "${OFFICE:-0}" = 1 ] && PKGS+=(libreoffice-still-es)

# Raíz en btrfs → herramientas del sistema de archivos (check, scrub, snapshots)
[ "$(findmnt -no FSTYPE /)" = btrfs ] && PKGS+=(btrfs-progs)

# CPU → microcódigo
UCODE=""
if   grep -q GenuineIntel /proc/cpuinfo; then PKGS+=(intel-ucode); UCODE=intel; if in_repo sof-firmware; then PKGS+=(sof-firmware); fi   # audio de portátiles Intel recientes
elif grep -q AuthenticAMD /proc/cpuinfo; then PKGS+=(amd-ucode);   UCODE=amd; fi

# GPU → drivers de Mesa/Vulkan/VA-API (lee el fabricante de /sys: 0x8086 Intel, 0x1002 AMD, 0x10de NVIDIA)
PKGS+=(mesa)
GPUS=$(cat /sys/class/drm/card*/device/vendor 2>/dev/null | sort -u || true)
for v in $GPUS; do
  case "$v" in
    0x8086) PKGS+=(vulkan-intel intel-media-driver) ;;
    0x1002) PKGS+=(vulkan-radeon); in_repo libva-mesa-driver && PKGS+=(libva-mesa-driver) ;;
    0x10de) NVIDIA=1 ;;
  esac
done
[ -z "$GPUS" ] && note "No se detectó GPU en /sys (¿máquina virtual?): solo se instala mesa."

# Bluetooth → solo si hay controlador (en un PC sin bluetooth no se instala ni se activa el servicio)
BT=0
if [ -d /sys/class/bluetooth ] && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ]; then BT=1; PKGS+=(bluez bluez-utils); pkg_or_aur bluetui; fi

# wlopm apaga la pantalla por inactividad: si no está en los repos, va por el AUR
pkg_or_aur wlopm

# ---------- drivers de 32 bits (solo si activaste multilib arriba) ----------
if [ "$WANT32" = 1 ]; then
  PKGS32=(lib32-mesa lib32-libpulse lib32-alsa-plugins lib32-pipewire)   # OpenGL/Vulkan base + audio de apps de 32 bits
  for v in $GPUS; do
    case "$v" in
      0x8086) PKGS32+=(lib32-vulkan-intel) ;;
      0x1002) PKGS32+=(lib32-vulkan-radeon); in_repo lib32-libva-mesa-driver && PKGS32+=(lib32-libva-mesa-driver) ;;
      0x10de) # el driver NVIDIA de 32 bits debe ser de la MISMA versión que el de 64: solo se añade si ya lo tienes
              if pacman -Qq nvidia-utils &>/dev/null && in_repo lib32-nvidia-utils; then PKGS32+=(lib32-nvidia-utils)
              else note "NVIDIA + 32 bits: cuando instales tu driver (nvidia-open + nvidia-utils), añade también lib32-nvidia-utils."; fi ;;
    esac
  done
  for p in "${PKGS32[@]}"; do
    if in_repo "$p"; then PKGS+=("$p"); else note "Omitido (no está en multilib): $p"; fi
  done
fi

# Un nombre que ya no exista en los repos oficiales no debe abortar toda la instalación: se intenta por el AUR.
OFFICIAL=()
for p in "${PKGS[@]}"; do
  if in_repo "$p"; then OFFICIAL+=("$p"); else note "$p no está en los repos oficiales: se probará en el AUR."; AUR+=("$p"); fi
done
PKGS=("${OFFICIAL[@]}")

say "Instalando paquetes (repos oficiales)"
sudo pacman -S "${PACMAN_FLAGS[@]}" "${PKGS[@]}"
# --needed no cambia el motivo de instalación de lo que ya estaba como dependencia: se marcan como explícitos
# para que ink-clean / 4-cleanup nunca los traten como huérfanos si luego cae otro paquete.
sudo pacman -D --asexplicit "${PKGS[@]}" >/dev/null
[ "${NVIDIA:-0}" = 1 ] && note "NVIDIA detectada: instala el driver a mano (nvidia-open + nvidia-utils, según tu kernel); no se automatiza a propósito."

# ---------- AUR: navegador (y wlopm/bluetui/etc. si no están en los repos) ----------
# paru se COMPILA desde el AUR (no paru-bin): el binario precompilado se enlaza contra una versión concreta de
# libalpm y deja de arrancar cuando pacman se actualiza («error while loading shared libraries: libalpm.so.N»).
helper_ok() { command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1; }

build_paru() {
  say "Compilando paru desde el AUR (tarda unos minutos; Rust se instala solo para esto y se quita después)"
  sudo pacman -S "${PACMAN_FLAGS[@]}" base-devel git
  installed_rust=0
  if ! command -v cargo >/dev/null 2>&1; then   # rust a mano: así makepkg no pregunta «rust o rustup»
    sudo pacman -S "${PACMAN_FLAGS[@]}" --asdeps rust && installed_rust=1
  fi
  # paru-bin choca con paru (y es justo el que suele romperse): fuera
  if pacman -Q paru-bin &>/dev/null; then sudo pacman -Rns --noconfirm paru-bin; fi
  tmp=$(mktemp -d)
  local mk=(--noconfirm)
  [ "$YES" = 1 ] || mk=()
  if git clone --depth 1 https://aur.archlinux.org/paru.git "$tmp/paru" && (cd "$tmp/paru" && makepkg -si "${mk[@]}"); then
    rm -rf "$tmp"
  else
    rm -rf "$tmp"; echo "AVISO: no se pudo compilar paru."; return 1
  fi
  if [ "$installed_rust" = 1 ]; then sudo pacman -Rns --noconfirm rust || true; fi   # solo hacía falta para compilar
}

HELPER=""
for h in paru yay; do
  if helper_ok "$h"; then HELPER=$h; break; fi
done
if [ -z "$HELPER" ]; then
  if command -v paru >/dev/null 2>&1; then echo "AVISO: paru está instalado pero no arranca (típico de paru-bin tras actualizar pacman)."; fi
  if confirm "No hay un ayudante AUR que funcione. ¿Compilar paru desde el AUR para instalar ${AUR[*]}?" "$([ "$YES" = 1 ] && echo s || echo n)"; then
    if build_paru && helper_ok paru; then HELPER=paru; fi
  fi
fi
if [ -n "$HELPER" ]; then
  say "Instalando ${AUR[*]} con $HELPER"
  "$HELPER" -S "${PACMAN_FLAGS[@]}" "${AUR[@]}" || echo "AVISO: falló algún paquete del AUR; reintenta más tarde."
else
  echo "AVISO: sin AUR no hay ${AUR[*]}. Sin navegador, instala chromium o firefox a mano (y cambia W-b en rc.xml); sin wlopm la pantalla no se apaga sola."
fi

# ---------- scripts de apoyo (en /usr/local/bin: labwc, waybar y fuzzel los encuentran sin tocar el PATH) ----------
say "Instalando scripts: osd, shot, lock, dnd, power-menu, idle-suspend, battery-watch, wallpaper, ink-menu, nightlight, audio-switch, wifi-menu, keys, rec, notif, ink-update, ink-clean, ink-doctor, monitors"
sudo install -m755 bin/* /usr/local/bin/
sudo install -Dm644 lib/common.sh /usr/local/lib/ink/common.sh   # ink-doctor la usa para reconocer tu gestor de arranque

# ---------- pantalla de inicio de sesión: greetd + tuigreet ----------
say "Configurando greetd"
sudo install -Dm644 /dev/stdin /etc/greetd/config.toml <<'TOML'
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --asterisks --cmd labwc --theme 'border=white;text=white;prompt=white;time=darkgray;action=darkgray;button=white;container=black;input=white;title=white;greet=white'"
user = "greeter"
TOML
sudo install -d -o greeter -g greeter /var/cache/tuigreet 2>/dev/null || true   # --remember guarda aquí el último usuario

# ---------- llavero: gnome-keyring se desbloquea solo al iniciar sesión en greetd ----------
# Sin estas dos líneas el llavero queda bloqueado y el navegador (Helium) no puede guardar contraseñas ni cookies cifradas.
# Solo funciona si la contraseña del llavero es la de tu usuario (se crea así en el primer inicio de sesión).
if [ -f /etc/pam.d/greetd ] && ! grep -q pam_gnome_keyring /etc/pam.d/greetd; then
  say "Desbloqueo automático del llavero (PAM de greetd)"
  [ -e /etc/pam.d/greetd.ink-bak ] || sudo cp /etc/pam.d/greetd /etc/pam.d/greetd.ink-bak
  printf '%s\n' 'auth       optional     pam_gnome_keyring.so' | sudo tee -a /etc/pam.d/greetd >/dev/null
  printf '%s\n' 'session    optional     pam_gnome_keyring.so auto_start' | sudo tee -a /etc/pam.d/greetd >/dev/null
fi

# ---------- servicios ----------
say "Activando servicios"
if systemctl is-active --quiet systemd-networkd.service; then   # arrancar NM a la vez que networkd corta la red a mitad de la instalación
  note "systemd-networkd está activo: NetworkManager se habilita pero no se arranca ahora (se usará tras reiniciar)."
  sudo systemctl enable NetworkManager.service
else
  sudo systemctl enable --now NetworkManager.service
fi
[ "$BT" = 1 ] && sudo systemctl enable --now bluetooth.service
sudo systemctl enable --force greetd.service   # --force: sustituye el alias display-manager de sddm/gdm/lightdm si lo había
sudo systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service 2>/dev/null || true

# ---------- usuario ----------
sudo usermod -aG video "$USER"            # brillo sin sudo
xdg-user-dirs-update
[ "$(getent passwd "$USER" | cut -d: -f7)" = /usr/bin/fish ] || chsh -s /usr/bin/fish

# Navegador predeterminado: Helium (el .desktop lo trae el paquete)
for f in /usr/share/applications/[Hh]elium*.desktop; do
  [ -f "$f" ] && { xdg-settings set default-web-browser "${f##*/}" 2>/dev/null || true; break; }
done

BL=$(detect_bootloader)
cat <<MSG

✔ Listo. Siguiente:
  0. Microcódigo (${UCODE:-ninguno}) · gestor de arranque detectado: $BL
MSG
[ -n "$UCODE" ] && printf '       %s\n' "$(ucode_hint "$BL" "${UCODE}-ucode")"
[ "$WANT32" = 1 ] && printf '       Drivers de 32 bits (multilib) instalados: Steam, Wine y apps de 32 bits ya pueden usarlos.\n'
cat <<'MSG'
  1. Copia los dotfiles:   ./dotfiles.sh
  2. ./2-optimize.sh y ./3-privacy.sh   (y, si tu raíz es btrfs, ./5-snapshots.sh: funciona con GRUB y Limine)
  2b. (opcional) Wine Staging + winetricks para programas de Windows:  ./6-wine.sh
  3. Reinicia y entra desde greetd. (Antes puedes probar con `labwc` desde un TTY.)
MSG
