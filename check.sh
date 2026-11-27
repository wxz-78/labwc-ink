#!/usr/bin/env bash
# check.sh — valida el repositorio sin instalar nada (útil antes de hacer commit).
#   · sintaxis de todos los scripts (bash -n; shellcheck si está instalado)
#   · XML (rc.xml, menu.xml), JSONC (waybar, fastfetch), config.fish (si hay fish) y permisos de bin/
#   · que cada atajo «Super+…» de la chuleta (bin/keys) exista en rc.xml
#   · que no haya atajos duplicados y que los comandos propios existan
#   · formato de archivos (sin CRLF, con shebang, ejecutables) y scripts de bin/ sin uso
#   · que cada programa que usan las configs lo instale 1-install.sh
#   · que 6-wine.sh no vuelva a instalar por defecto DLL nativas conflictivas
#   · una instalación real de dotfiles.sh en un HOME temporal (idempotente y sin tocar tu sesión) y su --restore
#   · Wine: ajustes del prefijo, XWayland persistente y prueba de ink-wine con un wine simulado
#   · escaneo de hardware y arranque (lib/hwscan.sh) contra un /sys simulado: UEFI/BIOS, gestor en uso, microcódigo, GPU híbrida, NVIDIA, portátil
#   · gamepad-awake con un mando js simulado y un wlrctl falso (ignora eventos iniciales y deriva; un botón pulsa 1 px y vuelve; limitador de 30 s) y avisos de mando en ink-hw
#   · guardias contra regresiones de seguridad/compatibilidad (TLP, firewall+SSH, MAC en Ethernet, fwupd)
#   · 4-cleanup.sh --dry-run con un pacman simulado (solo como root, p. ej. el contenedor de Arch del CI)
# Uso:  ./check.sh      (sale con error si algo falla)
set -uo pipefail
cd "$(dirname "$0")" || exit 1
fail=0
ok()  { printf '\e[32m✔\e[0m %s\n' "$*"; }
bad() { printf '\e[31m✘\e[0m %s\n' "$*"; fail=1; }

