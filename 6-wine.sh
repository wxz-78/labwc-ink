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
# Compatibilidad + rendimiento: por defecto se instala lo que no sustituye DLL propias de Wine Staging (vcrun2022, msxml,
# mfc42, vb6run, d3dx*) y, además, DXVK y vkd3d-proton (Direct3D sobre Vulkan), que son la gran mejora de FPS en juegos.
# Cada DLL nativa de Microsoft que pisa a la de Wine es una posible fuente de ventanas en negro, entradas rotas o audio
# entrecortado; DXVK/vkd3d son la excepción buscada y solo se instalan si hay un controlador Vulkan (ICD) funcionando.
#
# Variables opcionales:
#   INK_WINEPREFIX=ruta     prefijo a crear/completar (por defecto el de Wine: ~/.wine)
#   INK_WINE_LEGACY=1       añade DLL nativas para juegos/programas antiguos (d3dcompiler, xact, xinput, dinput8…; ver más abajo)
#   INK_WINE_DXVK=0         NO instalar dxvk ni vkd3d (por defecto SÍ: Direct3D 8-11 y 12 sobre Vulkan = mucho más rendimiento en juegos)
#   INK_WINE_VKD3D=0        instalar dxvk pero no vkd3d (vkd3d-proton: solo Direct3D 12)
#   INK_WINE_DOTNET=1       instalar dotnet48 (lento: 10-30 min; por defecto NO: se usa wine-mono)
#   INK_WINE_PAD=0          no instalar las reglas udev de mandos (game-devices-udev / steam-devices)
#   INK_WINE_GAMING=1|0     instalar (1) u omitir (0) gamemode y gamescope; sin definir, lo pregunta (con INK_YES=1: sí)
#   INK_WINE_TWEAKS=0       no aplicar los ajustes del prefijo (sin diálogo de fallos, fuentes ClearType)
#   INK_WINE_INPUT_FIX=0    NO reparar los overrides de dinput/xinput. Por defecto se usan las DLL de Wine:
#                           un dinput8 nativo roto hace que joy.cpl no abra y que Wine no vea NINGÚN mando,
#                           aunque Linux sí lo detecte. Con INK_WINE_LEGACY=1 se conservan (los instala a propósito).
#   INK_WINE_FIX=1          quitar del registro otros overrides nativos conflictivos (no borra archivos ni toca DXVK)
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
  # wine y wine-staging se excluyen: --ask=4 (con signo igual, la forma probada) hace que --noconfirm
  # responda «sí» solo a la pregunta de sustitución, en vez de cancelarla con la respuesta por defecto.
  if confirm "Tienes el paquete «wine»: se sustituirá por wine-staging (tus prefijos no se tocan). ¿Continuar?" s; then
    CONFLICT_FLAGS=(--ask=4)
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

# ---------- 1b. Mandos y juegos ----------
# game-devices-udev: reglas udev para que tu usuario pueda usar mandos (PS4/PS5, Xbox, Switch, Steam Controller…) sin root.
# gamemode (modo rendimiento) y gamescope (ventana de juego aislada: arregla ratón que se escapa y escalados raros).
# Ninguno falla la instalación: si un paquete no existe en tus repositorios, se avisa y se sigue.
say "Mandos y juegos"
GAME_PKGS=()
want_pkg() {   # añade a GAME_PKGS solo lo que falta y existe en los repositorios
  if pacman -Qq "$1" &>/dev/null; then note "$1: ya instalado"
  elif pacman -Si "$1" &>/dev/null; then GAME_PKGS+=("$1")
  else warn "$1 no está en tus repositorios (¿extra desactivado?): se omite."; fi
}
# game-devices-udev es de AUR: si no está en los repos, steam-devices (multilib) da permiso a los mismos mandos.
PAD_PKG=""
if [ "${INK_WINE_PAD:-1}" = 0 ]; then
  note "Reglas udev de mandos: omitidas por INK_WINE_PAD=0 (el mando dependerá de los permisos de tu sesión)."
