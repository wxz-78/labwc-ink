#!/usr/bin/env bash
# ============================================================
# 6-wine.sh — Wine Staging + winetricks y un prefijo listo para «casi todo» de Windows.
# Úsalo como usuario normal (pide sudo solo para instalar paquetes):  ./6-wine.sh
# Es idempotente: si se corta o algo falla, vuelve a lanzarlo y solo hace lo que falta. NUNCA borra un prefijo.
#
# Cómo es Wine en Arch hoy (comprobado en archlinux.org, wine-staging 11.x):
#   · Es «nuevo WoW64»: no necesita librerías lib32-* y ejecuta 32 y 64 bits en el MISMO prefijo.
#     Por eso ya NO existen prefijos solo de 32 bits (WINEARCH=win32 da error) ni se ejecutan programas de 16 bits.
#   · wine-staging provee «wine» y CONFLICTA con el paquete wine: se sustituye (los prefijos existentes no se tocan).
#   · ntsync viene de serie (dependencia ntsync-autoload): mejor rendimiento sin configurar nada.
#
# Máxima compatibilidad: por defecto SOLO se instala lo que no sustituye DLL propias de Wine Staging (vcrun2022, msxml,
# mfc42, vb6run, d3dx*). Cada DLL nativa de Microsoft que pisa a la de Wine es una posible fuente de ventanas en negro,
# entradas rotas o audio entrecortado, y Wine Staging ya trae parches y versiones propias de casi todas.
#
# Variables opcionales:
#   INK_WINEPREFIX=ruta     prefijo a crear/completar (por defecto el de Wine: ~/.wine)
#   INK_WINE_LEGACY=1       añade DLL nativas para juegos/programas antiguos (d3dcompiler, xact, xinput, dinput8…; ver más abajo)
#   INK_WINE_DXVK=1         instalar también dxvk y vkd3d (solo si los necesitas: ver README, «ventana en negro»)
#   INK_WINE_DOTNET=1       instalar dotnet48 (lento: 10-30 min; por defecto NO: se usa wine-mono)
#   INK_WINE_FIX=1          quitar del registro del prefijo los overrides nativos conflictivos (no borra archivos)
#   INK_WINE_MEDIA=0        no instalar códecs (GStreamer/ffmpeg: vídeos y escenas de los juegos)
#   INK_WINE_EXTRA="a b"    verbos extra de winetricks (p. ej. corefonts)
#   INK_WINE_SKIP="a b"     verbos que NO quieres (p. ej. vkd3d)
#   INK_YES=1               sin preguntas
# ============================================================
set -uo pipefail
case "${1:-}" in
  -h|--help) sed -n '2,/^set /{/^set /!p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
[ "$EUID" -eq 0 ] && { echo "No lo ejecutes como root."; exit 1; }
cd "$(dirname "$0")" || exit 1
source lib/common.sh
command -v pacman >/dev/null 2>&1 || { echo "Este instalador es para Arch Linux (o derivados con pacman)."; exit 1; }
say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
note() { printf '    \033[2m%s\033[0m\n' "$*"; }
warn() { printf '    \033[33m! %s\033[0m\n' "$*"; }
YES=${INK_YES:-0}
PACMAN_FLAGS=(--needed); [ "$YES" = 1 ] && PACMAN_FLAGS+=(--noconfirm)

# ---------- 1. Paquetes ----------
say "Paquetes: wine-staging, winetricks y dependencias"
# Los dos addons de Wine (mono y gecko) vienen como paquetes: wineboot los instala solo, sin descargar nada.
PKGS=(winetricks wine-mono wine-gecko cabextract unzip p7zip curl vulkan-icd-loader alsa-plugins libpulse)
[ "${INK_WINE_MEDIA:-1}" = 0 ] || PKGS+=(ffmpeg gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav)

NEED_STAGING=1; CONFLICT_FLAGS=()
if pacman -Qq wine-staging &>/dev/null; then
  note "wine-staging ya está instalado."; NEED_STAGING=0
elif pacman -Qq wine &>/dev/null; then
  # wine y wine-staging se excluyen: sin --ask 4 pacman pregunta y, con --noconfirm, cancela.
  if confirm "Tienes el paquete «wine»: se sustituirá por wine-staging (tus prefijos no se tocan). ¿Continuar?" s; then
    CONFLICT_FLAGS=(--ask 4)
  else echo "Cancelado: nada se ha modificado."; exit 1; fi