# --- shell ---
for f in *.sh lib/*.sh bin/* .config/labwc/autostart; do
    # lib/*.sh no tienen shebang pero usan bash (arrays, [[ ]]): se validan como bash
    case $f in lib/*) syntax="bash" ;; *) if head -n1 "$f" | grep -q 'bash'; then syntax="bash"; else syntax="sh"; fi ;; esac
    out=$($syntax -n "$f" 2>&1) && ok "sintaxis $f" || bad "$f: $out"
done
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -S warning -x *.sh lib/*.sh bin/* .config/labwc/autostart >/dev/null 2>&1 && ok "shellcheck" || bad "shellcheck reporta avisos (ejecútalo a mano)"
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

# --- el indicador de «no molestar» de la barra y el script dnd deben usar la misma señal ---
# 8 = grabación (rec), 9 = actualizaciones (ink-update), 10 = no molestar (dnd)
if grep -q '"custom/dnd"' .config/waybar/config.jsonc && grep -q '"signal": 10' .config/waybar/config.jsonc \
   && grep -q 'RTMIN+10' bin/dnd && grep -q '#custom-dnd.on' .config/waybar/style.css; then
    ok "waybar: indicador de «no molestar» conectado con dnd"
else
    bad "waybar: el módulo custom/dnd, su señal (10) o su estilo no coinciden con bin/dnd"
fi

# --- la chuleta (bin/keys) no debe enseñar atajos que ya no existen en rc.xml ---
# Se comprueban los atajos simples «Super+X» (letras, números y F1…F12).
rc=.config/labwc/rc.xml
while read -r k; do
    key=${k#Super+}
    grep -qiE "key=\"[A-Za-z-]*W-${key}\"" "$rc" || bad "bin/keys menciona Super+$key y no está en rc.xml"
done < <(grep -oE 'Super\+[A-Za-z0-9]{1,2}( |$)' bin/keys | tr -d ' ' | sort -u)
# Y al revés: un atajo simple «W-x» (letra o F1…F12) de rc.xml que la chuleta no menciona es un atajo
# que el usuario nunca descubrirá. «Super+H/J/K/L» cuenta como mención de h, j, k y l.
for k in $(grep -oE '<keybind key="W-([A-Za-z]|F[0-9]{1,2})"' "$rc" | sed 's/.*W-//;s/"//'); do
    grep -qiE "Super\+([A-Za-z]+\+)*[A-Za-z/]*${k}([ /]|\$)" bin/keys || bad "rc.xml define W-${k} y bin/keys no lo menciona"
done
# Lo mismo con los atajos Super+Shift+… (la comprobación anterior solo mira los simples).
# En la chuleta el Shift puede ir escrito «Super+B … (Shift: …)», así que se admiten las dos formas.
while read -r k; do
    case $k in
        Left)  pat='Super\+Shift\+.*←' ;;
        Right) pat='Super\+Shift\+.*→' ;;
        *)     pat="Super\+Shift\+${k}([ /]|\$)|Super\+${k}.*Shift" ;;
    esac
    grep -qiE "$pat" bin/keys || bad "rc.xml define W-S-${k} y bin/keys no lo menciona"
done < <(grep -oE '<keybind key="W-S-[A-Za-z]+"' "$rc" | sed 's/.*W-S-//;s/"//')
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
    [fwupdmgr]=fwupd [wlrctl]=wlrctl
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

# --- Wine: ajustes de estabilidad/estética que no deben perderse sin pensarlo ---
wt_bad=0
grep -q 'ShowCrashDialog' 6-wine.sh || { bad "6-wine.sh: falta desactivar el diálogo de fallos de winedbg (se cuelga en Wayland)"; wt_bad=1; }
grep -q 'FontSmoothingType' 6-wine.sh || { bad "6-wine.sh: falta el suavizado de fuentes ClearType"; wt_bad=1; }
grep -q 'xwaylandPersistence' .config/labwc/rc.xml || { bad "rc.xml: falta xwaylandPersistence (XWayland persistente para Wine)"; wt_bad=1; }
grep -q 'DISPLAY' .config/labwc/autostart || { bad "autostart: DISPLAY debe pasarse a D-Bus/systemd (programas X11 y Wine lanzados por portales)"; wt_bad=1; }
grep -q 'INK_WINE_DXVK:-1' 6-wine.sh && ! grep -q 'INK_WINE_DXVK:-0' 6-wine.sh || { bad "6-wine.sh: DXVK debe instalarse por defecto (INK_WINE_DXVK:-1): sin él los juegos van lentos"; wt_bad=1; }
grep -q 'game-devices-udev' 6-wine.sh || { bad "6-wine.sh: faltan las reglas udev de mandos (game-devices-udev)"; wt_bad=1; }
grep -q 'INK_WINE_INPUT_FIX:-1' 6-wine.sh && grep -q 'fix_input_overrides' 6-wine.sh \
  || { bad "6-wine.sh: falta reparar los overrides dinput/xinput que ocultan el mando a Wine"; wt_bad=1; }
grep -q 'gamescope' 6-wine.sh && grep -q 'gamemode' 6-wine.sh || { bad "6-wine.sh: faltan gamemode/gamescope opcionales"; wt_bad=1; }
grep -qE '\^gamemode\$.*gamescope' lib/common.sh || { bad "lib/common.sh: keep_pkgs debe proteger gamemode/gamescope de la limpieza"; wt_bad=1; }
for sub in new tweaks dpi dark light grab desktop pad; do
    grep -qE "^  (.*\|)?${sub}(\|.*)?\)" bin/ink-wine || { bad "bin/ink-wine: falta el subcomando «$sub»"; wt_bad=1; }
done
[ "$wt_bad" = 0 ] && ok "Wine: ajustes de prefijo, XWayland persistente y subcomandos de ink-wine"

# --- ink-wine con un wine y un gamescope simulados: valida argumentos y lo que se escribe en el registro ---
wk=$(mktemp -d); mkdir -p "$wk/bin" "$wk/home/pfx"; : > "$wk/home/pfx/system.reg"
printf '#!/bin/sh\nprintf "OVR=${WINEDLLOVERRIDES:-}|%%s\\n" "$*" >> "$WINE_LOG"\n' > "$wk/bin/wine"
printf '#!/bin/sh\nprintf "gamescope %%s\\n" "$*" >> "$WINE_LOG"\n' > "$wk/bin/gamescope"
printf '#!/bin/sh\nexit 0\n' > "$wk/bin/wineserver"
chmod +x "$wk/bin/wine" "$wk/bin/wineserver" "$wk/bin/gamescope"
inkwine() { PATH="$wk/bin:$PATH" HOME="$wk/home" WINE_LOG="$wk/log" INK_WINEPREFIX="$wk/home/pfx" bin/ink-wine "$@"; }
if inkwine dark >/dev/null 2>&1 && grep -q 'Colors.*Window.*21 21 21' "$wk/log" \
   && inkwine light >/dev/null 2>&1 && grep -q 'Colors.*Window.*255 255 255' "$wk/log" \
   && inkwine tweaks >/dev/null 2>&1 && grep -q 'ShowCrashDialog' "$wk/log" \
   && inkwine dpi 144 >/dev/null 2>&1 && grep -q 'LogPixels.*144' "$wk/log" \
   && ! inkwine dpi abc >/dev/null 2>&1 && ! inkwine dpi 9999 >/dev/null 2>&1 \
   && inkwine grab on >/dev/null 2>&1 && grep -q 'GrabFullscreen.*Y' "$wk/log" \
   && ! inkwine grab quizas >/dev/null 2>&1 \
   && inkwine desktop 1920x1080 >/dev/null 2>&1 && grep -q 'Desktops.*Default.*1920x1080' "$wk/log" \
   && ! inkwine desktop 12x >/dev/null 2>&1 \
   && ! inkwine new ../x >/dev/null 2>&1 && ! inkwine new .oculto >/dev/null 2>&1; then
    ok "ink-wine: dark/light/dpi/grab/desktop escriben el registro y rechazan entradas inválidas"
else bad "ink-wine: la prueba con wine simulado falló"; fi
: > "$wk/juego.exe"; : > "$wk/log"
if INK_GAMESCOPE=1 inkwine "$wk/juego.exe" >/dev/null 2>&1 && grep -q '^gamescope -f -- ' "$wk/log" \
   && { : > "$wk/log"; INK_WINE_DESKTOP=1280x720 inkwine "$wk/juego.exe" >/dev/null 2>&1; grep -q 'explorer /desktop=ink,1280x720 juego.exe' "$wk/log"; }; then
    ok "ink-wine: gamescope y escritorio virtual envuelven el comando"
else bad "ink-wine: la prueba de gamescope/escritorio virtual falló"; fi
# Un dinput8 nativo roto en el registro es la causa más común de «Wine no detecta el mando».
: > "$wk/log"
if inkwine "$wk/juego.exe" >/dev/null 2>&1 && grep -q 'OVR=[^|]*dinput8=b' "$wk/log" \
   && { : > "$wk/log"; WINEDLLOVERRIDES='dinput8=n,xinput1_3=n,winemenubuilder.exe=n' inkwine "$wk/juego.exe" >/dev/null 2>&1 \
        && grep -q 'OVR=[^|]*dinput8=b' "$wk/log" && ! grep -qE 'dinput8=n|xinput1_3=n' "$wk/log"; }; then
    ok "ink-wine: fuerza dinput8 integrado y descarta overrides de mandos heredados"
else bad "ink-wine: no se fuerza dinput8=b o se conserva un override de mando (xinput1_3)"; fi
: > "$wk/log"
if inkwine pad check >/dev/null 2>&1 && grep -q 'reg delete .* dinput8 /f' "$wk/log" \
   && { : > "$wk/log"; INK_WINE_NATIVE_INPUT=1 inkwine pad check >/dev/null 2>&1 \
        && ! grep -q 'reg delete ' "$wk/log"; }; then
    ok "ink-wine pad: repara los overrides de entrada y respeta INK_WINE_NATIVE_INPUT=1"
else bad "ink-wine pad: la reparación de overrides de entrada falló"; fi
rm -rf "$wk"

# --- escaneo de hardware y arranque (lib/hwscan.sh) contra un /sys simulado: sin tocar tu equipo ---
# Cada escenario construye un «sistema» en un directorio temporal y comprueba lo que el escaneo concluye.
hw_fixture() {   # hw_fixture DIR ESCENARIO
    local fx=$1 sc=$2 S P R d
    S=$fx/sys; P=$fx/proc; R=$fx/root
    mkdir -p "$S/class/dmi/id" "$P" "$R/etc" "$R/boot" "$R/usr/lib/modules/6.12.1-arch1-1"
    printf 'linux\n' > "$R/usr/lib/modules/6.12.1-arch1-1/pkgbase"
    pci() { d=$S/bus/pci/devices/$1; mkdir -p "$d"; echo "$2" > "$d/class"; echo "$3" > "$d/vendor"; echo "$4" > "$d/device"
            if [ -n "${5:-}" ]; then mkdir -p "$fx/drv/$5"; ln -s "$fx/drv/$5" "$d/driver"; fi
            if [ -n "${6:-}" ]; then echo "$6" > "$d/boot_vga"; fi; return 0; }
    case $sc in
      laptop-limine)   # portátil Intel + NVIDIA Turing, UEFI, Limine en la ruta genérica, hook microcode
        mkdir -p "$S/firmware/efi/efivars" "$R/efi/EFI/BOOT"
        printf '\x07\x00\x00\x00\x01' > "$S/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"
        printf '\x07\x00\x00\x00\x00' > "$S/firmware/efi/efivars/SetupMode-8be4df61-93ca-11d2-aa0d-00e098032b8c"
        printf 'xx Limine yy' > "$R/efi/EFI/BOOT/BOOTX64.EFI"; : > "$R/efi/limine.conf"
        printf 'HOOKS=(base udev autodetect microcode modconf kms block filesystems fsck)\n' > "$R/etc/mkinitcpio.conf"
        printf 'vendor_id\t: GenuineIntel\nmodel name\t: Intel i7\nprocessor\t: 0\n' > "$P/cpuinfo"
        pci 0000:00:02.0 0x030000 0x8086 0x9a49 i915 1; pci 0000:01:00.0 0x030200 0x10de 0x2560 nvidia 0
        pci 0000:00:1f.3 0x040100 0x8086 0xa0c8 snd_hda_intel; pci 0000:00:14.3 0x028000 0x8086 0xa0f0
        mkdir -p "$S/class/power_supply/BAT0"; echo Battery > "$S/class/power_supply/BAT0/type"
        : > "$S/class/power_supply/BAT0/charge_control_end_threshold"; echo 10 > "$S/class/dmi/id/chassis_type"
        printf 'BootCurrent: 0001\nBoot0001* Arch\tHD(1,GPT,x)/File(\\EFI\\BOOT\\BOOTX64.EFI)\nBoot0002* Windows Boot Manager\tHD(1,GPT,x)/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)\n' > "$fx/efi.out" ;;
      desktop-grub)    # sobremesa AMD, UEFI, GRUB con nombre «Arch», microcódigo SIN enlazar
        mkdir -p "$S/firmware/efi" "$R/efi/EFI/arch" "$R/boot/grub"
        : > "$R/efi/EFI/arch/grubx64.efi"; echo 'menuentry "Arch" { initrd /initramfs-linux.img }' > "$R/boot/grub/grub.cfg"
        printf 'HOOKS=(base udev autodetect modconf block filesystems fsck)\n' > "$R/etc/mkinitcpio.conf"
        printf 'vendor_id\t: AuthenticAMD\nmodel name\t: AMD Ryzen\nprocessor\t: 0\n' > "$P/cpuinfo"
        pci 0000:06:00.0 0x030000 0x1002 0x73bf amdgpu 1; echo 3 > "$S/class/dmi/id/chassis_type"
        printf 'BootCurrent: 0000\nBoot0000* Arch\tHD(1,GPT,x)/File(\\EFI\\arch\\grubx64.efi)\n' > "$fx/efi.out" ;;
      bios-pascal)     # BIOS clásica, NVIDIA Pascal sin driver, sobremesa Intel
        printf 'vendor_id\t: GenuineIntel\nmodel name\t: Intel i5\nprocessor\t: 0\n' > "$P/cpuinfo"
        pci 0000:01:00.0 0x030000 0x10de 0x1c03 "" 1; echo 3 > "$S/class/dmi/id/chassis_type" ;;
    esac
}
hw_run() {   # hw_run DIR PAQUETES FUNCIÓN…  → ejecuta una función de la librería sobre el sistema simulado
    local fx=$1 pk=$2; shift 2
    INK_HW_NOCMD=1 INK_HW_PKGS="$pk" INK_SYSFS=$fx/sys INK_PROCFS=$fx/proc INK_ROOT=$fx/root \
    INK_EFIBOOTMGR_OUT=$fx/efi.out INK_KLOG=$fx/klog bash -c 'set -euo pipefail; source lib/hwscan.sh; "$@"' _ "$@" 2>&1
}
hw_bad=0
hwt() {   # hwt «descripción» «esperado» «obtenido»
    [ "$2" = "$3" ] || { bad "hwscan: $1 (esperaba «$2», salió «$3»)"; hw_bad=1; }
}
hx=$(mktemp -d); : > "$hx/klog"
hw_fixture "$hx" laptop-limine
env_a=$(hw_run "$hx" "intel-ucode mkinitcpio vulkan-intel" hw_env)
hwt "laptop: UEFI"                       FIRMWARE=uefi   "$(grep ^FIRMWARE= <<<"$env_a")"
hwt "laptop: Secure Boot activo"         SECUREBOOT=on   "$(grep ^SECUREBOOT= <<<"$env_a")"
hwt "laptop: Limine por contenido del binario genérico" BOOTLOADER=limine "$(grep ^BOOTLOADER= <<<"$env_a")"
hwt "laptop: gráfica híbrida"            GPU_HYBRID=1    "$(grep ^GPU_HYBRID= <<<"$env_a")"
hwt "laptop: GPU intel+nvidia"           "GPU_KINDS=intel nvidia" "$(grep ^GPU_KINDS= <<<"$env_a")"
hwt "laptop: detectado como portátil"    LAPTOP=1        "$(grep ^LAPTOP= <<<"$env_a")"
hwt "laptop: microcódigo por el hook"    UCODE_STATE=configurado "$(grep ^UCODE_STATE= <<<"$env_a")"
hwt "laptop: initramfs"                  INITRAMFS=mkinitcpio "$(grep ^INITRAMFS= <<<"$env_a")"
hwt "laptop: batería con límite de carga" 1 "$(hw_run "$hx" "" hw_charge_limit)"
if hw_run "$hx" "" hw_wants_sof >/dev/null; then hwt "audio Intel sin tarjeta de sonido: necesita sof-firmware" si si; else hwt "audio Intel sin tarjeta de sonido: necesita sof-firmware" si no; fi
# Intel con HDA clásico y tarjeta ya registrada (p. ej. Skylake): sof-firmware sobra
mkdir -p "$hx/sys/class/sound/card0"
if hw_run "$hx" "" hw_wants_sof >/dev/null; then hwt "audio Intel HDA clásico con tarjeta: NO necesita sof-firmware" no si; else hwt "audio Intel HDA clásico con tarjeta: NO necesita sof-firmware" no no; fi
# …pero si el controlador enlazado ya es SOF, sí
rm -f "$hx/sys/bus/pci/devices/0000:00:1f.3/driver"; mkdir -p "$hx/drv/snd_sof_pci_intel_tgl"; ln -s "$hx/drv/snd_sof_pci_intel_tgl" "$hx/sys/bus/pci/devices/0000:00:1f.3/driver"
if hw_run "$hx" "" hw_wants_sof >/dev/null; then hwt "audio con controlador SOF: necesita sof-firmware" si si; else hwt "audio con controlador SOF: necesita sof-firmware" si no; fi
# ajustes de juego: vm.max_map_count bajo y límite de archivos bajo → avisos; valores buenos → ✔
mkdir -p "$hx/proc/sys/vm" "$hx/proc/self" "$hx/root/usr/share/vulkan/icd.d"
echo 65530 > "$hx/proc/sys/vm/max_map_count"; : > "$hx/root/usr/share/vulkan/icd.d/intel_icd.x86_64.json"
printf 'Limit Soft Limit Hard Limit Units\nMax open files 1024 4096 files\n' > "$hx/proc/self/limits"
g=$(hw_run "$hx" "" hw_report_gaming)
grep -q '! .*vm.max_map_count = 65530' <<<"$g" || { bad "hwscan: vm.max_map_count bajo debe avisar"; hw_bad=1; }
grep -q '! .*xorg-xwayland' <<<"$g"            || { bad "hwscan: sin xorg-xwayland debe avisar"; hw_bad=1; }
grep -q '! .*524288' <<<"$g"                   || { bad "hwscan: límite de archivos bajo debe avisar"; hw_bad=1; }
echo 1048576 > "$hx/proc/sys/vm/max_map_count"; printf 'Max open files 524288 524288 files\n' > "$hx/proc/self/limits"
g=$(hw_run "$hx" "xorg-xwayland" hw_report_gaming)
grep -q '!' <<<"$g" && { bad "hwscan: con los ajustes de juego correctos no debe haber avisos"; hw_bad=1; }
g=$(HW_BRIEF=1 hw_run "$hx" "xorg-xwayland" hw_report_gaming)
grep -q 'zram\|ntsync' <<<"$g" && { bad "hwscan: HW_BRIEF=1 no debe imprimir las líneas informativas"; hw_bad=1; }
echo "[ 0.1] microcode: updated early: 0x1 -> 0x2" > "$hx/klog"
hwt "laptop: microcódigo confirmado por el log" "activo|log del kernel" "$(hw_run "$hx" "intel-ucode" hw_ucode_state)"
echo "[ 1.0] iwlwifi: Direct firmware load for iwlwifi-x.ucode failed with error -2" > "$hx/klog"
hwt "laptop: firmware faltante en el log" iwlwifi-x.ucode "$(hw_run "$hx" "" hw_missing_firmware)"
hwt "NVIDIA 0x2560 → Turing+"  turing+ "$(hw_run "$hx" "" hw_nvidia_family 0x2560)"
hwt "NVIDIA 0x1c03 → Pascal"   pascal  "$(hw_run "$hx" "" hw_nvidia_family 0x1c03)"
hwt "NVIDIA 0x1380 → Maxwell"  maxwell "$(hw_run "$hx" "" hw_nvidia_family 0x1380)"
hwt "NVIDIA 0x0fc1 → antigua"  antigua "$(hw_run "$hx" "" hw_nvidia_family 0x0fc1)"
hwt "NVIDIA: módulo del kernel de CachyOS"  linux-cachyos-nvidia-open "$(hw_run "$hx" "linux-cachyos linux-cachyos-nvidia-open nvidia-utils" hw_nvidia_installed)"
hwt "NVIDIA: sin driver instalado"          ""                          "$(hw_run "$hx" "linux-cachyos nvidia-utils" hw_nvidia_installed)"
hwt "NVIDIA: nvidia-open sigue ganando"     nvidia-open                 "$(hw_run "$hx" "linux nvidia-open linux-cachyos-nvidia-open" hw_nvidia_installed)"
grep -q '580xx' <<<"$(hw_run "$hx" "" hw_nvidia_hint pascal)" || { bad "hwscan: Pascal debe remitir a nvidia-580xx (el driver actual ya no la soporta)"; hw_bad=1; }
# seguridad del hardware: vulnerabilidades de CPU, mitigations=off y permisos de la ESP con systemd-boot
vd="$hx/sys/devices/system/cpu/vulnerabilities"; mkdir -p "$vd"
echo "Mitigation: PTI" > "$vd/meltdown"; echo "Mitigation: Clear CPU buffers; SMT vulnerable" > "$vd/mds"
echo "Not affected" > "$vd/tsx_async_abort"; echo "Vulnerable: No microcode" > "$vd/srbds"
sc=$(hw_run "$hx" "intel-ucode" hw_report_security)
grep -q '! CPU srbds: Vulnerable' <<<"$sc" || { bad "hwscan: una vulnerabilidad de CPU sin mitigar debe avisar"; hw_bad=1; }
grep -q 'microc' <<<"$sc"           || { bad "hwscan: si falta microcódigo, el aviso debe remitir al microcódigo"; hw_bad=1; }
echo "Mitigation: Microcode" > "$vd/srbds"
sc=$(hw_run "$hx" "intel-ucode" hw_report_security)
grep -q '!' <<<"$sc" && { bad "hwscan: con todo mitigado no debe haber avisos de CPU"; hw_bad=1; }
grep -q '4 vulnerabilidades' <<<"$sc" || { bad "hwscan: debe contar las vulnerabilidades revisadas"; hw_bad=1; }
echo "root=/dev/sda2 rw mitigations=off quiet" > "$hx/proc/cmdline"
grep -q '! mitigations=off' <<<"$(hw_run "$hx" "" hw_report_security)" || { bad "hwscan: mitigations=off debe avisar"; hw_bad=1; }
echo "root=/dev/sda2 rw quiet" > "$hx/proc/cmdline"
grep -q '! La ESP' <<<"$(INK_BOOTLOADER=systemd-boot INK_ESP_OPTS='rw,fmask=0022,dmask=0022' hw_run "$hx" "" hw_report_security)" || { bad "hwscan: ESP legible por todos con systemd-boot debe avisar"; hw_bad=1; }
grep -q '! La ESP' <<<"$(INK_BOOTLOADER=systemd-boot INK_ESP_OPTS='rw,fmask=0137,dmask=0027' hw_run "$hx" "" hw_report_security)" && { bad "hwscan: ESP con fmask=0137 no debe avisar"; hw_bad=1; }
# consejos de btrfs (solo informativos)
grep -q 'compress=zstd' <<<"$(INK_ROOT_FS=btrfs INK_ROOT_OPTS='rw,relatime' hw_run "$hx" "" hw_report_hardware)" || { bad "hwscan: btrfs sin compresión debe sugerir compress=zstd"; hw_bad=1; }
grep -q 'btrfs sin' <<<"$(INK_ROOT_FS=btrfs INK_ROOT_OPTS='rw,noatime,compress=zstd:1' hw_run "$hx" "" hw_report_hardware)" && { bad "hwscan: btrfs ya optimizado no debe sugerir nada"; hw_bad=1; }
rm -rf "$hx"

hx=$(mktemp -d); : > "$hx/klog"
hw_fixture "$hx" desktop-grub
env_b=$(hw_run "$hx" "amd-ucode grub mkinitcpio" hw_env)
hwt "sobremesa: GRUB por la ruta de la entrada (aunque se llame «Arch»)" BOOTLOADER=grub "$(grep ^BOOTLOADER= <<<"$env_b")"
hwt "sobremesa: no es portátil"          LAPTOP=0 "$(grep ^LAPTOP= <<<"$env_b")"
hwt "sobremesa: CPU AMD"                 CPU_VENDOR=amd "$(grep ^CPU_VENDOR= <<<"$env_b")"
hwt "sobremesa: microcódigo sin enlazar" UCODE_STATE=falta "$(grep ^UCODE_STATE= <<<"$env_b")"
echo 'menuentry "Arch" { initrd /amd-ucode.img /initramfs-linux.img }' > "$hx/root/boot/grub/grub.cfg"
hwt "sobremesa: microcódigo en grub.cfg" configurado "$(hw_run "$hx" "amd-ucode grub" hw_ucode_state | cut -d'|' -f1)"
hwt "sobremesa: sin el paquete ucode"    "sin-paquete|amd-ucode" "$(hw_run "$hx" "grub" hw_ucode_state)"
rep=$(hw_run "$hx" "grub amd-ucode mkinitcpio" hw_report_boot)
grep -q 'Gestor de arranque en uso: grub' <<<"$rep" || { bad "hwscan: el informe de arranque no muestra el gestor"; hw_bad=1; }
rm -rf "$hx"

hx=$(mktemp -d); : > "$hx/klog"
hw_fixture "$hx" bios-pascal
env_c=$(hw_run "$hx" "intel-ucode" hw_env)
hwt "BIOS: modo legacy"                  FIRMWARE=bios "$(grep ^FIRMWARE= <<<"$env_c")"
hwt "BIOS: sin ESP"                      ESP= "$(grep ^ESP= <<<"$env_c")"
hwt "NVIDIA sin driver detectada"        nvidia "$(hw_run "$hx" "" hw_gpu_kinds)"
grep -q 'sin driver' <<<"$(hw_run "$hx" "" hw_report_hardware)" || { bad "hwscan: una NVIDIA sin driver debe avisar"; hw_bad=1; }
rm -rf "$hx"
for fn in detect_bootloader hw_ucode_state hw_gpus hw_report_boot hw_report_hardware; do
    grep -q "^$fn()" lib/hwscan.sh || { bad "lib/hwscan.sh: falta $fn"; hw_bad=1; }
done
grep -q 'hwscan.sh' 1-install.sh && grep -q 'hw_summary' 1-install.sh || { bad "1-install.sh debe instalar y usar lib/hwscan.sh"; hw_bad=1; }
[ "$hw_bad" = 0 ] && ok "hwscan: UEFI/BIOS, gestor en uso, microcódigo, GPU híbrida/NVIDIA y portátil contra un /sys simulado"

# --- optimización y seguridad añadidas: reglas udev válidas, sysctl coherentes, archivos presentes ---
op_bad=0
io_rules=$(mktemp)
awk '/60-ink-ioschedulers.rules/ {f=1; next} f && /^CONF$/ {exit} f' 2-optimize.sh > "$io_rules"
[ -s "$io_rules" ] || { bad "2-optimize.sh: falta la regla udev de planificadores de E/S"; op_bad=1; }
grep -qE 'ATTR\{queue/scheduler\}="(none|mq-deadline|bfq)"' "$io_rules" || { bad "2-optimize.sh: la regla de E/S no fija ningún planificador"; op_bad=1; }
grep -q 'DEVTYPE}=="disk"' "$io_rules" || { bad "2-optimize.sh: la regla de E/S debe limitarse a discos enteros (DEVTYPE==disk), no a particiones"; op_bad=1; }
if udevadm verify --help >/dev/null 2>&1; then   # si esta versión de udevadm no conoce la opción, la prueba se omite
    uv=$(udevadm verify --no-style "$io_rules" 2>&1); rc=$?
    if [ "$rc" != 0 ] && ! grep -qiE 'unrecogni[sz]ed|invalid option|unknown option' <<<"$uv"; then
        bad "2-optimize.sh: «udevadm verify» rechaza la regla de planificadores de E/S"; op_bad=1; fi
fi
rm -f "$io_rules"
# dirty_bytes y dirty_background_bytes van JUNTOS y con el de fondo menor (si no, el kernel ajusta uno al otro sin avisar)
db=$(sed -n 's/^vm.dirty_bytes *= *\([0-9]*\).*/\1/p' 2-optimize.sh | head -n1)
dbg=$(sed -n 's/^vm.dirty_background_bytes *= *\([0-9]*\).*/\1/p' 2-optimize.sh | head -n1)
if [ -z "$db" ] || [ -z "$dbg" ] || [ "$dbg" -ge "$db" ]; then bad "2-optimize.sh: vm.dirty_bytes y vm.dirty_background_bytes deben estar los dos y el de fondo ser menor"; op_bad=1; fi
for k in $(sed -n 's/^\(vm\.[a-z_]*\) *=.*/\1/p' 2-optimize.sh | sort -u); do
    [ -d /proc/sys/vm ] && [ ! -e "/proc/sys/${k//.//}" ] && { bad "2-optimize.sh: la clave sysctl $k no existe en este kernel"; op_bad=1; }
