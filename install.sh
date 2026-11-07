#!/usr/bin/env bash
# install.sh — instalador guiado. Ejecuta los pasos en orden y te pregunta por los opcionales.
# Uso:  ./install.sh          (te va preguntando)
#       ./install.sh --yes    (acepta las respuestas recomendadas, sin preguntar)
set -euo pipefail
[ "$EUID" -eq 0 ] && { echo "No lo ejecutes como root; pedirá sudo cuando haga falta."; exit 1; }
cd "$(dirname "$0")"
YES=0; [ "${1:-}" = "--yes" ] && YES=1

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
# ask "pregunta" s|n  → devuelve 0 si la respuesta es «sí». El segundo argumento es la respuesta por defecto.
ask() {
  local def=$2 hint="[S/n]" r
  [ "$def" = n ] && hint="[s/N]"
  if [ "$YES" = 1 ]; then [ "$def" = s ]; return; fi
  read -rp "$1 $hint " r
  r=${r:-$def}
  [[ $r =~ ^[sSyY]$ ]]
}

say "Paso 1 de 2 · Programas y sesión de inicio"
./1-install.sh

say "Paso 2 de 2 · Configuración personal (tus archivos actuales se respaldan antes)"
./dotfiles.sh

say "Extras opcionales"
if ask "¿Optimizar el sistema (memoria, disco, arranque y batería)?" s; then ./2-optimize.sh; fi
if ask "¿Activar privacidad y seguridad (DNS cifrado, firewall)?" s; then ./3-privacy.sh; fi
if ask "¿Quitar programas que no se usan (wine, herramientas de compilación…)?" n; then ./4-cleanup.sh; fi
if [ "$(findmnt -no FSTYPE /)" = btrfs ] && ask "Tu disco es btrfs: ¿crear copias de seguridad automáticas del sistema?" s; then ./5-snapshots.sh; fi

cat <<'MSG'

✔ Todo listo. Reinicia el equipo y entra con tu usuario.
  Una vez dentro, pulsa Super+F1 para ver todos los atajos (Super = tecla de Windows).
MSG
