#!/usr/bin/env bash
# dotfiles.sh — copia .config/ y .local/ a ~ con copia de seguridad.
# Uso:  ./dotfiles.sh [--dry-run]   (--dry-run solo muestra qué haría)
#       ./dotfiles.sh --restore [CARPETA]   devuelve lo que se respaldó (la última copia ~/.ink-backup-*, o la que indiques)
# Variables: INK_YES=1 (sin preguntas) · INK_NO_RELOAD=1 (no reinicia waybar/mako ni recarga labwc: lo usa check.sh)
# · Lo que ya existía se mueve a ~/.ink-backup-FECHA/ (nada se borra).
# · Si una carpeta de destino era un enlace simbólico (Colloid, nwg-look…), se respalda el enlace
#   y se crea una carpeta real: así nunca se modifica el tema original al que apuntaba.
# · --restore: lo que hay ahora en esos sitios se respalda de nuevo (nada se pierde) y vuelve lo anterior. Los archivos
#   que no existían antes de instalar no tienen copia: se quedan (bórralos a mano si no los quieres).
set -euo pipefail
cd "$(dirname "$0")" || exit 1
bak="$HOME/.ink-backup-$(date +%Y%m%d-%H%M%S)"
while [ -e "$bak" ]; do bak="$bak+"; done   # dos ejecuciones en el mismo segundo no deben pisar una copia
moved=0
env_new=0
DRY=0
RESTORE=0
RDIR=""
for a in "$@"; do
    case "$a" in
        --dry-run) DRY=1 ;;
        --restore) RESTORE=1 ;;
        -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) echo "uso: $0 [--dry-run] [--restore [CARPETA]]" >&2; exit 1 ;;
        *)  if [ "$RESTORE" = 1 ] && [ -z "$RDIR" ]; then RDIR=$a; else echo "uso: $0 [--dry-run] [--restore [CARPETA]]" >&2; exit 1; fi ;;
    esac
done

backup() {   # $1 = ruta relativa a ~ (archivo o enlace)
    moved=$((moved+1))
    if [ "$DRY" = 1 ]; then echo "respaldaría  ~/$1"; return; fi
    mkdir -p "$bak/$(dirname "$1")"
    mv "$HOME/$1" "$bak/$1"
}