done
grep -q 'user.conf.d/10-ink.conf' 2-optimize.sh || { bad "2-optimize.sh: falta el tiempo de parada del gestor de usuario"; op_bad=1; }
grep -q '^MESA_SHADER_CACHE_MAX_SIZE=' .config/labwc/environment || { bad "environment: falta MESA_SHADER_CACHE_MAX_SIZE"; op_bad=1; }
for m in cramfs freevxfs jffs2 ax25 netrom rose; do grep -q "^install $m /usr/bin/false" 3-privacy.sh || { bad "3-privacy.sh: falta bloquear $m"; op_bad=1; }; done
# UDF e HFS+ SÍ se usan en discos externos y DVD: no deben bloquearse
grep -qE '^install (udf|hfsplus|hfs|squashfs|vfat|exfat|ntfs3?) ' 3-privacy.sh && { bad "3-privacy.sh: no bloquees sistemas de archivos de discos externos (udf, hfs, squashfs, vfat, exfat, ntfs)"; op_bad=1; }
grep -q 'hw_report_security' bin/ink-hw && grep -q 'hw_report_security' bin/ink-doctor || { bad "ink-hw e ink-doctor deben llamar a hw_report_security"; op_bad=1; }
[ "$op_bad" = 0 ] && ok "optimización y seguridad: regla udev, sysctl de escritura a disco, módulos bloqueados y avisos de CPU/arranque"

