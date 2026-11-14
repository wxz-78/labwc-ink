#!/usr/bin/env bash
# install.sh — instalador guiado. Ejecuta los pasos en orden y te pregunta por los opcionales.
# Uso:  ./install.sh          (te va preguntando)
#       ./install.sh --yes    (acepta las respuestas recomendadas, sin preguntar)
set -euo pipefail
[ "$EUID" -eq 0 ] && { echo "No lo ejecutes como root; pedirá sudo cuando haga falta."; exit 1; }
cd "$(dirname "$0")" || exit 1
YES=0
case "${1:-}" in
  "") ;;
  --yes) YES=1 ;;
  -h|--help) sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "uso: $0 [--yes]" >&2; exit 1 ;;
esac
export INK_YES=$YES   # los scripts hijos también dejan de preguntar

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
if ask "¿Quitar programas que no se usan (herramientas de compilación, Qt5, paquetes huérfanos…)?" n; then ./4-cleanup.sh; fi
if [ "$(findmnt -no FSTYPE /)" = btrfs ] && ask "Tu disco es btrfs: ¿crear copias de seguridad automáticas del sistema (con GRUB o Limine salen en el menú de arranque)?" s; then ./5-snapshots.sh; fi

if ask "¿Instalar Wine Staging + winetricks y preparar un prefijo para programas y juegos de Windows? (compatibilidad máxima: solo DLL que no pisan las de Wine)" n; then ./6-wine.sh || echo "Wine: terminó con avisos; revisa el resumen y vuelve a lanzar ./6-wine.sh si hace falta."; fi

cat <<'MSG'

✔ Todo listo. Reinicia el equipo y entra con tu usuario.
  Una vez dentro, pulsa Super+F1 para ver todos los atajos (Super = tecla de Windows).
MSG