# --- Restaurar: copia de vuelta lo que había antes de instalar ---
if [ "$RESTORE" = 1 ]; then
    if [ -z "$RDIR" ]; then RDIR=$(find "$HOME" -maxdepth 1 -type d -name '.ink-backup-*' 2>/dev/null | sort | tail -n1); fi
    [ -n "$RDIR" ] && [ -d "$RDIR" ] || { echo "No hay copias en ~/.ink-backup-*: nada que restaurar." >&2; exit 1; }
    RDIR=${RDIR%/}
    echo "Restaurando desde $RDIR"
    n=0
    while IFS= read -r -d '' f; do
        rel=${f#"$RDIR"/}
        { [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ]; } && backup "$rel"
        n=$((n+1))
        if [ "$DRY" = 1 ]; then echo "restauraría  ~/$rel"; continue; fi
        mkdir -p "$HOME/$(dirname "$rel")"
        cp -a "$f" "$HOME/$rel"
    done < <(find "$RDIR" -mindepth 1 \( -type f -o -type l \) -print0)
    [ "$n" -gt 0 ] || { echo "La carpeta $RDIR está vacía."; exit 1; }
    if [ "$DRY" = 1 ]; then echo "(simulación: no se ha cambiado nada)"; exit 0; fi
    echo "✔ $n elemento(s) restaurados. Lo que había antes de restaurar quedó en $bak. Reinicia la sesión (o labwc --reconfigure)."
    exit 0
fi

# waybar lee ~/.config/waybar/config (sin extensión) antes que config.jsonc: un archivo viejo así taparía la barra nueva.
# También hay que respaldar enlaces simbólicos: si se dejan, siguen tapando la configuración nueva.
for old in .config/waybar/config .config/waybar/config.json; do
    if [ -e "$HOME/$old" ] || [ -L "$HOME/$old" ]; then backup "$old"; fi
done

while IFS= read -r -d '' f; do
    rel=${f#./}
    # 1) ningún directorio intermedio puede ser un enlace simbólico
    dir=$(dirname "$rel"); acc=""
    IFS=/ read -ra parts <<< "$dir"
    for p in "${parts[@]}"; do
        acc="${acc:+$acc/}$p"
        [ -L "$HOME/$acc" ] && backup "$acc"
    done
    # 2) si ya es idéntico no se toca; si existe y es distinto (o es un enlace), se respalda
    if [ -f "$HOME/$rel" ] && [ ! -L "$HOME/$rel" ] && cmp -s "$f" "$HOME/$rel"; then
        if [ -x "$f" ] && [ ! -x "$HOME/$rel" ]; then
            if [ "$DRY" = 1 ]; then echo "daría +x     ~/$rel"; else chmod 755 "$HOME/$rel"; fi
        fi
        continue
    fi
    { [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ]; } && backup "$rel"
    if [ "$DRY" = 1 ]; then echo "copiaría     ~/$rel"; continue; fi
    mode=644; [ -x "$f" ] && mode=755   # conserva scripts ejecutables (p. ej. labwc/autostart)
    install -Dm"$mode" "$f" "$HOME/$rel"
    if [ "$rel" = ".config/labwc/environment" ]; then env_new=1; fi
done < <(find .config .local -type f -print0)

# Scripts de usuario: los de /usr/local/bin son de root y no se pueden actualizar sin sudo. Se instala una copia
# en ~/.local/bin, que va primero en el PATH de la sesión (ver .config/labwc/environment). Mismo respaldo y
# misma idempotencia que los dotfiles: si el archivo ya es idéntico, no se toca.
for f in bin/*; do
    [ -f "$f" ] || continue
    rel=".local/bin/${f#bin/}"
    if [ -f "$HOME/$rel" ] && [ ! -L "$HOME/$rel" ] && cmp -s "$f" "$HOME/$rel"; then
        continue
    fi
    { [ -e "$HOME/$rel" ] || [ -L "$HOME/$rel" ]; } && backup "$rel"
    if [ "$DRY" = 1 ]; then echo "copiaría     ~/$rel"; continue; fi
    install -Dm755 "$f" "$HOME/$rel"
done

# --- Teclado: la configuración viene en español latinoamericano (latam). Se ofrece cambiarlo solo si el archivo se acaba de instalar ---
env_file="$HOME/.config/labwc/environment"
if [ "$DRY" != 1 ] && [ "$env_new" = 1 ] && [ -t 0 ] && [ "${INK_YES:-0}" != 1 ]; then
    cur=$(sed -n 's/^XKB_DEFAULT_LAYOUT=//p' "$env_file")
    read -rp "Distribución de teclado del escritorio (ej.: latam, es, us, gb, br, fr, de) [${cur:-latam}]: " kb || kb=""
    kb=${kb:-${cur:-latam}}
    if [ "$kb" != "$cur" ]; then
        layouts=$(localectl list-x11-keymap-layouts 2>/dev/null || true)
        if [[ $kb =~ ^[a-z0-9_]+$ ]] && { [ -z "$layouts" ] || grep -qx -- "$kb" <<<"$layouts"; }; then
            sed -i "s/^XKB_DEFAULT_LAYOUT=.*/XKB_DEFAULT_LAYOUT=$kb/" "$env_file"
            if [ "$kb" = latam ]; then
                grep -q '^XKB_DEFAULT_VARIANT=' "$env_file" || echo 'XKB_DEFAULT_VARIANT=deadtilde' >> "$env_file"
            else
                sed -i '/^XKB_DEFAULT_VARIANT=/d' "$env_file"   # la variante «deadtilde» es solo de latam
            fi
            echo "Teclado: $kb (se puede cambiar luego en ~/.config/labwc/environment)"
        else
            echo "«$kb» no es una distribución válida: se deja $cur (lista: localectl list-x11-keymap-layouts)."
        fi
    fi
fi
# Carpeta donde `wallpaper` busca fondos (así existe aunque aún no haya imágenes)
[ "$DRY" = 1 ] || mkdir -p "$HOME/.local/share/backgrounds"

if [ "$moved" -gt 0 ]; then echo "$([ "$DRY" = 1 ] && echo "Se respaldarían" || echo "Respaldo de") $moved elemento(s) en $bak"; else echo "Nada que respaldar."; fi

# --- Lanzador limpio: oculta entradas que no aportan nada (Acerca de Xfce, avisos de Thunar, etc.) ---
# Thunar arrastra libxfce4ui y con él «Acerca de Xfce». No se puede quitar sin quitar Thunar, pero sí ocultar:
# se copia el .desktop original a ~/.local/share/applications con NoDisplay=true (sigue funcionando como
# manejador de archivos; solo deja de salir en fuzzel). Para recuperar una entrada, borra su copia de ahí.
HIDE=(
    xfce4-about.desktop thunar-settings.desktop thunar-bulk-rename.desktop     # Xfce / Thunar
    foot-server.desktop footclient.desktop fish.desktop imv-dir.desktop        # duplicados de terminal, shell y visor
    avahi-discover.desktop bssh.desktop bvnc.desktop lstopo.desktop            # herramientas de red/hardware que nadie lanza
    org.qt-project.qdbusviewer.desktop org.qt-project.assistant.desktop
    org.qt-project.designer.desktop org.qt-project.linguist.desktop             # Qt Tools, si están
)
hidden=0
for id in "${HIDE[@]}"; do
    src="/usr/share/applications/$id"; dst="$HOME/.local/share/applications/$id"
    [ -f "$src" ] || continue
    [ -e "$dst" ] && continue
    hidden=$((hidden+1))
    if [ "$DRY" = 1 ]; then echo "ocultaría    $id"; continue; fi
    mkdir -p "$HOME/.local/share/applications"
    awk '/^\[Desktop Entry\]/{print; print "NoDisplay=true"; next} !/^NoDisplay=/' "$src" > "$dst"
done
[ "$hidden" -gt 0 ] && echo "$([ "$DRY" = 1 ] && echo "Se ocultarían" || echo "Ocultadas") $hidden entrada(s) del lanzador."

[ "$DRY" = 1 ] && { echo "(simulación: no se ha cambiado nada)"; exit 0; }
# Los archivos acaban de volver al acento de fábrica: si elegiste otro con `ink-theme`, se reaplica
bin/ink-theme restore || true
if [ "${INK_NO_RELOAD:-0}" = 1 ]; then echo "✔ Dotfiles copiados (sin recargar nada: INK_NO_RELOAD=1)."; exit 0; fi
# Si waybar está abierto, reinícialo con la configuración nueva (recargar con SIGUSR2 no basta si cambian los módulos)
if pgrep -x waybar >/dev/null; then
    pkill -x waybar; sleep 0.5
    setsid -f waybar -c "$HOME/.config/waybar/config.jsonc" -s "$HOME/.config/waybar/style.css" >/dev/null 2>&1
fi
# mako relee su configuración sin reiniciar las notificaciones visibles
if pgrep -x mako >/dev/null && command -v makoctl >/dev/null 2>&1; then
    makoctl reload >/dev/null 2>&1 || true
fi
# Si labwc está corriendo, recarga la configuración sin cerrar la sesión
if pgrep -x labwc >/dev/null; then labwc --reconfigure && echo "✔ Dotfiles copiados y labwc recargado."
else echo "✔ Dotfiles copiados. Inicia labwc o reinicia la sesión."; fi