# --- mando: avisos de ink-hw y gamepad-awake con un mando js simulado (tarda ~9 s: el vigilante mira los mandos cada 5 s) ---
pad_bad=0
hx=$(mktemp -d); mkdir -p "$hx/sys/class/input/event5/device/capabilities" "$hx/sys/class/input/event2/device/capabilities" "$hx/root/dev/input"
echo "Wireless Controller" > "$hx/sys/class/input/event5/device/name"; echo "1000000000000 0 0 0 0" > "$hx/sys/class/input/event5/device/capabilities/key"   # BTN_SOUTH (0x130)
echo "ffffffffe 0" > "$hx/sys/class/input/event2/device/capabilities/key"                                                                                  # un teclado
[ "$(INK_HW_NOCMD=1 INK_SYSFS=$hx/sys bash -c 'source lib/hwscan.sh; hw_gamepads')" = "event5|Wireless Controller" ] || { bad "hwscan: hw_gamepads debe detectar el mando y no el teclado"; pad_bad=1; }
padrep() { INK_HW_NOCMD=1 INK_SYSFS=$hx/sys INK_ROOT=$hx/root INK_PROCFS=$hx/proc bash -c 'source lib/hwscan.sh; hw_report_gaming' 2>&1; }
grep -q '! Hay un mando conectado pero no aparece como /dev/input/js' <<<"$(padrep)" || { bad "hwscan: un mando sin /dev/input/js* debe avisar (joydev)"; pad_bad=1; }
: > "$hx/root/dev/input/js0"
grep -q '✔ Mando detectado: Wireless Controller' <<<"$(padrep)" || { bad "hwscan: con js0 legible debe confirmar el mando"; pad_bad=1; }
if [ "$(id -u)" != 0 ]; then   # como root todo es legible: la prueba de permisos solo vale con un usuario normal
    chmod 000 "$hx/root/dev/input/js0"
    grep -q '! .*js0 sin permiso de lectura' <<<"$(padrep)" || { bad "hwscan: un js0 ilegible debe avisar (reglas udev de mandos)"; pad_bad=1; }
