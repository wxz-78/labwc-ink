#!/usr/bin/env bash
# 5-snapshots.sh — instantáneas del sistema con snapper + snap-pac (btrfs) y, si quieres, arranque desde ellas.
#   · snap-pac hace un snapshot ANTES y otro DESPUÉS de cada operación de pacman: si una actualización rompe algo, vuelves atrás.
#   · snapper hace snapshots por horas/días y borra los viejos solos (límites bajos para no llenar el disco).
#   · Según tu gestor de arranque se añaden los snapshots al menú de arranque:
#       GRUB          → grub-btrfs (+ grub-btrfsd, que regenera el menú solo)
#       Limine        → limine-snapper-sync + limine-mkinitcpio-hook (AUR)
#       otros         → solo snapshots (se restauran desde un USB o desde otra entrada de arranque)
#
# Uso:  ./5-snapshots.sh                          detecta el gestor de arranque
#       ./5-snapshots.sh --bootloader grub|limine|none    fuerza uno (none = sin integración en el menú)
#       ./5-snapshots.sh --status                 lista los snapshots
#       INK_YES=1 ./5-snapshots.sh                sin preguntas
# Solo funciona si la raíz (/) es btrfs. En ext4/xfs no hay snapshots de sistema: te lo explica y sale.
# Se ejecuta como usuario normal (pide sudo): el AUR no se puede compilar como root.
set -euo pipefail
[[ $EUID -eq 0 ]] && { echo "No lo ejecutes como root; pedirá sudo cuando haga falta."; exit 1; }
cd "$(dirname "$0")"
# shellcheck source=lib/common.sh
source lib/common.sh
ok()   { printf '\e[32m[ok]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[!]\e[0m %s\n' "$*"; }
note() { printf '\e[2m     %s\e[0m\n' "$*"; }

BL=auto
while [[ $# -gt 0 ]]; do
  case "$1" in
    --status) sudo snapper -c root list; exit 0 ;;
    --grub)   BL=grub ;;                                   # compatibilidad con la versión anterior
    --bootloader) BL=${2:-}; shift ;;
    -h|--help) sed -n '2,/^set /{/^set /!p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Opción desconocida: $1"; exit 1 ;;
  esac
  shift
done
case "$BL" in auto|grub|limine|none) ;; *) echo "--bootloader: usa auto, grub, limine o none"; exit 1 ;; esac

fs=$(findmnt -no FSTYPE /)
if [[ $fs != btrfs ]]; then
  warn "Tu raíz es $fs, no btrfs: snapper no puede hacer snapshots instantáneos."
  cat <<'MSG'
     Opciones: reinstalar con btrfs (subvolúmenes @ y @home), o usar Timeshift en modo rsync
     (sudo pacman -S timeshift: copia completa, más lenta y pesada) o una copia externa con restic/borg.
MSG
  exit 0
fi

sudo pacman -S --needed --noconfirm snapper snap-pac btrfs-progs

if sudo snapper list-configs 2>/dev/null | awk 'NR > 2 && $1 == "root" {f = 1} END {exit !f}'; then
  ok "snapper ya tiene configuración para /"
elif [[ -e /.snapshots ]]; then
  warn "/.snapshots ya existe pero snapper no tiene configuración para /."
  echo "     Revisa tu disposición de subvolúmenes (wiki de Arch: Snapper → «Configuration of snapper and mount point»)."
  exit 1
else
  sudo snapper -c root create-config /
  ok "Configuración creada para /"
fi

# Límites conservadores: pocos snapshots, para que no se coman el disco (y, con Limine/GRUB, no llenen el menú ni la ESP)
sudo snapper -c root set-config \
  TIMELINE_CREATE=yes TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=3 TIMELINE_LIMIT_WEEKLY=0 \
  TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 NUMBER_LIMIT=8 NUMBER_LIMIT_IMPORTANT=4
sudo snapper -c root set-config ALLOW_USERS="$USER" SYNC_ACL=yes   # ink-doctor puede listar snapshots sin ser root
sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer

# ---------- integración con el gestor de arranque ----------
[[ $BL == auto ]] && BL=$(detect_bootloader)
note "Gestor de arranque: $BL"

