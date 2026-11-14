#!/usr/bin/env bash
# check.sh — valida el repositorio sin instalar nada (útil antes de hacer commit).
#   · sintaxis de todos los scripts (bash -n; shellcheck si está instalado)
#   · XML (rc.xml, menu.xml), JSONC (waybar, fastfetch), config.fish (si hay fish) y permisos de bin/
#   · que cada atajo «Super+…» de la chuleta (bin/keys) exista en rc.xml
#   · que no haya atajos duplicados y que los comandos propios existan
#   · formato de archivos (sin CRLF, con shebang, ejecutables) y scripts de bin/ sin uso
#   · que cada programa que usan las configs lo instale 1-install.sh
#   · que 6-wine.sh no vuelva a instalar por defecto DLL nativas conflictivas
#   · una instalación real de dotfiles.sh en un HOME temporal (idempotente y sin tocar tu sesión)
# Uso:  ./check.sh      (sale con error si algo falla)
set -uo pipefail
cd "$(dirname "$0")" || exit 1
fail=0
ok()  { printf '\e[32m✔\e[0m %s\n' "$*"; }
bad() { printf '\e[31m✘\e[0m %s\n' "$*"; fail=1; }

# --- shell ---
for f in *.sh lib/*.sh bin/* .config/labwc/autostart; do
    # lib/common.sh no tiene shebang pero usa bash (arrays, [[ ]]): se valida como bash
    if head -n1 "$f" | grep -q 'bash' || [ "$f" = lib/common.sh ]; then syntax="bash"; else syntax="sh"; fi
    out=$($syntax -n "$f" 2>&1) && ok "sintaxis $f" || bad "$f: $out"
done
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning -x *.sh lib/*.sh bin/* >/dev/null 2>&1 && ok "shellcheck" || bad "shellcheck reporta avisos (ejecútalo a mano)"
else
    echo "· shellcheck no instalado (opcional): sudo pacman -S shellcheck"
fi

# --- fish (config.fish: solo se comprueba la sintaxis, no se ejecuta) ---
if command -v fish >/dev/null 2>&1; then
    fish --no-execute .config/fish/config.fish 2>/dev/null && ok "sintaxis config.fish" || bad "config.fish tiene errores de sintaxis (fish --no-execute)"
else
    echo "· fish no instalado: se omite la sintaxis de config.fish"
fi

# --- scripts ejecutables (un zip o un checkout sin permisos rompe los atajos) ---
for f in bin/*; do
    [ -x "$f" ] || bad "bin/${f#bin/} no es ejecutable"
done
ok "permisos de bin revisados"

# --- XML ---
if command -v xmllint >/dev/null 2>&1; then
    for f in .config/labwc/rc.xml .config/labwc/menu.xml; do
        xmllint --noout "$f" 2>/dev/null && ok "XML $f" || bad "XML inválido: $f"
    done
else
    echo "· xmllint no instalado (libxml2): se omite la validación de XML"
fi

# --- JSONC (se quitan los comentarios //) ---
if command -v jq >/dev/null 2>&1; then
    for f in .config/waybar/config.jsonc .config/fastfetch/config.jsonc; do
        sed 's|^[[:space:]]*//.*$||' "$f" | jq -e . >/dev/null 2>&1 && ok "JSON $f" || bad "JSON inválido: $f"
    done
else
    echo "· jq no instalado: se omite la validación de JSON"
fi

# --- la chuleta (bin/keys) no debe enseñar atajos que ya no existen en rc.xml ---
# Se comprueban los atajos simples «Super+X» (letras, números y F1…F12).
rc=.config/labwc/rc.xml
while read -r k; do
    key=${k#Super+}
    grep -qiE "key=\"[A-Za-z-]*W-${key}\"" "$rc" || bad "bin/keys menciona Super+$key y no está en rc.xml"
done < <(grep -oE 'Super\+[A-Za-z0-9]{1,2}( |$)' bin/keys | tr -d ' ' | sort -u)
ok "chuleta de atajos revisada"

# --- atajos duplicados: labwc solo conserva uno y el otro deja de funcionar en silencio ---
dups=$(grep -oE '<keybind key="[^"]+"' "$rc" | sed 's/.*key="//;s/"$//' | sort | uniq -d)
if [ -n "$dups" ]; then
    bad "atajos duplicados en rc.xml: $(printf '%s ' $dups)"
else
    ok "sin atajos duplicados"
fi

# --- comandos propios citados en rc.xml: deben existir en bin/ (los del sistema no se comprueban) ---
for c in $(grep -oE '<command>[^<]+' "$rc" | sed 's/<command>//' | awk '{print $1}' | sort -u); do
    case $c in
        sh|bash|foot|helium-browser|cliphist|makoctl|playerctl|systemctl|labwc) continue ;;
    esac
    [ -f "bin/$c" ] || continue
    [ -x "bin/$c" ] || bad "rc.xml usa $c pero bin/$c no es ejecutable"
done
ok "comandos de rc.xml revisados"