fi
rm -rf "$hx"
if command -v python3 >/dev/null 2>&1 && command -v mkfifo >/dev/null 2>&1 && command -v od >/dev/null 2>&1 \
   && command -v stdbuf >/dev/null 2>&1 && command -v flock >/dev/null 2>&1 && command -v setsid >/dev/null 2>&1; then
    gt=$(mktemp -d); mkdir -p "$gt/bin" "$gt/pads" "$gt/run"
    printf '#!/bin/sh\necho "$*" >> "%s/wlrctl.log"\n' "$gt" > "$gt/bin/wlrctl"; chmod +x "$gt/bin/wlrctl"
    mkfifo "$gt/pads/js0" "$gt/cmd"
    ( export PATH="$gt/bin:$PATH" WAYLAND_DISPLAY=wl-test XDG_RUNTIME_DIR="$gt/run" INK_PADS="$gt/pads/js*"
      exec setsid bash "$PWD/bin/gamepad-awake" >"$gt/out" 2>&1 ) & ga=$!
    # «mando» simulado: mantiene abierto el dispositivo (como el kernel) y emite struct js_event según lo que se le pida
    python3 - "$gt" <<'PYEOF' 2>/dev/null &
import os, struct, sys
T = sys.argv[1]
fd = os.open(f"{T}/pads/js0", os.O_WRONLY)       # bloquea hasta que gamepad-awake abra el dispositivo
while True:
    with open(f"{T}/cmd") as f:
        for line in f:
            t, n, v = map(int, line.split())
            os.write(fd, struct.pack("<IhBB", 0, v, t, n))
PYEOF
    pw=$!
    sleep 6
    padev() { echo "$1 $2 $3" > "$gt/cmd"; sleep 0.6; }
    pulses() { grep -c '^pointer move 1 0' "$gt/wlrctl.log" 2>/dev/null; true; }
    padev 129 0 1; padev 130 0 30000    # eventos iniciales (bit 0x80): el estado al conectar NO es actividad
    padev 2 0 5000; padev 2 1 -9000     # deriva del stick (< 12000 de 32767)
    [ -z "$(pulses)" ] || [ "$(pulses)" = 0 ] || { bad "gamepad-awake: los eventos iniciales o la deriva del stick no deben mover el puntero"; pad_bad=1; }
    padev 1 0 1                         # un botón
    [ "$(pulses)" = 1 ] || { bad "gamepad-awake: un botón del mando debe reiniciar el reposo con un pulso de wlrctl"; pad_bad=1; }
    grep -q '^pointer move -1 0' "$gt/wlrctl.log" 2>/dev/null || { bad "gamepad-awake: tras el pulso de +1 px debe volver -1 px (el puntero no debe quedar desplazado)"; pad_bad=1; }
    padev 1 1 1; padev 2 0 30000        # más actividad enseguida: el limitador (30 s) no repite el pulso
    [ "$(pulses)" = 1 ] || { bad "gamepad-awake: el limitador de 30 s no debe permitir un segundo pulso inmediato"; pad_bad=1; }
    kill -- "-$ga" 2>/dev/null; kill "$pw" 2>/dev/null; wait 2>/dev/null
    rm -rf "$gt"
else
    echo "· faltan python3/mkfifo/od/stdbuf/flock/setsid: se omite la prueba funcional de gamepad-awake"
fi
[ "$pad_bad" = 0 ] && ok "mando: gamepad-awake (js simulado + wlrctl falso) y avisos de ink-hw (joydev / permisos)"