elif [ -z "$(pacman -T wine 2>/dev/null)" ]; then
  warn "Otro paquete ya provee «wine» (AUR/git/personalizado): no lo sustituyo; se usará ese."
  NEED_STAGING=0
  # sus addons (wine-mono/gecko) suelen venir con él y chocarían con los de los repos
  PKGS=("${PKGS[@]/wine-mono/}"); PKGS=("${PKGS[@]/wine-gecko/}")
  mapfile -t PKGS < <(printf '%s\n' "${PKGS[@]}" | grep -v '^$')
fi
[ "$NEED_STAGING" = 1 ] && PKGS=(wine-staging "${PKGS[@]}")
sudo pacman -S "${PACMAN_FLAGS[@]}" "${CONFLICT_FLAGS[@]}" "${PKGS[@]}" || { echo "ERROR: falló la instalación de paquetes."; exit 1; }
sudo pacman -D --asexplicit wine-staging winetricks >/dev/null 2>&1 || true   # que ningún limpiador los vea como huérfanos

command -v wine >/dev/null && command -v winetricks >/dev/null || { echo "ERROR: wine o winetricks no quedaron en el PATH."; exit 1; }
WINEVER=$(wine --version 2>/dev/null)
case $WINEVER in
  *Staging*|*staging*) note "Wine: $WINEVER" ;;
  *) warn "Wine: $WINEVER (no es Staging: funciona igual, pero sin los parches de Staging)." ;;
esac
note "winetricks: $(winetricks --version 2>/dev/null | head -n1)"
[ -e /dev/ntsync ] && note "ntsync: activo" || note "ntsync: no disponible ahora (tras reiniciar puede aparecer; Wine usa esync/fsync mientras tanto)."

# ---------- 2. Entorno limpio y común ----------
# Nada heredado del shell que pueda romper el prefijo (un WINEARCH=win32 antiguo, por ejemplo).
unset WINEARCH WINEPREFIX WINEDLLOVERRIDES WINEDEBUG WINE
export WINEPREFIX="${INK_WINEPREFIX:-$HOME/.wine}"       # el prefijo por defecto de Wine (el mismo que usa «wine» a secas)
export WINEDEBUG="${INK_WINEDEBUG:-fixme-all}"          # sin el ruido de «fixme», pero los errores SÍ quedan en el registro
export WINEDLLOVERRIDES="winemenubuilder.exe=d"         # Wine NO crea accesos en el lanzador ni toca tus asociaciones de archivos
export WINETRICKS_LATEST_VERSION_CHECK=disabled         # sin comprobar/actualizar winetricks por su cuenta (la versión es la de pacman)
mkdir -p "$(dirname "$WINEPREFIX")"

LOGDIR="${XDG_STATE_HOME:-$HOME/.local/state}/ink-wine"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/setup-$(date +%Y%m%d-%H%M%S).log"
note "Prefijo: $WINEPREFIX"
note "Registro: $LOG"

# Wine puede tocar mimeapps.list al registrar tipos de archivo; esta copia permite revertirlo.
MIME="$HOME/.config/mimeapps.list"; MIME_BAK=""
if [ -f "$MIME" ]; then MIME_BAK=$(mktemp); cp -p "$MIME" "$MIME_BAK"; fi

# ---------- 3. Prefijo ----------
say "Prefijo de Wine"
if [ -f "$WINEPREFIX/system.reg" ]; then
  note "Ya existe: se completa lo que falte (no se borra nada)."
else
  echo "Creando el prefijo (primera vez, puede tardar un minuto)…"
  wineboot -u >>"$LOG" 2>&1
  wineserver -w
  [ -f "$WINEPREFIX/system.reg" ] || { echo "ERROR: no se creó el prefijo; mira $LOG"; exit 1; }
fi
# Desactiva winemenubuilder dentro del prefijo (aunque luego lances wine sin nuestro entorno)
wine reg add 'HKCU\Software\Wine\DllOverrides' /v winemenubuilder.exe /t REG_SZ /d '' /f >>"$LOG" 2>&1 || true
wineserver -w