# --- formato: un CRLF (típico al pasar por Windows o un zip) rompe los scripts con «\r: orden no encontrada» ---
crlf=0
for f in *.sh lib/*.sh bin/* .config/labwc/autostart .config/labwc/environment; do
    if grep -q $'\r' "$f"; then bad "$f tiene saltos de línea CRLF (dos2unix $f)"; crlf=1; fi
done
[ "$crlf" = 0 ] && ok "sin saltos de línea CRLF"

# --- todos los scripts llevan shebang y los de la raíz son ejecutables ---
for f in *.sh bin/* .config/labwc/autostart; do   # lib/common.sh se carga con «source»: no lleva shebang
    head -n1 "$f" | grep -q '^#!' || bad "$f no empieza con #! (shebang)"
done
for f in [0-9]-*.sh dotfiles.sh install.sh check.sh .config/labwc/autostart; do
    [ -x "$f" ] || bad "$f no es ejecutable (chmod +x $f)"
done
ok "shebang y permisos de scripts revisados"

# --- un script de bin/ que nadie llama es código muerto (o un atajo que se perdió) ---
for f in bin/*; do
    n=${f#bin/}
    grep -rIqw --exclude-dir=.git --exclude="$n" -- "$n" . || bad "bin/$n no se usa en ningún sitio (atajo, barra, script o README)"
done
ok "scripts de bin/ con uso revisados"

# --- programas que usan las configs y scripts: deben instalarse en 1-install.sh ---
declare -A PKG_OF=(
    [foot]=foot [fuzzel]=fuzzel [waybar]=waybar [mako]=mako [makoctl]=mako [swaylock]=swaylock [swayidle]=swayidle
    [swaybg]=swaybg [wf-recorder]=wf-recorder [cliphist]=cliphist [wl-copy]=wl-clipboard [wl-paste]=wl-clipboard
    [grim]=grim [slurp]=slurp [brightnessctl]=brightnessctl [notify-send]=libnotify [wlsunset]=wlsunset
    [pactl]=libpulse [wpctl]=wireplumber [udiskie]=udiskie [wlr-randr]=wlr-randr [nmcli]=networkmanager
    [nmtui]=networkmanager [thunar]=thunar [playerctl]=playerctl [jq]=jq [wiremix]=wiremix [bluetui]=bluetui
)
pkgmiss=0
for c in "${!PKG_OF[@]}"; do
    if grep -rIqw -- "$c" bin .config/labwc .config/waybar 2>/dev/null && ! grep -qw -- "${PKG_OF[$c]}" 1-install.sh; then
        bad "se usa «$c» pero 1-install.sh no instala ${PKG_OF[$c]}"; pkgmiss=1
    fi
done
[ "$pkgmiss" = 0 ] && ok "los programas usados están en 1-install.sh"

# --- 6-wine.sh: guardia contra una regresión que ya dio ventanas en negro ---
# Estas DLL nativas pisan las de Wine Staging: solo pueden instalarse dentro de INK_WINE_LEGACY (o con INK_WINE_EXTRA).
wine_bad=$(grep -nE '^[^#]*\btricks\b' 6-wine.sh | grep -wE 'gdiplus|riched20|wininet' || true)
[ -z "$wine_bad" ] && ok "6-wine.sh: sin gdiplus/riched20/wininet por defecto" || bad "6-wine.sh instala DLL conflictivas por defecto: $wine_bad"
if grep -nE '^[^#]*WINEDEBUG=-all' 6-wine.sh bin/ink-wine | grep -q .; then
    bad "WINEDEBUG=-all oculta los errores de Wine (usa fixme-all)"
else
    ok "Wine muestra los errores (sin WINEDEBUG=-all)"
fi

# --- instalación real en un HOME temporal: copia todo, conserva permisos y es idempotente ---
# INK_NO_RELOAD=1 evita que reinicie tu waybar o recargue tu labwc.
tmp=$(mktemp -d)
if HOME="$tmp" INK_YES=1 INK_NO_RELOAD=1 ./dotfiles.sh </dev/null >"$tmp/.log" 2>&1; then
    ok "dotfiles.sh instala en un HOME vacío"
    diff_n=0
    while IFS= read -r -d '' f; do
        rel=${f#./}
        cmp -s "$f" "$tmp/$rel" || { bad "instalado distinto o ausente: $rel"; diff_n=1; }
        if [ -x "$f" ] && [ ! -x "$tmp/$rel" ]; then bad "se perdió el permiso de ejecución: $rel"; diff_n=1; fi
    done < <(find .config .local -type f -print0)
    [ "$diff_n" = 0 ] && ok "todos los archivos instalados son idénticos"
    ls -d "$tmp"/.ink-backup-* >/dev/null 2>&1 && bad "dotfiles.sh respaldó algo en un HOME vacío"
    again=$(HOME="$tmp" ./dotfiles.sh --dry-run </dev/null 2>&1 | grep -E '^(copiaría|respaldaría|daría)' || true)
    [ -z "$again" ] && ok "dotfiles.sh es idempotente (la 2.ª pasada no cambia nada)" || bad "la 2.ª pasada de dotfiles.sh aún cambiaría algo:
$again"
else
    bad "dotfiles.sh falló en un HOME vacío:
$(sed 's/^/    /' "$tmp/.log")"
fi
rm -rf "$tmp"

exit $fail