# --- bin/ con programas simulados: ink-theme (colisiones), monitors (rotación), ink-menu (comandos), ink-fuzzel y nightlight ---
bt_bad=0
bt=$(mktemp -d); mkdir -p "$bt/bin" "$bt/home"; cp -r .config .local "$bt/home/"
for c in notify-send pkill; do printf '#!/bin/sh\nexit %s\n' "$([ $c = pkill ] && echo 1 || echo 0)" > "$bt/bin/$c"; done
cat > "$bt/bin/wlr-randr" <<'MOCK'
#!/bin/sh
[ $# -gt 0 ] && { echo "$*" >> "$BT/randr.args"; exit 0; }
printf 'DP-1 "A"\n  Enabled: yes\n  Modes:\n    1920x1080 px, 60.000000 Hz (preferred, current)\n  Position: 0,0\n  Transform: 90\n  Scale: 1.500000\n'
printf 'HDMI-A-1 "B"\n  Enabled: yes\n  Modes:\n    1920x1080 px, 60.000000 Hz (preferred, current)\n  Position: 2560,0\n  Transform: normal\n  Scale: 1.000000\n'
MOCK
cat > "$bt/bin/fuzzel" <<'MOCK'
#!/bin/sh
echo "$*" >> "$BT/fuzzel.args"; cat > "$BT/fuzzel.in"
read -r first rest < "$BT/seq"; echo "$rest" > "$BT/seq"
[ -n "$first" ] && echo "$first" || exit 1
MOCK
for c in audio-switch shot; do printf '#!/bin/sh\necho "%s $*" >> "$BT/calls"\n' "$c" > "$bt/bin/$c"; done
chmod +x "$bt"/bin/*
btx() { PATH="$bt/bin:$PWD/bin:$PATH" BT="$bt" HOME="$bt/home" XDG_CONFIG_HOME="$bt/home/.config" XDG_DATA_HOME="$bt/home/.local/share" \
        XDG_STATE_HOME="$bt/home/.state" INK_NO_RELOAD=1 "$@"; }
# ink-theme: un color que el tema ya usa (#ffffff = texto) no debe fundirse con el acento; ida y vuelta deja todo igual
btx bin/ink-theme '#ffffff' >/dev/null 2>&1; btx bin/ink-theme jade >/dev/null 2>&1; btx bin/ink-theme tinta >/dev/null 2>&1
diff -r .config "$bt/home/.config" >/dev/null 2>&1 && diff -r .local "$bt/home/.local" >/dev/null 2>&1 \
    || { bad "ink-theme: un color ya usado por el tema (#ffffff) se mezcla con el acento y no se puede deshacer"; bt_bad=1; }
# Violeta: el acento suave llega a los DOS temas de labwc, no solo al de fábrica
btx bin/ink-theme violeta >/dev/null 2>&1
grep -q '#a596c8' "$bt/home/.local/share/themes/Ink/labwc/themerc" 2>/dev/null \
  && grep -q '#a596c8' "$bt/home/.local/share/themes/Violeta/labwc/themerc" 2>/dev/null \
  && grep -q '#a596c8' "$bt/home/.config/waybar/style.css" 2>/dev/null \
  || { bad "ink-theme: el acento violeta no se aplica a todos los temas de labwc"; bt_bad=1; }
# look: cambia el <name> del tema sin pisar los <name> de <font> y alterna de vuelta a Ink
btx bin/ink-theme look Violeta >/dev/null 2>&1
grep -q '<name>Violeta</name>' "$bt/home/.config/labwc/rc.xml" 2>/dev/null \
  && grep -q '<name>JetBrainsMono Nerd Font</name>' "$bt/home/.config/labwc/rc.xml" 2>/dev/null \
  && [ "$(btx bin/ink-theme look status 2>/dev/null)" = Violeta ] \
  || { bad "ink-theme look: no cambia el tema o pisa el nombre de la fuente"; bt_bad=1; }
btx bin/ink-theme look >/dev/null 2>&1
grep -qx -- '    <name>Ink</name>' "$bt/home/.config/labwc/rc.xml" 2>/dev/null \
  || { bad "ink-theme look: al alternar no vuelve al tema Ink"; bt_bad=1; }
btx bin/ink-theme tinta >/dev/null 2>&1
diff -r .config "$bt/home/.config" >/dev/null 2>&1 && diff -r .local "$bt/home/.local" >/dev/null 2>&1 \
    || { bad "ink-theme look: la ida y vuelta no deja la configuración como estaba"; bt_bad=1; }
# look Violeta desde la tinta tiñe el acento (si no, el blanco domina igual que en Ink) y look Ink lo devuelve; uno elegido a mano se respeta
btx bin/ink-theme look Violeta >/dev/null 2>&1
[ "$(btx bin/ink-theme status 2>/dev/null)" = "violeta #a596c8" ] \
  && ! grep -qi 'fdfdfd' "$bt/home/.local/share/themes/Violeta/labwc/themerc" 2>/dev/null \
  || { bad "ink-theme look Violeta: no tiñe el acento de violeta al venir de la tinta"; bt_bad=1; }
btx bin/ink-theme look Ink >/dev/null 2>&1
diff -r .config "$bt/home/.config" >/dev/null 2>&1 && diff -r .local "$bt/home/.local" >/dev/null 2>&1 \
    || { bad "ink-theme look Ink: no devuelve la tinta tras el acento que puso Violeta"; bt_bad=1; }
btx bin/ink-theme jade >/dev/null 2>&1; btx bin/ink-theme look Violeta >/dev/null 2>&1; btx bin/ink-theme look Ink >/dev/null 2>&1
[ "$(btx bin/ink-theme status 2>/dev/null)" = "jade #4fb286" ] \
    || { bad "ink-theme look: pisa un acento elegido a mano"; bt_bad=1; }
btx bin/ink-theme tinta >/dev/null 2>&1
# Violeta: las superficies grandes (fila activa del menú, zonas de encaje) no usan el acento blanco
vt="$PWD/.local/share/themes/Violeta/labwc/themerc"
grep -Eq '^(menu\.items\.active\.bg\.color|snapping\.overlay\.[a-z]+\.(bg|border)\.color): #fdfdfd' "$vt" \
    && { bad "Violeta: una superficie grande (menú activo o encaje) vuelve a usar el acento blanco"; bt_bad=1; }

# El menú de acento pide tantas líneas como entradas imprime (colores + fondo + tema)
: > "$bt/fuzzel.args"; echo "" > "$bt/seq"
INK_SCREEN=3840x2160 btx bin/ink-theme menu >/dev/null 2>&1 || true
want_lines=$(( $(btx bin/ink-theme list 2>/dev/null | wc -l) + 2 ))
got_lines=$(sed -n 's/.*--lines \([0-9]*\).*/\1/p' "$bt/fuzzel.args" | tail -n1)
[ "$got_lines" = "$want_lines" ] \
    || { bad "ink-theme menu: --lines=$got_lines pero hay $want_lines entradas (se corta el menú)"; bt_bad=1; }
# monitors: guarda la rotación y la tiene en cuenta al colocar una pantalla al lado de otra (DP-1 girada: ancho lógico 1080/1.5 = 720)
echo "1 4" > "$bt/seq"; btx bin/monitors >/dev/null 2>&1
grep -q -- '--output DP-1 .*--transform 90' "$bt/home/.config/ink/monitors" 2>/dev/null \
    || { bad "monitors: no guarda --transform (una pantalla girada se endereza al reiniciar la sesión)"; bt_bad=1; }
grep -qx -- '--output HDMI-A-1 --on --pos 720,0' "$bt/randr.args" 2>/dev/null \
    || { bad "monitors: «poner a la derecha» ignora la rotación de la pantalla de referencia"; bt_bad=1; }
echo "0 3 2" > "$bt/seq"; : > "$bt/randr.args"; btx bin/monitors >/dev/null 2>&1
grep -qx -- '--output DP-1 --transform 180' "$bt/randr.args" || { bad "monitors: la opción Rotación no aplica --transform"; bt_bad=1; }
# ink-menu: el principal tiene 8 entradas; cada submenú lanza su comando y «Volver» regresa al principal
: > "$bt/fuzzel.args"; echo "" > "$bt/seq"; btx bin/ink-menu >/dev/null 2>&1
[ "$(sed -n 's/.*--lines \([0-9]*\).*/\1/p' "$bt/fuzzel.args" | head -n 1)" = 8 ] \
    || { bad "ink-menu: --lines no coincide con las 8 entradas del menú principal"; bt_bad=1; }
echo "3 2" > "$bt/seq"; btx bin/ink-menu >/dev/null 2>&1     # Red y audio → Salida de audio
echo "1 2" > "$bt/seq"; btx bin/ink-menu >/dev/null 2>&1     # Captura y grabación → Área al portapapeles
[ "$(cat "$bt/calls" 2>/dev/null)" = "$(printf 'audio-switch sink\nshot clip')" ] \
    || { bad "ink-menu: «Salida de audio» y «Captura → Área al portapapeles» no lanzan sus comandos"; bt_bad=1; }
: > "$bt/fuzzel.args"; echo "1 6 0" > "$bt/seq"; btx bin/ink-menu >/dev/null 2>&1   # Captura → Volver → el principal otra vez
[ "$(grep -c -- '--lines 8' "$bt/fuzzel.args")" = 2 ] \
    || { bad "ink-menu: «Volver» de un submenú no regresa al menú principal"; bt_bad=1; }
# ink-menu muestra el estado real (grabando → «Detener grabación»); ink-update avisa si hay kernel entre las actualizaciones
printf '#!/bin/sh\n[ "$2" = wf-recorder ] && [ -e "$BT/rec" ] && exit 0\nexit 1\n' > "$bt/bin/pgrep"
printf '#!/bin/sh\nprintf "linux 6.1-1 -> 6.2-1\\nfoo 1-1 -> 2-1\\n"\n' > "$bt/bin/checkupdates"
for c in paru yay; do printf '#!/bin/sh\nexit 0\n' > "$bt/bin/$c"; done
chmod +x "$bt"/bin/*
: > "$bt/rec"; echo "" > "$bt/seq"; btx bin/ink-menu >/dev/null 2>&1; rm -f "$bt/rec"
grep -q '●' "$bt/fuzzel.in" || { bad "ink-menu: grabando, «Captura y grabación» debe llevar el ●"; bt_bad=1; }
: > "$bt/rec"; echo "1" > "$bt/seq"; btx bin/ink-menu >/dev/null 2>&1; rm -f "$bt/rec"
grep -q 'Detener grabación' "$bt/fuzzel.in" || { bad "ink-menu: grabando, el submenú debe ofrecer «Detener grabación»"; bt_bad=1; }
btx bin/ink-update status 2>/dev/null | grep -q 'reinicia después' || { bad "ink-update: con el kernel entre las actualizaciones debe avisar de reiniciar"; bt_bad=1; }
# ink-fuzzel: en una pantalla pequeña recorta las filas y compacta; en una grande no toca nada; respeta --config
mkdir -p "$bt/fz"; printf '#!/bin/sh\n[ "$1" = --help ] && { echo "  --line-height --vertical-pad --horizontal-pad --inner-pad"; exit 0; }\necho "$*" | tee -a "%s/fz.args"\n' "$bt" > "$bt/fz/fuzzel"
chmod +x "$bt/fz/fuzzel"   # imprime y guarda los argumentos; --help anuncia las opciones de compactación
fzl() { sed -n 's/.*--lines \([0-9]*\).*/\1/p'; }
fz_small=$(PATH="$bt/fz:$PATH" XDG_CONFIG_HOME="$PWD/.config" INK_SCREEN=1366x768 bin/ink-fuzzel --dmenu --lines 23 --width 200)
fz_big=$(PATH="$bt/fz:$PATH" XDG_CONFIG_HOME="$PWD/.config" INK_SCREEN=3840x2160 bin/ink-fuzzel --dmenu --lines 23 --width 56)
fz_pick=$(PATH="$bt/fz:$PATH" XDG_CONFIG_HOME="$PWD/.config" INK_SCREEN=1366x768 bin/ink-fuzzel --config .config/fuzzel/wallpaper.ini --dmenu --lines 6 --width 44)
[ "$(printf '%s' "$fz_small" | fzl)" -le 19 ] && [ "$(printf '%s' "$fz_small" | fzl)" -ge 10 ] && case $fz_small in *--line-height*) true ;; *) false ;; esac \
    || { bad "ink-fuzzel: en 1366×768 las 23 filas pedidas deben recortarse (10–19) y compactarse (--line-height)"; bt_bad=1; }
