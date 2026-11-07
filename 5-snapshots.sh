#!/usr/bin/env bash
# 5-snapshots.sh — instantáneas del sistema con snapper + snap-pac (btrfs).
#   · snap-pac hace un snapshot ANTES y otro DESPUÉS de cada operación de pacman: si una actualización rompe algo, vuelves atrás.
#   · snapper hace snapshots por horas/días y borra los viejos solo (límites bajos para no llenar el disco).
# Uso:  ./5-snapshots.sh [--grub]      (--grub: añade los snapshots al menú de GRUB con grub-btrfs)
#       ./5-snapshots.sh --status      (lista los snapshots)
# Solo funciona si la raíz (/) es btrfs. En ext4/xfs no hay snapshots de sistema: te lo explica y sale.
set -euo pipefail
[[ $EUID -eq 0 ]] || exec sudo bash "$0" "$@"
ok()   { printf '\e[32m[ok]\e[0m %s\n' "$*"; }
warn() { printf '\e[33m[!]\e[0m %s\n' "$*"; }

if [[ "${1:-}" == "--status" ]]; then snapper -c root list; exit 0; fi
GRUB=0; [[ "${1:-}" == "--grub" ]] && GRUB=1

fs=$(findmnt -no FSTYPE /)
if [[ $fs != btrfs ]]; then
  warn "Tu raíz es $fs, no btrfs: snapper no puede hacer snapshots instantáneos."
  cat <<'MSG'
     Opciones: reinstalar con btrfs (subvolúmenes @ y @home), o usar Timeshift en modo rsync
     (sudo pacman -S timeshift: copia completa, más lenta y pesada) o una copia externa con restic/borg.
MSG
  exit 0
fi

pacman -S --needed --noconfirm snapper snap-pac

if snapper list-configs 2>/dev/null | awk 'NR > 2 && $1 == "root" {f = 1} END {exit !f}'; then
  ok "snapper ya tiene configuración para /"
elif [[ -e /.snapshots ]]; then
  warn "/.snapshots ya existe pero snapper no tiene configuración para /."
  echo "     Revisa tu disposición de subvolúmenes (wiki de Arch: Snapper → «Configuration of snapper and mount point»)."
  exit 1
else
  snapper -c root create-config /
  ok "Configuración creada para /"
fi

# Límites conservadores: pocos snapshots, para que no se coman el disco
snapper -c root set-config \
  TIMELINE_CREATE=yes TIMELINE_LIMIT_HOURLY=5 TIMELINE_LIMIT_DAILY=3 TIMELINE_LIMIT_WEEKLY=0 \
  TIMELINE_LIMIT_MONTHLY=0 TIMELINE_LIMIT_YEARLY=0 NUMBER_LIMIT=8 NUMBER_LIMIT_IMPORTANT=4
systemctl enable --now snapper-timeline.timer snapper-cleanup.timer

if (( GRUB )); then
  pacman -S --needed --noconfirm grub-btrfs inotify-tools
  systemctl enable --now grub-btrfsd.service
  ok "grub-btrfs: los snapshots aparecen en el menú de GRUB (submenú «Arch Linux snapshots»)"
fi

snapper -c root create -d "ink: estado inicial"
ok "Listo. Ver: sudo snapper -c root list · Volver atrás: sudo snapper -c root undochange N..M"
warn "Los snapshots viven en el MISMO disco: protegen de un mal pacman -Syu, NO de un disco roto. Haz copias externas de lo importante."
warn "/home no se incluye (tu trabajo no se revierte). Si /boot está en la ESP (vfat), el kernel no vuelve atrás: tras restaurar, reinstala con «sudo pacman -S linux»."