else
  for c in game-devices-udev steam-devices; do
    if pacman -Si "$c" &>/dev/null; then PAD_PKG=$c; break; fi
  done
  if [ -n "$PAD_PKG" ]; then want_pkg "$PAD_PKG"
  else warn "Ni game-devices-udev ni steam-devices están en tus repositorios: el mando dependerá de los permisos de tu sesión (logind)."; fi
fi
WANT_GAMING=${INK_WINE_GAMING:-ask}
if [ "$WANT_GAMING" = ask ]; then
  if confirm "¿Instalar también gamemode y gamescope (rendimiento y ventana de juego aislada)?" s; then WANT_GAMING=1; else WANT_GAMING=0; fi
fi
if [ "$WANT_GAMING" = 1 ]; then want_pkg gamemode; want_pkg gamescope; fi
if [ ${#GAME_PKGS[@]} -gt 0 ]; then
  if sudo pacman -S "${PACMAN_FLAGS[@]}" "${GAME_PKGS[@]}"; then
    sudo pacman -D --asexplicit "${GAME_PKGS[@]}" >/dev/null 2>&1 || true   # que ningún limpiador los vea como huérfanos
  else warn "No se pudieron instalar: ${GAME_PKGS[*]} (el resto sigue; vuelve a lanzar ./6-wine.sh)"; fi
fi
if [ -n "$PAD_PKG" ] && pacman -Qq "$PAD_PKG" &>/dev/null; then
  sudo udevadm control --reload-rules >/dev/null 2>&1 && sudo udevadm trigger --subsystem-match=input --subsystem-match=hidraw >/dev/null 2>&1 || true
  note "Mandos: reglas de $PAD_PKG activas (si no te lo detecta, desconecta y vuelve a conectar el mando)."
fi
if declare -F hw_gamepads >/dev/null 2>&1; then
  PADS=$(hw_gamepads 2>/dev/null || true)
  if [ -n "$PADS" ]; then
    note "Mandos detectados por el kernel: $(cut -d'|' -f2 <<<"$PADS" | paste -sd, -)"
    while IFS='|' read -r ev _; do
      [ -n "$ev" ] && [ ! -r "/dev/input/$ev" ] && warn "/dev/input/$ev sin lectura para tu usuario: vuelve a conectar el mando (reglas udev / logind)."
    done <<<"$PADS"
  else
    note "Ahora mismo no hay mando conectado: Wine lo verá en cuanto lo conectes."
  fi
fi
# gamemode: su grupo permite subir la prioridad del juego sin root (hace falta cerrar sesión para que cuente)
if pacman -Qq gamemode &>/dev/null && getent group gamemode >/dev/null && ! id -nG | tr ' ' '\n' | grep -qx gamemode; then
  sudo usermod -aG gamemode "$(id -un)" && note "Te he añadido al grupo «gamemode»: cierra sesión y entra de nuevo para que cuente."
fi

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
case $WINEPREFIX in '~/'*) WINEPREFIX="$HOME${WINEPREFIX#'~/'}" ;; esac   # INK_WINEPREFIX="~/otro" también funciona
case $WINEPREFIX in /*) ;; *) echo "El prefijo de Wine debe ser una ruta absoluta: $WINEPREFIX" >&2; exit 1 ;; esac
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
# Restaura también si el script se interrumpe (Ctrl+C, error antes del final): no deja copias en /tmp.
restore_mime() {
  [ -n "$MIME_BAK" ] || return 0
  if ! cmp -s "$MIME" "$MIME_BAK"; then
    cat "$MIME_BAK" > "$MIME"; warn "Wine había modificado ~/.config/mimeapps.list: se ha restaurado."
  fi
  rm -f "$MIME_BAK"; MIME_BAK=""
}
trap restore_mime EXIT

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
# Desactiva winemenubuilder dentro del prefijo (aunque luego lances wine sin nuestro entorno).
# Wine 11 lo lanza desde HKLM\...\RunServices en cada arranque: con el DLL override desactivado
# eso deja «Error running cmd ... winemenubuilder.exe -a -r (126)» en la terminal. Borrar esa
# entrada evita el error; el override «d» se mantiene por si Wine vuelve a crearla.
disable_menu_builder() {
  wine reg add 'HKCU\Software\Wine\DllOverrides' /v winemenubuilder.exe /t REG_SZ /d d /f >>"$LOG" 2>&1 || true
  wine reg delete 'HKLM\Software\Microsoft\Windows\CurrentVersion\RunServices' /v winemenubuilder /f >>"$LOG" 2>&1 || true
}
disable_menu_builder
wineserver -w

# Ajustes del prefijo (idempotentes, se repiten sin problema; no tocan DLL):
#   · Sin el diálogo de «winedbg» al caerse un programa: en Wayland suele quedarse colgado y bloquea el cierre del prefijo.
#   · Suavizado de fuentes ClearType RGB: el texto de los programas de Windows se ve nítido, como en el resto del escritorio.
#   INK_WINE_TWEAKS=0 los omite.
if [ "${INK_WINE_TWEAKS:-1}" != 0 ]; then
  say "Ajustes del prefijo (sin diálogo de fallos, texto nítido)"
  wine reg add 'HKCU\Software\Wine\WineDbg' /v ShowCrashDialog /t REG_DWORD /d 0 /f >>"$LOG" 2>&1 || true
  wine reg add 'HKCU\Control Panel\Desktop' /v FontSmoothing /t REG_SZ /d 2 /f >>"$LOG" 2>&1 || true
  wine reg add 'HKCU\Control Panel\Desktop' /v FontSmoothingType /t REG_DWORD /d 2 /f >>"$LOG" 2>&1 || true
  wine reg add 'HKCU\Control Panel\Desktop' /v FontSmoothingOrientation /t REG_DWORD /d 1 /f >>"$LOG" 2>&1 || true
  wine reg add 'HKCU\Control Panel\Desktop' /v FontSmoothingGamma /t REG_DWORD /d 1400 /f >>"$LOG" 2>&1 || true
  wineserver -w
fi

# ---------- 3b. Entrada (mandos): Wine DEBE usar sus DLL de dinput/xinput ----------
# joy.cpl (Panel de control → Mandos) y casi todos los juegos enumeran el mando con dinput8.dll de Wine.
# Si el prefijo arrastra *dinput8=native de un winetricks antiguo (dinput8, directx9, xinput…) y esa DLL
# nativa está rota, joy.cpl ni abre y Wine no ve ningún mando, aunque Linux/SDL sí lo detecte.
# Quitar el override NO borra la DLL: Wine vuelve a cargar la integrada, que enumera el pad por HID.
# No toca d3d*/dxgi (eso es DXVK; «ink-wine builtin» lo gestiona). INK_WINE_INPUT_FIX=0 lo desactiva y
# con INK_WINE_LEGACY=1 se conserva porque el usuario pidió esas DLL nativas a propósito.
fix_input_overrides() {
  local d changed=0
  [ "${INK_WINE_INPUT_FIX:-1}" = 0 ] && return 0
  [ "${INK_WINE_LEGACY:-0}" = 1 ] && return 0
  for d in dinput dinput8 xinput1_1 xinput1_2 xinput1_3 xinput1_4 xinput9_1_0 xact xact_x64; do
    # winetricks guarda los overrides con '*' delante (*dinput8): hay que mirar las dos formas.
    for v in "$d" "*$d"; do
      if wine reg query 'HKCU\Software\Wine\DllOverrides' /v "$v" >/dev/null 2>&1; then
        wine reg delete 'HKCU\Software\Wine\DllOverrides' /v "$v" /f >>"$LOG" 2>&1 && changed=1
      fi
    done
  done
  wineserver -w
  if [ "$changed" = 1 ]; then
    note "Overrides nativos de entrada quitados: Wine usa dinput8/xinput integrados (mando visible en joy.cpl)."
  else
    note "Sin overrides de entrada conflictivos: Wine ya usa sus DLL integradas."
  fi
}
fix_input_overrides

# Overrides nativos conflictivos que no son de entrada ni de Direct3D: winetricks los deja en el registro.
# INK_WINE_FIX=1 los quita (NO borra archivos). d3d*/dxgi se dejan a DXVK («ink-wine builtin» los quita).
if [ "${INK_WINE_FIX:-0}" = 1 ]; then
  say "Quitando overrides nativos conflictivos del registro"
  for d in gdiplus riched20 riched32 wininet openal directmusic directplay xna40; do
    wine reg delete 'HKCU\Software\Wine\DllOverrides' /v "$d" /f >>"$LOG" 2>&1 || true
    wine reg delete 'HKCU\Software\Wine\DllOverrides' /v "*$d" /f >>"$LOG" 2>&1 || true
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
# Sin catálogo no se puede instalar nada: que el resumen no diga «Wine listo» aunque todos los verbos se omitan.
[ -n "$AVAIL" ] || { warn "winetricks list-all no devolvió verbos: revisa winetricks y vuelve a lanzar el script."; FAILED+=(catalogo-winetricks); }

# tricks «verbo» o «verbo1|verbo2» (el primero que exista en TU winetricks) con reintento y límite de tiempo
tricks() {
  local cand v="" s c
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

# 4.4 DXVK (Direct3D 8/9/10/11) y vkd3d-proton (Direct3D 12) traducen Direct3D a Vulkan: es lo que hace que los juegos vayan
#     de verdad rápido en Linux. REEMPLAZAN las DLL de Direct3D del prefijo, así que solo se instalan con un controlador
#     Vulkan (ICD) presente: sin él la ventana se abriría en negro y sin mensajes. Se desactivan con INK_WINE_DXVK=0.
#     Si un juego concreto falla con ellos: INK_WINE_BUILTIN=1 ink-wine juego.exe (los ignora solo esa vez).
if [ "${INK_WINE_DXVK:-1}" = 0 ]; then
  note "dxvk/vkd3d: omitidos por INK_WINE_DXVK=0 (Wine usa su Direct3D propio). Para activarlos: ink-wine dxvk"
elif [ "$VULKAN" = 1 ]; then
  tricks dxvk
  [ "${INK_WINE_VKD3D:-1}" = 0 ] || tricks vkd3d
else
  warn "Sin controlador Vulkan (ICD): se omiten dxvk y vkd3d (Wine usará su Direct3D, bastante más lento)."
  warn "Instala el de tu GPU (vulkan-intel / vulkan-radeon / nvidia-utils) y vuelve a lanzar ./6-wine.sh"
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

# 4.7 Versión de Windows: SIEMPRE lo último. Varios verbos (vcrun, dotnet…) la dejan en win7 al terminar; así queda win10.
# Mismo trato que a los demás verbos: se puede omitir con INK_WINE_SKIP, tiene límite de tiempo y cuenta en el resumen.
if printf '%s\n' "${SKIP[@]:-}" | grep -qxF win10; then
  note "win10: omitido por INK_WINE_SKIP"
else
  printf '  · %-16s' win10
  if timeout 900 winetricks -q win10 >>"$LOG" 2>&1; then echo "ok"; DONE+=(win10); else echo "FALLÓ (ver registro)"; FAILED+=(win10); fi
  wineserver -w 2>/dev/null
fi

# Un verbo extra del usuario (o un winetricks antiguo) puede volver a poner dinput8=xinput=native:
# repetimos la reparación al final para que el prefijo quede siempre listo para mandos.
fix_input_overrides
# Los verbos pueden llamar a wineboot y recuperar la entrada de RunServices de winemenubuilder.
disable_menu_builder

# ---------- 5. Protección de tus archivos de configuración ----------
restore_mime

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
  Mando no detectado:     ink-wine pad     (repara dinput8 y abre el Panel de control → Mandos)
  Ratón que se escapa:    ink-wine grab on  ·  ink-wine desktop 1920x1080  ·  INK_GAMESCOPE=1 ink-wine juego.exe
MSG
[ ${#FAILED[@]} -eq 0 ]