setup_grub() {
  sudo pacman -S --needed --noconfirm grub-btrfs inotify-tools
  sudo systemctl enable --now grub-btrfsd.service
  # Sin este paso el submenú NO aparece: grub-btrfs solo añade los snapshots cuando se regenera grub.cfg.
  local cfg=/boot/grub/grub.cfg
  if [[ -f $cfg ]]; then
    sudo grub-mkconfig -o "$cfg"
    ok "grub-btrfs: los snapshots aparecen en el menú de GRUB (submenú «Arch Linux snapshots»); grub-btrfsd lo mantiene al día"
  else
    warn "No encuentro $cfg: regenera tu menú a mano con  sudo grub-mkconfig -o <ruta de tu grub.cfg>"
  fi
  note "Los snapshots arrancan en solo lectura. Para poder arrancarlos de verdad, añade el hook «grub-btrfs-overlayfs» al final de HOOKS en /etc/mkinitcpio.conf y ejecuta  sudo mkinitcpio -P"
}

setup_limine() {
  if ! pacman -Qq mkinitcpio &>/dev/null; then
    warn "Limine con snapshots necesita mkinitcpio (tienes otro generador de initramfs). Alternativa en el AUR: limine-dracut-support."
    return 0
  fi
  local helper; helper=$(aur_helper) || helper=""
  if [[ -z $helper ]]; then
    warn "Hace falta paru o yay (AUR) para limine-snapper-sync. Ejecuta antes ./1-install.sh (compila paru) y vuelve a lanzar este script."
    return 0
  fi
  if ! confirm "Instalar limine-mkinitcpio-hook y limine-snapper-sync desde el AUR con $helper?" s; then
    warn "Omitido: los snapshots funcionan, pero no saldrán en el menú de Limine."; return 0
  fi
  "$helper" -S --needed limine-mkinitcpio-hook limine-snapper-sync || { warn "Falló la instalación desde el AUR; reintenta más tarde."; return 0; }
  if systemctl list-unit-files limine-snapper-sync.service --no-legend 2>/dev/null | grep -q .; then
    sudo systemctl enable --now limine-snapper-sync.service
  else
    warn "No encuentro limine-snapper-sync.service: revisa  pacman -Ql limine-snapper-sync | grep service"
  fi
  local conf; conf=$(limine_conf)
  ok "Limine: instalado${conf:+ (tu configuración: $conf)}"
  cat <<'MSG'
     Falta una vez, a mano (no lo hago solo para no tocar tu limine.conf sin que lo veas):
       1. Revisa /etc/default/limine (ESP_PATH, KERNEL_CMDLINE y, si hace falta, ENABLE_UKI/ENABLE_LIMINE_FALLBACK).
       2. sudo limine-mkinitcpio        → genera las entradas de arranque
       3. sudo limine-snapper-sync      → añade los snapshots al menú (después lo hace el servicio solo)
     Ajustes (nº de entradas, uso de la ESP…): /etc/limine-snapper-sync.conf
     Consejo: con muchos snapshots la ESP se llena, porque se copia un kernel por entrada. Usa una ESP de 1 GiB o más.
MSG
}

case "$BL" in
  grub)   setup_grub ;;
  limine) setup_limine ;;
  none)   note "Sin integración en el menú de arranque (--bootloader none)." ;;
  *)      warn "Gestor «$BL»: los snapshots se crean igual, pero no salen en el menú de arranque."
          note "Si el sistema no arranca: entra desde un USB de Arch, monta el subvolumen raíz y restaura con snapper o btrfs (wiki de Arch: Snapper → Restoring)."
          note "Si usas GRUB o Limine y no se detectó: ./5-snapshots.sh --bootloader grub|limine" ;;
esac

sudo snapper -c root create -d "ink: estado inicial"
ok "Listo. Ver: sudo snapper -c root list · Volver atrás: sudo snapper -c root undochange N..M"
warn "Los snapshots viven en el MISMO disco: protegen de un mal pacman -Syu, NO de un disco roto. Haz copias externas de lo importante."
warn "/home no se incluye (tu trabajo no se revierte). Si /boot está en la ESP (vfat), el kernel no vuelve atrás: tras restaurar, reinstala con «sudo pacman -S linux»."