mkdir -p "$bt/fzold"; printf '#!/bin/sh\n[ "$1" = --help ] && { echo "  --lines --width"; exit 0; }\necho "$*"\n' > "$bt/fzold/fuzzel"; chmod +x "$bt/fzold/fuzzel"
fz_old=$(PATH="$bt/fzold:$PATH" XDG_CONFIG_HOME="$PWD/.config" INK_SCREEN=1366x768 bin/ink-fuzzel --dmenu --lines 23 --width 56)
case $fz_old in *--line-height*|*--inner-pad*) bad "ink-fuzzel: pasa opciones de compactación a un fuzzel que no las conoce (el menú no abriría)"; bt_bad=1 ;; esac
[ "$fz_big" = "--dmenu --lines 23 --width 56" ] || { bad "ink-fuzzel: en una pantalla grande no debe cambiar nada (salió: $fz_big)"; bt_bad=1; }
[ "$(printf '%s' "$fz_pick" | fzl)" = 6 ] || { bad "ink-fuzzel: el selector de fondos (filas altas de wallpaper.ini) debe caber con sus 6 filas en 1366×768"; bt_bad=1; }
# la chuleta: se ajusta a la pantalla y su ancho cubre la línea más larga (sin «…»)
PATH="$bt/fz:$bt/bin:$PWD/bin:$PATH" XDG_CONFIG_HOME="$PWD/.config" INK_SCREEN=1366x768 bin/keys >/dev/null 2>&1; fz_keys=$(tail -n 1 "$bt/fz.args")
[ "$(printf '%s' "$fz_keys" | fzl)" -le 19 ] || { bad "keys: en 1366×768 la chuleta debe mostrar como mucho 19 filas (el resto, con scroll)"; bt_bad=1; }
[ "$(printf '%s' "$fz_keys" | sed -n 's/.*--width \([0-9]*\).*/\1/p')" -ge 60 ] || { bad "keys: el ancho no cubre la línea más larga (se cortaría con «…»)"; bt_bad=1; }
want_keys=$(awk '/^txt=\$\(cat <<.TXT.$/{f=1;next} /^TXT$/{if(f)exit} f' bin/keys | wc -l)
PATH="$bt/fz:$bt/bin:$PWD/bin:$PATH" XDG_CONFIG_HOME="$PWD/.config" INK_SCREEN=3840x2160 bin/keys >/dev/null 2>&1
fz_keys_big=$(tail -n 1 "$bt/fz.args")
[ "$(printf '%s' "$fz_keys_big" | fzl)" = "$want_keys" ] \
    || { bad "keys: pide --lines=$(printf '%s' "$fz_keys_big" | fzl) pero hay $want_keys entradas (sobran filas vacías)"; bt_bad=1; }