# Overrides nativos conflictivos: winetricks los deja en el registro y hacen que Wine use la DLL de Microsoft en vez de la suya.
# INK_WINE_FIX=1 los quita del registro (NO borra ningún archivo): Wine vuelve a cargar sus DLL integradas.
if [ "${INK_WINE_FIX:-0}" = 1 ]; then
  say "Quitando overrides nativos conflictivos del registro"
  for d in gdiplus riched20 riched32 wininet dinput dinput8 xinput1_1 xinput1_2 xinput1_3 xinput1_4 xinput9_1_0 \
           d3dcompiler_43 d3dcompiler_46 d3dcompiler_47 d3d8 d3d9 d3d10core d3d11 d3d12 d3d12core dxgi; do
    wine reg delete 'HKCU\Software\Wine\DllOverrides' /v "$d" /f >>"$LOG" 2>&1 || true
  done
  wineserver -w
  note "Hecho. Si algún programa necesitaba una de esas DLL nativas, instálala con INK_WINE_EXTRA=\"verbo\"."
fi

# ---------- 4. Verbos de winetricks ----------
say "winetricks (cada verbo por separado: si uno falla, los demás siguen)"
AVAIL=$(winetricks list-all 2>/dev/null | awk '{print $1}')
INSTALLED=$(winetricks list-installed 2>/dev/null)
read -r -a SKIP <<< "${INK_WINE_SKIP:-}"
FAILED=(); DONE=(); SKIPPED=()

# tricks «verbo» o «verbo1|verbo2» (el primero que exista en TU winetricks) con reintento y límite de tiempo
tricks() {
  local cand v="" s
  IFS='|' read -r -a cand <<< "$1"
  for c in "${cand[@]}"; do grep -qxF -- "$c" <<<"$AVAIL" && { v=$c; break; }; done
  if [ -z "$v" ]; then warn "Sin verbo «$1» en tu winetricks: se omite."; SKIPPED+=("$1"); return 0; fi
  for s in "${SKIP[@]:-}"; do [ "$s" = "$v" ] && { note "$v: omitido por INK_WINE_SKIP"; return 0; }; done
  if grep -qxF -- "$v" <<<"$INSTALLED"; then note "$v: ya instalado"; return 0; fi
  printf '  · %-16s' "$v"
  local rc limit=900; [ "$v" = dotnet48 ] && limit=5400
  timeout "$limit" winetricks -q "$v" >>"$LOG" 2>&1; rc=$?
  if [ $rc -ne 0 ]; then   # un segundo intento: muchas descargas fallan una vez por la red
    [ $rc -eq 124 ] && wineserver -k 2>/dev/null
    timeout "$limit" winetricks -q "$v" >>"$LOG" 2>&1; rc=$?
  fi
  wineserver -w 2>/dev/null
  if [ $rc -eq 0 ]; then echo "ok"; DONE+=("$v"); INSTALLED+=$'\n'"$v"
  else echo "FALLÓ (ver registro)"; FAILED+=("$v"); [ $rc -eq 124 ] && wineserver -k 2>/dev/null; fi
}

# 4.1 Núcleo (siempre): bibliotecas que Wine NO trae y que NO pisan DLL de Wine.
#   vcrun2022 cubre 2015-2022 (vcrun2015 sobra). msxml3/6 son los analizadores XML que piden muchos instaladores.
#   Se quitaron de la lista habitual, porque sustituyen DLL propias de Wine y suelen dar más problemas que soluciones:
#     gdiplus, riched20, wininet  (la versión de Wine funciona mejor; la de Microsoft rompe texto, redes y SSL)
for v in vcrun2022 mfc42 msxml3 msxml6 vb6run; do tricks "$v"; done