# nightlight: «restore» sin estado guardado (luz apagada) no es un error
btx bin/nightlight restore >/dev/null 2>&1 || { bad "nightlight restore falla cuando no hay estado guardado"; bt_bad=1; }
rm -rf "$bt"
[ "$bt_bad" = 0 ] && ok "bin/: ink-theme sin colisiones, monitors con rotación, ink-menu, ink-fuzzel (ajuste a pantalla) y nightlight restore"

# --- guardias de regresión: valores que ya se cambiaron a propósito y no deben volver sin pensarlo ---
guard_bad=0
grep -qE '^[^#]*PCIE_ASPM_ON_BAT=powersupersave' 2-optimize.sh && { bad "2-optimize.sh: powersupersave por defecto (congela algunos NVMe/Wi-Fi)"; guard_bad=1; }
grep -qE '^[^#]*ethernet\.cloned-mac-address' 3-privacy.sh && { bad "3-privacy.sh: MAC aleatoria en Ethernet (rompe DHCP con reserva, WoL y redes con control por MAC)"; guard_bad=1; }
grep -q 'ufw limit' 3-privacy.sh || { bad "3-privacy.sh: el firewall debe permitir SSH si sshd está activo antes de cerrar lo entrante"; guard_bad=1; }
grep -q 'fwupd' 2-optimize.sh && grep -q 'fwupd' 1-install.sh || { bad "fwupd debe instalarse (1-install.sh) y activar su refresco (2-optimize.sh)"; guard_bad=1; }
grep -q 'logind.conf.d' 2-optimize.sh || { bad "2-optimize.sh: falta la configuración de tapa/botón (logind) para portátiles"; guard_bad=1; }
grep -q 'pacman -Rns --print' 4-cleanup.sh && { bad "4-cleanup.sh: «pacman -Rns --print» es inválido (--nosave con --print): la simulación no funciona"; guard_bad=1; }
grep -q 'pgrep -x gamepad-awake' bin/ink-doctor || { bad "ink-doctor: el pgrep de gamepad-awake no coincide con el autostart"; guard_bad=1; }
grep -q 'SSH_CONNECTION' bin/idle-suspend && grep -q 'grep -vE' bin/idle-suspend || { bad "idle-suspend: el display local (:0) cuenta como sesión remota y nunca suspende"; guard_bad=1; }
grep -q 'font-feature-settings: "tnum 1, lnum 1";' .config/waybar/style.css || { bad "waybar: font-feature-settings mal escrita (GTK 3 exige una sola cadena; las cifras del reloj bailan)"; guard_bad=1; }
grep -qE '^export INK_YES=.*INK_32BIT.*OFFICE.*IMAGEMAGICK' install.sh || { bad "install.sh: no exporta OFFICE/IMAGEMAGICK/INK_32BIT a los hijos (OFFICE=1 ./install.sh calla y no instala)"; guard_bad=1; }
grep -qE '^[[:space:]]+mangohud[[:space:]]' 1-install.sh \
  && grep -qE '^[[:space:]]*PKGS32=\(.*lib32-mangohud' 1-install.sh \
  || { bad "1-install.sh: faltan mangohud o lib32-mangohud (el de 32 bits debe ir en PKGS32, dentro de multilib)"; guard_bad=1; }
grep -q 'hflags+=(--noconfirm)' 5-snapshots.sh || { bad "5-snapshots.sh: el helper AUR se cuelga con INK_YES=1 si no recibe --noconfirm"; guard_bad=1; }
grep -q 'grep -A1.*multilib' 1-install.sh || { bad "1-install.sh: falta acotar el bloque multilib antes de descomentarlo (podría activar SigLevel=Never)"; guard_bad=1; }
grep -q 'catalogo-winetricks' 6-wine.sh && grep -q 'trap restore_mime EXIT' 6-wine.sh \
  || { bad "6-wine.sh: falta detectar un catálogo winetricks vacío y restaurar mimeapps.list al salir"; guard_bad=1; }
! grep -q 'string sub -l 80' .config/fish/config.fish \
  || { bad "fish: la notificación de comando lento muestra argumentos (pueden contener credenciales)"; guard_bad=1; }
[ "$guard_bad" = 0 ] && ok "guardias de regresión (TLP, MAC, firewall+SSH, fwupd, logind, opciones heredadas)"

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
    cmp -s bin/ink-theme "$tmp/.local/bin/ink-theme" && cmp -s bin/ink-menu "$tmp/.local/bin/ink-menu" \
      && [ -x "$tmp/.local/bin/ink-theme" ] \
      || bad "dotfiles.sh: no instala los scripts actualizables en ~/.local/bin"
    grep -q '^PATH=\$HOME/\.local/bin:' .config/labwc/environment \
      || bad "environment: ~/.local/bin no va primero en el PATH de la sesión"
    ls -d "$tmp"/.ink-backup-* >/dev/null 2>&1 && bad "dotfiles.sh respaldó algo en un HOME vacío"
    again=$(HOME="$tmp" ./dotfiles.sh --dry-run </dev/null 2>&1 | grep -E '^(copiaría|respaldaría|daría)' || true)
    [ -z "$again" ] && ok "dotfiles.sh es idempotente (la 2.ª pasada no cambia nada)" || bad "la 2.ª pasada de dotfiles.sh aún cambiaría algo:
$again"
else
    bad "dotfiles.sh falló en un HOME vacío:
$(sed 's/^/    /' "$tmp/.log")"
fi
rm -rf "$tmp"

# --restore: lo respaldado vuelve tal cual y lo que había se respalda de nuevo (nada se pierde)
rt=$(mktemp -d); mkdir -p "$rt/.config/mako"; echo "MIO" > "$rt/.config/mako/config"
HOME="$rt" INK_YES=1 INK_NO_RELOAD=1 ./dotfiles.sh </dev/null >/dev/null 2>&1
if HOME="$rt" ./dotfiles.sh --restore >/dev/null 2>&1 && [ "$(cat "$rt/.config/mako/config")" = MIO ] \
   && [ "$(find "$rt" -maxdepth 1 -name '.ink-backup-*' | wc -l)" -ge 2 ]; then
    ok "dotfiles.sh --restore devuelve lo respaldado y conserva lo que había"
else bad "dotfiles.sh --restore no restauró bien"; fi
rm -rf "$rt"

# --- 4-cleanup.sh --dry-run con un pacman simulado: un cmake instalado a propósito (explícito) NO debe quitarse ---
# Solo como root: el script se reejecuta con sudo si no lo es, y sudo descartaría el PATH con el pacman simulado.
if [ "$(id -u)" = 0 ]; then
    mk=$(mktemp -d)
    cat > "$mk/pacman" <<'EOF'
#!/bin/bash
p=${@: -1}
case "$*" in
  "-Qq "*) case $p in cmake|clang|llvm|qt5-base) exit 0 ;; *) exit 1 ;; esac ;;
  "-Qqe")  echo cmake ;;
  "-Qqd")  printf 'clang\nllvm\nqt5-base\n' ;;
  -Qi*)    echo "Required By     : None" ;;
  -Rs*--print-format*) shift 4; printf '%s\n' "$@" ;;
  *) exit 0 ;;
esac
EOF
    chmod +x "$mk/pacman"
    out=$(PATH="$mk:$PATH" bash ./4-cleanup.sh --dry-run 2>&1 </dev/null)
    if grep -q 'cmake lo instalaste tú' <<<"$out" && ! grep -E 'Se quitan:.*cmake' <<<"$out" >/dev/null \
       && grep -qE 'Se quitan:.*clang' <<<"$out"; then
        ok "4-cleanup.sh respeta las herramientas de desarrollo instaladas a propósito"
    else bad "4-cleanup.sh: la prueba con pacman simulado falló:
$(sed 's/^/    /' <<<"$out")"; fi
    rm -rf "$mk"
else
    echo "· 4-cleanup.sh con pacman simulado: se omite (hace falta ser root; corre en el contenedor de Arch del CI)"
fi

exit $fail