# 4.2 DirectX auxiliar (siempre): d3dx9/10/11 son archivos con versión en el nombre (d3dx9_43.dll…): añaden, no pisan d3d9/d3d11.
#   «d3dx11» NO es un verbo: son d3dx11_42 y d3dx11_43.  «faudio» sobra: Wine ya trae FAudio.
VULKAN=0
if ls /usr/share/vulkan/icd.d/*.json >/dev/null 2>&1 || ls /etc/vulkan/icd.d/*.json >/dev/null 2>&1; then VULKAN=1; fi
for v in d3dx9 'd3dx10|d3dx10_43' d3dx11_42 d3dx11_43; do tricks "$v"; done

# 4.3 Solo para programas antiguos (INK_WINE_LEGACY=1): DLL nativas que SÍ pisan las de Wine. Úsalo solo si un programa concreto lo pide.
#   d3dcompiler_*: pisan el compilador de shaders de Wine (a veces dan pantalla en negro)  · xinput/dinput8: pisan la entrada de mandos y teclado
#   xact/xact_x64: pisan el audio XACT (que Wine ya hace con FAudio) · openal, directmusic, directplay, xna40: obsoletos
if [ "${INK_WINE_LEGACY:-0}" = 1 ]; then
  warn "INK_WINE_LEGACY=1: se instalan DLL nativas que pisan las de Wine (si algo falla, prueba sin esta opción)."
  for v in d3dcompiler_43 d3dcompiler_46 d3dcompiler_47 xact xact_x64 xinput dinput8 openal directmusic directplay xna40; do tricks "$v"; done
else
  note "DLL nativas que pisan las de Wine (d3dcompiler, xinput, dinput8, xact…): no se instalan. Programas antiguos: INK_WINE_LEGACY=1"
fi

# 4.4 DXVK y vkd3d REEMPLAZAN las DLL de Direct3D del prefijo por versiones que usan Vulkan. Si el controlador Vulkan falla,
#     la ventana se abre en negro y sin mensajes. Por eso son opcionales: INK_WINE_DXVK=1 (y solo con Vulkan funcionando).
if [ "${INK_WINE_DXVK:-0}" = 1 ]; then
  if [ "$VULKAN" = 1 ]; then
    tricks dxvk; tricks vkd3d
  else
    warn "INK_WINE_DXVK=1 pero no hay controlador Vulkan (ICD): se omiten dxvk y vkd3d."
    warn "Instala el de tu GPU (vulkan-intel / vulkan-radeon / nvidia-utils) y vuelve a lanzar ./6-wine.sh"
  fi
else
  note "dxvk/vkd3d: no se instalan (Wine usa su Direct3D propio). Para activarlos: INK_WINE_DXVK=1 ./6-wine.sh"
fi

# 4.5 .NET Framework 4.8: opcional. Sustituye a Wine Mono (que ya viene como paquete y corre casi todo lo de .NET),
#     toca decenas de DLL y suele fallar en prefijos WoW64. Solo si un programa exige .NET 4.8 de verdad: INK_WINE_DOTNET=1.
if [ "${INK_WINE_DOTNET:-0}" = 1 ]; then
  echo "  (dotnet48 puede tardar 10-30 minutos y abrir ventanas del instalador: no las cierres)"; tricks dotnet48
else
  note "dotnet48: no se instala (se usa wine-mono). Si un programa lo exige: INK_WINE_DOTNET=1"
fi

# 4.6 Extras del usuario
read -r -a EXTRA <<< "${INK_WINE_EXTRA:-}"
for v in "${EXTRA[@]:-}"; do [ -n "$v" ] && tricks "$v"; done

# 4.5 Versión de Windows: SIEMPRE lo último. Varios verbos (vcrun, dotnet…) la dejan en win7 al terminar; así queda win10.
printf '  · %-16s' win10
if winetricks -q win10 >>"$LOG" 2>&1; then echo "ok"; else echo "FALLÓ (ver registro)"; FAILED+=(win10); fi
wineserver -w 2>/dev/null

# ---------- 5. Protección de tus archivos de configuración ----------
if [ -n "$MIME_BAK" ]; then
  if ! cmp -s "$MIME" "$MIME_BAK"; then
    cat "$MIME_BAK" > "$MIME"; warn "Wine había modificado ~/.config/mimeapps.list: se ha restaurado."
  fi
  rm -f "$MIME_BAK"
fi

# ---------- 6. Resumen ----------
say "Resumen"
printf '  Instalados ahora: %s\n' "${DONE[*]:-ninguno (ya estaba todo)}"
[ ${#SKIPPED[@]} -gt 0 ] && printf '  Sin verbo en tu winetricks: %s\n' "${SKIPPED[*]}"
if [ ${#FAILED[@]} -gt 0 ]; then
  printf '  \033[33mFallaron: %s\033[0m\n  Vuelve a lanzar ./6-wine.sh (solo repite lo que falta) o revisa %s\n' "${FAILED[*]}" "$LOG"
fi
cat <<MSG

✔ Wine listo.  Prefijo: $WINEPREFIX
  Ejecutar un programa:   ink-wine programa.exe       (también .msi y .bat)
  Ajustes / winetricks:   ink-wine cfg  ·  ink-wine tricks <verbo>
  Estado y diagnóstico:   ink-wine info  ·  ink-doctor
MSG
[ ${#FAILED[@]} -eq 0 ]
