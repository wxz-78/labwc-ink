# shellcheck shell=bash
# lib/hwscan.sh — escaneo a fondo de hardware y arranque. Solo LEE: no cambia nada. Se carga con `source`.
# Se instala en /usr/local/lib/ink/hwscan.sh (lo cargan common.sh, ink-doctor e ink-hw).
#
# Qué detecta: modo de firmware (UEFI/BIOS), Secure Boot, ESP (y su espacio libre), gestor de arranque EN USO
# (y los que solo dejaron rastro), generador de initramfs, kernels (y headers para DKMS), microcódigo (si de verdad
# se carga), CPU, máquina virtual, GPU (híbridas, NVIDIA por generación, drivers que faltan), Wi-Fi, Bluetooth, audio
# (SOF), discos (NVMe/SSD/HDD), portátil, límite de carga de la batería, firmware que el kernel no pudo cargar y
# dispositivos PCI sin driver.
#
# Las funciones nunca abortan un script con «set -e» (devuelven 0 aunque falte una herramienta) y no usan pipes
# con «grep -q» (evita el falso negativo de «pipefail»).
#
# Para pruebas (check.sh), sin tocar el sistema real:
#   INK_SYSFS · INK_PROCFS · INK_ROOT (prefijo de /boot, /efi, /etc, /usr) · INK_ESP (ruta de la ESP)
#   INK_HW_NOCMD=1 (ignora programas externos) · INK_HW_PKGS="paq1 paq2" (paquetes «instalados» con NOCMD)
#   INK_KLOG=archivo (log del kernel) · INK_EFIBOOTMGR_OUT=archivo (salida de «efibootmgr -v»)

# ---------- utilidades internas ----------
_hw_root() { printf '%s' "${INK_ROOT:-}"; }
_hw_sys()  { printf '%s' "${INK_SYSFS:-/sys}"; }
_hw_proc() { printf '%s' "${INK_PROCFS:-/proc}"; }
_hw_have() { [ -z "${INK_HW_NOCMD:-}" ] && command -v "$1" >/dev/null 2>&1; }
_hw_pkg() {   # ¿paquete instalado?
  if [ -n "${INK_HW_NOCMD:-}" ]; then
    case " ${INK_HW_PKGS:-} " in *" $1 "*) return 0 ;; esac
    return 1
  fi
  command -v pacman >/dev/null 2>&1 && pacman -Qq "$1" >/dev/null 2>&1
}
_hw_read() { local v=""; [ -r "$1" ] && IFS= read -r v <"$1" 2>/dev/null || true; printf '%s' "$v"; }
_hw_first() { local f; for f in "$@"; do if [ -e "$f" ]; then printf '%s' "$f"; return 0; fi; done; return 0; }

_HW_KLOG=""; _HW_KLOG_DONE=0
hw_klog() {   # log del kernel de este arranque (se lee una sola vez)
  if [ "$_HW_KLOG_DONE" = 0 ]; then
    _HW_KLOG_DONE=1
    if [ -n "${INK_KLOG:-}" ]; then _HW_KLOG=$(cat "$INK_KLOG" 2>/dev/null || true)
    else
      if _hw_have journalctl; then _HW_KLOG=$(journalctl -k -b -q --no-pager 2>/dev/null || true); fi
      if [ -z "$_HW_KLOG" ] && _hw_have dmesg; then _HW_KLOG=$(dmesg 2>/dev/null || true); fi
    fi
  fi
  printf '%s\n' "$_HW_KLOG"
  return 0
}

# ---------- máquina, CPU y virtualización ----------
hw_virt() {   # none | nombre del hipervisor o contenedor (kvm, vmware, oracle, docker…)
  local v=""
  if _hw_have systemd-detect-virt; then v=$(systemd-detect-virt 2>/dev/null || true)
  elif grep -qw hypervisor "$(_hw_proc)/cpuinfo" 2>/dev/null; then v=vm; fi
  printf '%s' "${v:-none}"
  return 0
}

hw_cpu_vendor() {   # intel | amd | other
  local c; c="$(_hw_proc)/cpuinfo"
  if   grep -q GenuineIntel "$c" 2>/dev/null; then echo intel
  elif grep -q AuthenticAMD "$c" 2>/dev/null; then echo amd
  else echo other; fi
  return 0
}
hw_cpu_model()   { sed -n -e '/^model name/{s/^[^:]*:[[:space:]]*//;p;q}' "$(_hw_proc)/cpuinfo" 2>/dev/null; return 0; }
hw_cpu_threads() { grep -c '^processor' "$(_hw_proc)/cpuinfo" 2>/dev/null || true; return 0; }

hw_ucode_pkg() {   # intel-ucode | amd-ucode | (vacío: otra CPU o máquina virtual, donde no se puede cargar)
  [ "$(hw_virt)" = none ] || return 0
  case $(hw_cpu_vendor) in intel) echo intel-ucode ;; amd) echo amd-ucode ;; esac
  return 0
}

hw_dmi() {   # «fabricante modelo (BIOS versión, fecha)»
  local d; d="$(_hw_sys)/class/dmi/id"
  local v p ver bv bd
  v=$(_hw_read "$d/sys_vendor"); p=$(_hw_read "$d/product_name"); ver=$(_hw_read "$d/product_version")
  bv=$(_hw_read "$d/bios_version"); bd=$(_hw_read "$d/bios_date")
  [ -n "$v$p" ] && printf '%s %s%s' "$v" "$p" "${ver:+ ($ver)}"
  [ -n "$bv" ] && printf ' · BIOS %s%s' "$bv" "${bd:+ ($bd)}"
  return 0
}

# ---------- portátil ----------
hw_battery() {   # ruta de la batería del equipo (se ignoran las de periféricos: scope=Device)
  local d
  for d in "$(_hw_sys)"/class/power_supply/*; do
    if [ "$(_hw_read "$d/type")" = Battery ] && [ "$(_hw_read "$d/scope")" != Device ]; then printf '%s' "$d"; return 0; fi
  done
  return 0
}
hw_chassis() { _hw_read "$(_hw_sys)/class/dmi/id/chassis_type"; return 0; }
hw_is_laptop() {   # 1 si hay batería o el chasis es portátil (8 portátil, 9 laptop, 10 notebook, 11 handheld, 14 sub-notebook, 30 tablet, 31 convertible, 32 detachable)
  case $(hw_chassis) in 8|9|10|11|14|30|31|32) echo 1; return 0 ;; esac
  if [ -n "$(hw_battery)" ]; then echo 1; else echo 0; fi
  return 0
}
hw_charge_limit() {   # 1 si la batería permite fijar un límite de carga
  local b; b=$(hw_battery)
  if [ -n "$b" ] && [ -e "$b/charge_control_end_threshold" ]; then echo 1; else echo 0; fi
  return 0
}

# ---------- firmware, Secure Boot y ESP ----------
hw_firmware_mode() { if [ -d "$(_hw_sys)/firmware/efi" ]; then echo uefi; else echo bios; fi; return 0; }

_hw_efivar() {   # primer byte (decimal) del valor de una variable EFI global
  local f; f="$(_hw_sys)/firmware/efi/efivars/$1-8be4df61-93ca-11d2-aa0d-00e098032b8c"
  [ -r "$f" ] && od -An -t u1 -j4 -N1 "$f" 2>/dev/null | tr -d ' ' || true
  return 0
}
hw_secureboot() {   # on | off | setup (claves sin registrar) | unknown | bios
  local sb sm
  [ "$(hw_firmware_mode)" = uefi ] || { echo bios; return 0; }
  sb=$(_hw_efivar SecureBoot); sm=$(_hw_efivar SetupMode)
  if   [ "$sb" = 1 ]; then echo on
  elif [ "$sm" = 1 ]; then echo setup
  elif [ "$sb" = 0 ]; then echo off
  else echo unknown; fi
  return 0
}

hw_esp() {   # ruta de la partición ESP montada (la que lleva la carpeta EFI); vacío en BIOS o si no está montada
  local r m; r=$(_hw_root)
  if [ -n "${INK_ESP:-}" ]; then printf '%s' "$INK_ESP"; return 0; fi
  [ "$(hw_firmware_mode)" = uefi ] || return 0
  for m in /efi /boot/efi /boot; do
    if [ -d "$r$m/EFI" ] || [ -d "$r$m/efi" ]; then printf '%s' "$r$m"; return 0; fi
  done
  return 0
}
hw_esp_free_mb() { local e; e=$(hw_esp); [ -n "$e" ] && df -Pm "$e" 2>/dev/null | awk 'NR==2 {print $4}' || true; return 0; }

# ---------- gestor de arranque ----------
hw_efi_current() {   # línea (en minúsculas) de la entrada UEFI con la que arrancó el equipo, con su ruta
  if [ -n "${INK_EFIBOOTMGR_OUT:-}" ]; then
    awk '/^BootCurrent:/ {c = $2} c != "" && $1 == "Boot" c "*" {print tolower($0); exit}' "$INK_EFIBOOTMGR_OUT" 2>/dev/null || true
  elif _hw_have efibootmgr; then
    efibootmgr -v 2>/dev/null | awk '/^BootCurrent:/ {c = $2} c != "" && $1 == "Boot" c "*" {print tolower($0); exit}' || true
  fi
  return 0
}
hw_efi_entries() {   # todas las entradas UEFI (minúsculas)
  if [ -n "${INK_EFIBOOTMGR_OUT:-}" ]; then tr 'A-Z' 'a-z' <"$INK_EFIBOOTMGR_OUT" 2>/dev/null || true
  elif _hw_have efibootmgr; then efibootmgr -v 2>/dev/null | tr 'A-Z' 'a-z' || true; fi
  return 0
}

_hw_sniff_efi() {   # binario EFI → gestor, según las cadenas que lleva dentro (para rutas genéricas como \EFI\BOOT\BOOTX64.EFI)
  local f=$1
  [ -r "$f" ] || return 0
  if   grep -qaiE 'limine' "$f" 2>/dev/null; then echo limine
  elif grep -qaE 'rEFInd|refind' "$f" 2>/dev/null; then echo refind
  elif grep -qaE 'systemd-boot' "$f" 2>/dev/null; then echo systemd-boot
  elif grep -qaE 'GRUB|grub' "$f" 2>/dev/null; then echo grub
  fi
  return 0
}

limine_conf() {   # ruta del limine.conf en uso (vacío si no se encuentra)
  local r d dirs=() esp; r=$(_hw_root); esp=$(hw_esp)
  for d in "$r/boot" "$r/efi" "$esp"; do [ -n "$d" ] && [ -d "$d" ] && dirs+=("$d"); done
  [ "${#dirs[@]}" -gt 0 ] || return 0
  find "${dirs[@]}" -maxdepth 4 \( -name limine.conf -o -name limine.cfg \) -print -quit 2>/dev/null || true
  return 0
}

_hw_bl_candidates() {   # gestores con rastro en este equipo, uno por línea (el orden es la prioridad del respaldo)
  local r esp; r=$(_hw_root); esp=$(hw_esp)
  if _hw_pkg limine && [ -n "$(limine_conf)" ]; then echo limine; fi
  if _hw_pkg grub && [ -e "$r/boot/grub/grub.cfg" ]; then echo grub; fi
  if { [ -n "$esp" ] && [ -e "$esp/EFI/systemd/systemd-bootx64.efi" ]; } \
     || { _hw_have bootctl && bootctl is-installed >/dev/null 2>&1; }; then echo systemd-boot; fi
  if _hw_pkg refind || { [ -n "$esp" ] && [ -e "$esp/EFI/refind/refind_x64.efi" ]; }; then
    if [ -n "$esp" ] && [ -e "$esp/EFI/refind/refind_x64.efi" ]; then echo refind; fi
  fi
  if [ -e "$r/boot/syslinux/syslinux.cfg" ]; then echo syslinux; fi
  return 0
}
hw_bootloaders() { _hw_bl_candidates; }

# detect_bootloader → imprime: limine | grub | systemd-boot | refind | syslinux | uki | efistub | unknown
# Orden: INK_BOOTLOADER (forzado a mano) → entrada UEFI con la que arrancó el equipo (por su RUTA, no solo por su
# nombre: «Arch» puede ser GRUB o systemd-boot) → binario EFI genérico (se inspecciona por dentro) → rastros en disco.
detect_bootloader() {
  local cur f esp sn c r; r=$(_hw_root); esp=$(hw_esp)
  if [ -n "${INK_BOOTLOADER:-}" ]; then echo "$INK_BOOTLOADER"; return 0; fi
  cur=$(hw_efi_current)
  if [ -n "$cur" ]; then
    case $cur in
      *limine*)                          echo limine; return 0 ;;
      *refind*)                          echo refind; return 0 ;;
      *systemd-boot*|*systemd-bootx64*|*"linux boot manager"*) echo systemd-boot; return 0 ;;
      *grub*)                            echo grub; return 0 ;;
      *'\efi\linux\'*)                   echo uki; return 0 ;;
      *vmlinuz*|*initrd=*)               echo efistub; return 0 ;;
    esac
    f=$(sed -n 's/.*file(\([^)]*\)).*/\1/p' <<<"$cur")   # ruta genérica (\EFI\BOOT\BOOTX64.EFI): se mira qué hay dentro
    f=${f//\\//}
    if [ -n "$f" ] && [ -n "$esp" ]; then
      sn=$(_hw_sniff_efi "$esp$f")
      [ -n "$sn" ] && { echo "$sn"; return 0; }
    fi
  fi
  c=$(_hw_bl_candidates | head -n1)
  if [ -n "$c" ]; then echo "$c"; return 0; fi
  if [ -n "$esp" ] && [ -d "$esp/EFI/BOOT" ]; then   # sin entrada reconocible: el cargador de la ruta por defecto
    sn=$(_hw_sniff_efi "$esp/EFI/BOOT/BOOTX64.EFI")
    [ -n "$sn" ] && { echo "$sn"; return 0; }
  fi
  if [ -n "$esp" ] && [ -n "$(ls "$esp"/EFI/Linux/*.efi 2>/dev/null | head -n1)" ]; then echo uki; return 0; fi
  echo unknown
  return 0
}

hw_boot_config() {   # ruta de la configuración del gestor activo (archivo o carpeta de entradas)
  local bl=${1:-$(detect_bootloader)} r esp; r=$(_hw_root); esp=$(hw_esp)
  case $bl in
    grub)         _hw_first "$r/boot/grub/grub.cfg" ;;
    limine)       limine_conf ;;
    systemd-boot) _hw_first "$esp/loader/entries" "$r/boot/loader/entries" "$r/efi/loader/entries" ;;
    refind)       _hw_first "$esp/EFI/refind/refind.conf" "$r/boot/refind_linux.conf" ;;
    syslinux)     _hw_first "$r/boot/syslinux/syslinux.cfg" ;;
  esac
  return 0
}

# ---------- initramfs y kernels ----------
hw_initramfs_gen() {
  local m=0 d=0
  _hw_pkg mkinitcpio && m=1
  _hw_pkg dracut && d=1
  if   [ $m = 1 ] && [ $d = 1 ]; then echo "mkinitcpio+dracut"
  elif [ $m = 1 ]; then echo mkinitcpio
  elif [ $d = 1 ]; then echo dracut
  elif _hw_pkg booster; then echo booster
  else echo desconocido; fi
  return 0
}
hw_kernels() {   # kernels instalados (pkgbase), uno por línea
  local f
  for f in "$(_hw_root)"/usr/lib/modules/*/pkgbase; do
    if [ -r "$f" ]; then _hw_read "$f"; echo; fi
  done | sort -u
  return 0
}
hw_kernel_running() {   # pkgbase del kernel en uso (linux, linux-lts, linux-zen…)
  local rel; rel=$(uname -r 2>/dev/null || true)
  _hw_read "$(_hw_root)/usr/lib/modules/$rel/pkgbase"
  return 0
}
hw_headers_missing() {   # con DKMS: kernels instalados sin sus headers (los módulos DKMS no compilarían)
  local k
  _hw_pkg dkms || return 0
  for k in $(hw_kernels); do _hw_pkg "$k-headers" || echo "$k-headers"; done
  return 0
}

# ucode_hint GESTOR PAQUETE-UCODE → texto con lo que falta hacer para cargar el microcódigo
ucode_hint() {
  local bl=$1 img=$2
  case $bl in
    grub)         echo "sudo grub-mkconfig -o /boot/grub/grub.cfg   (detecta ${img}.img solo) — o añade el hook «microcode» a HOOKS en /etc/mkinitcpio.conf y ejecuta  sudo mkinitcpio -P" ;;
    limine)       echo "lo más simple: añade el hook «microcode» a HOOKS en /etc/mkinitcpio.conf y ejecuta  sudo mkinitcpio -P  (o, en tu limine.conf, ANTES del initramfs:  module_path: boot():/${img}.img; con limine-mkinitcpio-hook revisa /etc/default/limine)" ;;
    systemd-boot) echo "lo más simple: añade el hook «microcode» a HOOKS en /etc/mkinitcpio.conf y ejecuta  sudo mkinitcpio -P  (o en tu entrada de /boot/loader/entries/*.conf, ANTES del initramfs:  initrd /${img}.img)" ;;
    refind)       echo "en refind_linux.conf añade  initrd=/${img}.img  antes del initramfs, o usa mkrlconf (o el hook «microcode» de mkinitcpio)" ;;
    uki|efistub)  echo "añade el hook «microcode» a HOOKS en /etc/mkinitcpio.conf y regenera con  sudo mkinitcpio -P  (el microcódigo va dentro de la imagen)" ;;
    *)            echo "añade ${img}.img como primer initrd en tu gestor de arranque, o el hook «microcode» de mkinitcpio (wiki de Arch: Microcode)" ;;
  esac
  return 0
}

# hw_ucode_state [GESTOR] → «estado|motivo». Estados:
#   activo (el kernel confirma que lo aplicó en este arranque) · configurado (instalado y enlazado: hook, initrd o dracut)
#   falta (instalado pero NADA lo carga) · sin-paquete · desconocido (no se puede leer la config sin root)
#   vm (máquina virtual: lo gestiona el anfitrión) · no-aplica
hw_ucode_state() {
  local bl=${1:-$(detect_bootloader)} r pkg cfg unread=0 f hooks
  r=$(_hw_root)
  if [ "$(hw_virt)" != none ]; then echo "vm|"; return 0; fi
  case $(hw_cpu_vendor) in intel) pkg=intel-ucode ;; amd) pkg=amd-ucode ;; *) echo "no-aplica|"; return 0 ;; esac
  if ! _hw_pkg "$pkg"; then echo "sin-paquete|$pkg"; return 0; fi
  if grep -qiE 'microcode:.*updated' <<<"$(hw_klog)"; then echo "activo|log del kernel"; return 0; fi
  # hook «microcode» de mkinitcpio (el predeterminado de Arch desde 2024): el microcódigo va dentro del initramfs/UKI
  hooks=$(grep -hE '^[[:space:]]*HOOKS' "$r/etc/mkinitcpio.conf" "$r"/etc/mkinitcpio.conf.d/*.conf 2>/dev/null || true)
  if grep -qw microcode <<<"$hooks"; then
    echo "configurado|hook «microcode» de mkinitcpio"; return 0
  fi
  if _hw_pkg dracut; then echo "configurado|dracut lo incluye solo"; return 0; fi
  # referencia directa en la configuración del gestor (initrd / module_path)
  cfg=$(hw_boot_config "$bl")
  if [ -n "$cfg" ]; then
    if [ -d "$cfg" ]; then
      for f in "$cfg"/*.conf; do
        [ -e "$f" ] || continue
        if [ ! -r "$f" ]; then unread=1; elif grep -qs ucode "$f"; then echo "configurado|$f"; return 0; fi
      done
    elif [ ! -r "$cfg" ]; then unread=1
    elif grep -qs ucode "$cfg"; then echo "configurado|$cfg"; return 0; fi
  fi
  [ "$bl" = limine ] && [ -r /etc/default/limine ] && grep -qs ucode /etc/default/limine && { echo "configurado|/etc/default/limine"; return 0; }
  if [ "$unread" = 1 ]; then echo "desconocido|$cfg"; else echo "falta|"; fi
  return 0
}

# ---------- GPU ----------
hw_gpus() {   # una línea por GPU: ranura|vendor|device|driver|boot_vga|clase
  local d cls ven dev drv bv
  for d in "$(_hw_sys)"/bus/pci/devices/*; do
    [ -r "$d/class" ] || continue
    cls=$(_hw_read "$d/class")
    case $cls in 0x03*) ;; *) continue ;; esac
    ven=$(_hw_read "$d/vendor"); dev=$(_hw_read "$d/device")
    drv=""; [ -L "$d/driver" ] && drv=$(basename "$(readlink "$d/driver")")
    bv=$(_hw_read "$d/boot_vga")
    printf '%s|%s|%s|%s|%s|%s\n' "${d##*/}" "$ven" "$dev" "${drv:-ninguno}" "${bv:-0}" "$cls"
  done
  return 0
}
hw_gpu_kind() {   # vendor (0x....) → intel | amd | nvidia | virtual | otro
  case $1 in
    0x8086) echo intel ;;
    0x1002) echo amd ;;
    0x10de) echo nvidia ;;
    0x1af4|0x15ad|0x1234|0x80ee|0x1b36|0x1414|0x1ab8) echo virtual ;;
    *) echo otro ;;
  esac
  return 0
}
hw_gpu_name() {   # nombre legible de la GPU (lspci si está; si no, ids)
  local slot=$1 ven=$2 dev=$3 n=""
  if _hw_have lspci; then n=$(lspci -nn -s "$slot" 2>/dev/null | sed 's/^[^ ]* //' || true); fi
  printf '%s' "${n:-${ven#0x}:${dev#0x}}"
  return 0
}
hw_gpu_kinds() {   # tipos de GPU distintos, uno por línea
  local line ven
  hw_gpus | while IFS='|' read -r _ ven _; do hw_gpu_kind "$ven"; done | sort -u
  return 0
}
hw_gpu_hybrid() {   # 1 si hay dos o más GPU reales (iGPU + dGPU)
  local n; n=$(hw_gpus | grep -vc '^$' || true)
  if [ "${n:-0}" -ge 2 ]; then echo 1; else echo 0; fi
  return 0
}
# hw_nvidia_family device-id → turing+ | pascal | maxwell | antigua   (por rango de ID de dispositivo PCI; orientativo)
hw_nvidia_family() {
  local id=$(( ${1:-0} ))
  if   [ "$id" -ge $((0x1e00)) ]; then echo turing+
  elif [ "$id" -ge $((0x1b00)) ]; then echo pascal      # Pascal (y Volta)
  elif [ "$id" -ge $((0x1340)) ]; then echo maxwell
  else echo antigua; fi
  return 0
}
# hw_nvidia_hint FAMILIA → paquetes recomendados (Arch, según la wiki «NVIDIA»; el driver 590 dejó fuera Pascal y anteriores)
hw_nvidia_hint() {
  case $1 in
    turing+) echo "nvidia-open (kernel linux) · nvidia-open-lts (linux-lts) · nvidia-open-dkms (otros kernels, con sus headers) + nvidia-utils · CachyOS: el paquete linux-cachyos-nvidia-open de su kernel" ;;
    pascal|maxwell) echo "rama legacy del AUR: nvidia-580xx-dkms + nvidia-580xx-utils (el driver actual ya no soporta tu GPU; los paquetes oficiales no sirven)" ;;
    *) echo "GPU muy antigua: usa nouveau (mesa) o el AUR: nvidia-470xx-dkms (Kepler), nvidia-390xx-dkms (Fermi); mira la wiki de Arch «NVIDIA»" ;;
  esac
  return 0
}
_hw_pkg_find() {   # _hw_pkg_find REGEX → un paquete instalado cuyo nombre case con la expresión (vacío si ninguno)
  local p
  if [ -n "${INK_HW_NOCMD:-}" ]; then
    for p in ${INK_HW_PKGS:-}; do [[ $p =~ $1 ]] && { echo "$p"; return 0; }; done
    return 0
  fi
  command -v pacman >/dev/null 2>&1 || return 0
  pacman -Qq 2>/dev/null | grep -E -m1 -- "$1" || true
}
hw_nvidia_installed() {   # paquete de driver NVIDIA ya instalado (vacío si ninguno)
  local p
  for p in nvidia-open nvidia-open-lts nvidia-open-dkms nvidia nvidia-lts nvidia-dkms nvidia-580xx-dkms nvidia-470xx-dkms nvidia-390xx-dkms; do
    if _hw_pkg "$p"; then echo "$p"; return 0; fi
  done
  # derivados con kernel propio (CachyOS: linux-cachyos-nvidia-open, linux-cachyos-lts-nvidia-open…): el módulo viene con el kernel
  p=$(_hw_pkg_find '^linux-.+-nvidia(-open)?$'); [ -z "$p" ] || echo "$p"
  return 0
}

# ---------- Wi-Fi, Bluetooth, audio ----------
hw_wifi() {   # una línea por interfaz Wi-Fi: nombre|driver
  local n drv
  for n in "$(_hw_sys)"/class/net/*; do
    [ -d "$n/wireless" ] || [ -d "$n/phy80211" ] || continue
    drv=""; [ -L "$n/device/driver" ] && drv=$(basename "$(readlink "$n/device/driver")")
    printf '%s|%s\n' "${n##*/}" "${drv:-?}"
  done
  return 0
}
hw_ethernet_count() {
  local n c=0
  for n in "$(_hw_sys)"/class/net/*; do
    [ -e "$n/device" ] || continue
    [ -d "$n/wireless" ] || [ -d "$n/phy80211" ] || c=$((c + 1))
  done
  echo "$c"
  return 0
}
hw_rfkill_blocked() {   # bloqueos de radio: «bluetooth:soft», «wlan:hard»…
  local r t
  for r in "$(_hw_sys)"/class/rfkill/rfkill*; do
    [ -d "$r" ] || continue
    t=$(_hw_read "$r/type")
    [ "$(_hw_read "$r/hard")" = 1 ] && echo "$t:hard"
    [ "$(_hw_read "$r/soft")" = 1 ] && echo "$t:soft"
  done
  return 0
}
hw_bluetooth() {   # activo (hay controlador hci) | sin-driver (hay un dongle USB pero ningún hci) | no
  local sys f; sys=$(_hw_sys)
  if [ -d "$sys/class/bluetooth" ] && [ -n "$(ls -A "$sys/class/bluetooth" 2>/dev/null)" ]; then echo activo; return 0; fi
  for f in "$sys"/bus/usb/devices/*/bDeviceClass "$sys"/bus/usb/devices/*/bInterfaceClass; do
    if [ "$(_hw_read "$f")" = e0 ]; then echo sin-driver; return 0; fi
  done
  echo no
  return 0
}
hw_sound_cards() {   # número de tarjetas de sonido que el kernel ya registró
  local c n=0
  for c in "$(_hw_sys)"/class/sound/card*; do [ -e "$c" ] && n=$((n + 1)); done
  echo "$n"
  return 0
}
# hw_wants_sof → 0 si el audio necesita sof-firmware; 1 si no. Solo hace falta cuando:
#   · el controlador enlazado ya es SOF (snd_sof_*), o
#   · hay audio Intel/AMD con DSP y el kernel no registró NINGUNA tarjeta de sonido, o
#   · el log del kernel se queja del firmware de SOF.
# Un Intel con HDA clásico (snd_hda_intel, p. ej. Skylake) ya suena sin él: no se instala (menos paquetes, menos ruido).
hw_wants_sof() {
  local d cls ven drv dsp=0
  for d in "$(_hw_sys)"/bus/pci/devices/*; do
    [ -r "$d/class" ] || continue
    cls=$(_hw_read "$d/class"); ven=$(_hw_read "$d/vendor")
    case "$ven:$cls" in 0x8086:0x04*|0x1022:0x0480*) dsp=1 ;; *) continue ;; esac
    drv=""; [ -L "$d/driver" ] && drv=$(basename "$(readlink "$d/driver")")
    case $drv in snd_sof*) return 0 ;; esac
  done
  [ "$dsp" = 1 ] || return 1
  [ "$(hw_sound_cards)" = 0 ] && return 0
  if grep -qiE 'sof.*(firmware.*(fail|error|not found)|failed.*firmware)|Direct firmware load for intel/sof' <<<"$(hw_klog)"; then return 0; fi
  return 1
}

# ---------- mandos ----------
hw_gamepads() {   # una línea por mando: eventN|nombre (dispositivos con BTN_GAMEPAD 0x130 o BTN_JOYSTICK 0x120)
  local d w n bit i b idx
  for d in "$(_hw_sys)"/class/input/event*; do
    [ -r "$d/device/capabilities/key" ] || continue
    read -ra w < "$d/device/capabilities/key" || true
    n=${#w[@]}
    for bit in 304 288; do
      i=$((bit / 64)); b=$((bit % 64)); idx=$((n - 1 - i))
      [ "$idx" -ge 0 ] || continue
      if (( (0x${w[$idx]} >> b) & 1 )); then printf '%s|%s\n' "${d##*/}" "$(_hw_read "$d/device/name")"; break; fi
    done
  done
  return 0
}

# ---------- discos ----------
hw_disks() {   # una línea por disco: nombre|tipo|GiB|modelo   (tipo: nvme, ssd, hdd, usb, mmc, virtual)
  local d n t rota sz model
  for d in "$(_hw_sys)"/block/*; do
    [ -e "$d" ] || continue
    n=${d##*/}
    case $n in loop*|ram*|zram*|dm-*|md*|sr*|fd*|nbd*) continue ;; esac
    rota=$(_hw_read "$d/queue/rotational"); sz=$(_hw_read "$d/size")
    [ "${sz:-0}" -gt 0 ] 2>/dev/null || continue   # sin medio (lector vacío, dispositivo sin capacidad)
    case $n in
      nvme*) t=nvme ;;
      mmcblk*) t=mmc ;;
      vd*|xvd*) t=virtual ;;
      *) if [ "$rota" = 1 ]; then t=hdd; else t=ssd; fi
         case $(readlink -f "$d" 2>/dev/null) in */usb*) t=usb ;; esac ;;
    esac
    model=$(_hw_read "$d/device/model"); model=${model%"${model##*[![:space:]]}"}
    printf '%s|%s|%s|%s\n' "$n" "$t" "$(( ${sz:-0} / 2097152 ))" "$model"
  done
  return 0
}
hw_root_fs() {
  if [ -n "${INK_ROOT_FS:-}" ]; then printf '%s' "$INK_ROOT_FS"; return 0; fi
  _hw_have findmnt && findmnt -no FSTYPE "$(_hw_root)/" 2>/dev/null || true
  return 0
}
hw_root_opts() { # opciones de montaje de «/» (para los consejos de btrfs)
  if [ -n "${INK_ROOT_OPTS:-}" ]; then printf '%s' "$INK_ROOT_OPTS"; return 0; fi
  _hw_have findmnt && findmnt -no OPTIONS "$(_hw_root)/" 2>/dev/null || true
  return 0
}
hw_root_luks() {   # 1 si la raíz está sobre LUKS/dm-crypt
  local src
  if _hw_have findmnt && _hw_have lsblk; then
    src=$(findmnt -no SOURCE / 2>/dev/null | sed 's/\[.*//' || true)
    if [ -n "$src" ] && grep -qw crypt <<<"$(lsblk -s -no TYPE "$src" 2>/dev/null)"; then echo 1; return 0; fi
  fi
  echo 0
  return 0
}

# ---------- firmware que falta y dispositivos sin driver ----------
hw_missing_firmware() {   # archivos de firmware que el kernel no pudo cargar en este arranque
  local out
  out=$(hw_klog | sed -n -e 's/.*[Dd]irect firmware load for \([^ ]*\) failed.*/\1/p' -e 's/.*firmware: failed to load \([^ ]*\) .*/\1/p' || true)
  grep -v -E '^regulatory\.db' <<<"$out" | sort -u | grep -v '^$' || true
  return 0
}
hw_pci_unbound() {   # dispositivos PCI útiles (red, vídeo, audio, almacenamiento, inalámbricos) sin driver: ranura|vendor|device|clase
  local d cls drv
  for d in "$(_hw_sys)"/bus/pci/devices/*; do
    [ -r "$d/class" ] || continue
    cls=$(_hw_read "$d/class")
    case $cls in 0x01*|0x02*|0x03*|0x04*|0x0d*) ;; *) continue ;; esac
    [ -L "$d/driver" ] && continue
    printf '%s|%s|%s|%s\n' "${d##*/}" "$(_hw_read "$d/vendor")" "$(_hw_read "$d/device")" "$cls"
  done
  return 0
}

# ---------- salida para scripts: KEY=VALOR ----------
hw_env() {
  local ucode gk
  ucode=$(hw_ucode_state)
  gk=$(hw_gpu_kinds | tr '\n' ' '); gk=${gk% }
  printf 'FIRMWARE=%s\n'    "$(hw_firmware_mode)"
  printf 'SECUREBOOT=%s\n'  "$(hw_secureboot)"
  printf 'ESP=%s\n'         "$(hw_esp)"
  printf 'BOOTLOADER=%s\n'  "$(detect_bootloader)"
  printf 'INITRAMFS=%s\n'   "$(hw_initramfs_gen)"
  printf 'CPU_VENDOR=%s\n'  "$(hw_cpu_vendor)"
  printf 'VIRT=%s\n'        "$(hw_virt)"
  printf 'UCODE_PKG=%s\n'   "$(hw_ucode_pkg)"
  printf 'UCODE_STATE=%s\n' "${ucode%%|*}"
  printf 'GPU_KINDS=%s\n'   "$gk"
  printf 'GPU_HYBRID=%s\n'  "$(hw_gpu_hybrid)"
  printf 'LAPTOP=%s\n'      "$(hw_is_laptop)"
  printf 'BLUETOOTH=%s\n'   "$(hw_bluetooth)"
  printf 'ROOT_FS=%s\n'     "$(hw_root_fs)"
  return 0
}

# hw_summary → resumen corto de una línea por tema (para el instalador)
hw_summary() {
  local gk n m
  printf '    Equipo:   %s\n' "$(hw_dmi)"
  printf '    CPU:      %s (%s hilos) · virtualización: %s\n' "$(hw_cpu_model)" "$(hw_cpu_threads)" "$(hw_virt)"
  printf '    Arranque: %s · Secure Boot: %s · gestor: %s · initramfs: %s\n' \
    "$(hw_firmware_mode)" "$(hw_secureboot)" "$(detect_bootloader)" "$(hw_initramfs_gen)"
  gk=$(hw_gpu_kinds | tr '\n' ' ')
  printf '    GPU:      %s%s\n' "${gk:-ninguna detectada}" "$([ "$(hw_gpu_hybrid)" = 1 ] && echo ' (híbrida)')"
  printf '    Tipo:     %s · Bluetooth: %s · Wi-Fi: %s\n' \
    "$([ "$(hw_is_laptop)" = 1 ] && echo portátil || echo sobremesa)" "$(hw_bluetooth)" "$(hw_wifi | wc -l)"
  m=$(hw_disks | cut -d'|' -f2 | sort | uniq -c | awk '{printf "%s %s · ", $1, $2}')
  printf '    Discos:   %s\n' "${m% · }"
  return 0
}

# ---------- informes (usan ok/bad/info/hdr del script que los llama; si no existen, sencillos) ----------
declare -F ok   >/dev/null 2>&1 || ok()   { printf ' ✔ %s\n' "$*"; }
declare -F bad  >/dev/null 2>&1 || bad()  { printf ' ! %s\n' "$*"; }
declare -F info >/dev/null 2>&1 || info() { printf ' · %s\n' "$*"; }
declare -F hdr  >/dev/null 2>&1 || hdr()  { printf '\n%s\n' "$*"; }
# HW_BRIEF=1 → los informes solo dicen lo que está bien (✔) o mal (!); el detalle informativo se omite (lo usa ink-doctor)
hw_info() { [ -n "${HW_BRIEF:-}" ] || info "$@"; return 0; }

hw_report_boot() {
  local mode sb esp free bl cfg cand others ik kr gen st why pkg hm n
  hdr "Arranque"
  mode=$(hw_firmware_mode); sb=$(hw_secureboot); bl=$(detect_bootloader)
  if [ "$mode" = uefi ]; then
    hw_info "Modo UEFI · Secure Boot: $sb"
    [ "$sb" = on ] && hw_info "Con Secure Boot activo solo arrancan binarios firmados: kernels propios, DKMS y NVIDIA exigen firmar (sbctl)"
    esp=$(hw_esp)
    if [ -z "$esp" ]; then bad "No encuentro la ESP montada (/efi, /boot/efi o /boot): sin ella no se actualizan el gestor ni los kernels"
    else
      free=$(hw_esp_free_mb)
      if [ -n "$free" ] && [ "$free" -lt 100 ] 2>/dev/null; then bad "ESP ($esp) con solo ${free} MiB libres: el próximo kernel puede no caber (limpia o amplía la ESP)"
      else ok "ESP en $esp${free:+ · ${free} MiB libres}"; fi
    fi
  else
    hw_info "Modo BIOS (legacy): sin ESP ni Secure Boot"
  fi

  case $bl in
    unknown) case $(hw_virt) in
               docker|podman|lxc|lxc-libvirt|systemd-nspawn|openvz|wsl|rkt) hw_info "Contenedor: no tiene gestor de arranque propio" ;;
               *) bad "No pude identificar el gestor de arranque (fuérzalo con INK_BOOTLOADER=grub|limine|systemd-boot|refind)" ;;
             esac ;;
    uki)     ok "Gestor: UKI (imagen unificada del kernel arrancada directo desde el firmware)" ;;
    efistub) ok "Gestor: EFISTUB (el firmware arranca el kernel directamente, sin menú)" ;;
    *)       ok "Gestor de arranque en uso: $bl" ;;
  esac
  others=""
  for cand in $(hw_bootloaders); do [ "$cand" != "$bl" ] && others="$others $cand"; done
  [ -n "$others" ] && hw_info "También hay rastros de:$others (si ya no lo usas, quítalo para que no se mezclen las actualizaciones)"
  cfg=$(hw_boot_config "$bl")
  case $bl in grub|limine|systemd-boot|refind|syslinux)
    if [ -n "$cfg" ]; then hw_info "Configuración: $cfg"
    else bad "No encuentro la configuración de $bl (¿/boot sin montar?)"; fi ;;
  esac
  if [ "$bl" = grub ] && ! ls "$(_hw_root)"/boot/vmlinuz-* >/dev/null 2>&1; then
    bad "GRUB sin kernels en /boot (¿/boot no estaba montado al actualizar?): reinstala el kernel con  sudo pacman -S linux"; fi
  if [ "$mode" = uefi ] && grep -q 'windows boot manager' <<<"$(hw_efi_entries)"; then
    hw_info "Hay un Windows instalado (arranque dual)$([ "$bl" = grub ] && ! _hw_pkg os-prober && echo ': para que GRUB lo muestre instala os-prober y regenera el menú')"
  fi

  gen=$(hw_initramfs_gen); hw_info "Generador de initramfs: $gen"
  kr=$(hw_kernel_running); ik=$(hw_kernels | tr '\n' ' ')
  [ -n "$ik" ] && hw_info "Kernel en uso: ${kr:-?} · instalados: $ik"
  hm=$(hw_headers_missing | tr '\n' ' ')
  [ -n "$hm" ] && bad "DKMS instalado pero faltan headers: ${hm% }  (sudo pacman -S ${hm% }); sin ellos los módulos no compilan"

  IFS='|' read -r st why <<<"$(hw_ucode_state "$bl")"
  pkg=$(hw_ucode_pkg)
  case $st in
    activo)       ok "Microcódigo aplicado en este arranque (confirmado por el kernel)" ;;
    configurado)  ok "Microcódigo instalado y enlazado al arranque (${why})" ;;
    falta)        bad "El microcódigo ($pkg) está instalado pero nada lo carga: $(ucode_hint "$bl" "$pkg")" ;;
    sin-paquete)  bad "Falta el microcódigo de tu CPU: sudo pacman -S $why" ;;
    desconocido)  hw_info "No puedo leer la configuración de arranque sin permisos de root: ejecuta  sudo ink-hw  para confirmar el microcódigo" ;;
    vm)           hw_info "Máquina virtual: el microcódigo lo gestiona el anfitrión" ;;
    *)            hw_info "Microcódigo: no aplica a esta CPU" ;;
  esac
  n=$(hw_root_fs)
  [ -n "$n" ] && hw_info "Raíz: $n$([ "$(hw_root_luks)" = 1 ] && echo ' sobre LUKS (cifrada)')"
  return 0
}

hw_report_hardware() {
  local line slot ven dev drv bv cls kind name fam pkg main nv ml c v n d t mod
  hdr "Hardware"
  hw_info "Equipo: $(hw_dmi)"
  hw_info "CPU: $(hw_cpu_model) · $(hw_cpu_threads) hilos"
  v=$(hw_virt)
  case $v in
    none) ;;
    docker|podman|lxc|lxc-libvirt|systemd-nspawn|openvz|wsl|rkt) hw_info "Virtualización: contenedor ($v)" ;;
    *) hw_info "Virtualización: máquina virtual ($v). Herramientas del invitado: qemu/KVM → qemu-guest-agent + spice-vdagent · VirtualBox → virtualbox-guest-utils · VMware → open-vm-tools" ;;
  esac
  if [ "$(hw_is_laptop)" = 1 ]; then
    hw_info "Tipo: portátil (chasis $(hw_chassis); batería: $([ -n "$(hw_battery)" ] && echo sí || echo no detectada))"
    [ "$(hw_charge_limit)" = 1 ] && hw_info "Tu batería admite límite de carga (p. ej. 80 %): descomenta START/STOP_CHARGE_THRESH_BAT0 en /etc/tlp.d/10-ink.conf"
    [ -e "$(_hw_sys)/firmware/acpi/platform_profile" ] && hw_info "Perfiles de energía del firmware disponibles (los usa TLP)"
  else
    hw_info "Tipo: sobremesa/servidor"
  fi

  # --- GPU ---
  n=0; nv=0
  while IFS='|' read -r slot ven dev drv bv cls; do
    [ -n "$slot" ] || continue
    n=$((n + 1)); kind=$(hw_gpu_kind "$ven"); name=$(hw_gpu_name "$slot" "$ven" "$dev")
    main=""; [ "$bv" = 1 ] && main=" · principal"
    hw_info "GPU: $name · driver: $drv$main"
    case $kind in
      intel) _hw_pkg vulkan-intel || bad "Falta vulkan-intel (Vulkan/DXVK): sudo pacman -S vulkan-intel" ;;
      amd)   _hw_pkg vulkan-radeon || bad "Falta vulkan-radeon (Vulkan/DXVK): sudo pacman -S vulkan-radeon" ;;
      virtual) hw_info "GPU virtual: sin aceleración 3D real (en el invitado instala las herramientas indicadas arriba)" ;;
      nvidia)
        nv=1; fam=$(hw_nvidia_family "$dev")
        hw_info "NVIDIA generación «$fam»: $(hw_nvidia_hint "$fam")"
        pkg=$(hw_nvidia_installed)
        case $drv in
          nvidia) ok "Driver propietario NVIDIA cargado${pkg:+ ($pkg)}"
                  if [ "$(_hw_read "$(_hw_sys)/module/nvidia_drm/parameters/modeset")" != Y ]; then
                    bad "nvidia_drm.modeset no está activo: Wayland (labwc) lo necesita. Añade  nvidia_drm.modeset=1  a la línea de comandos del kernel"; fi ;;
          nouveau) hw_info "Usas nouveau (libre; rendimiento limitado). Para jugar o usar CUDA instala el driver indicado y reinicia" ;;
          ninguno) bad "La GPU NVIDIA no tiene driver cargado: instala el indicado arriba y reinicia" ;;
          *)       hw_info "Driver actual: $drv" ;;
        esac
        [ -z "$pkg" ] && [ "$drv" = nvidia ] && hw_info "El driver está cargado pero no encuentro su paquete en pacman (¿instalación manual?)" ;;
      *) [ "$drv" = ninguno ] && bad "GPU sin driver cargado ($name)" ;;
    esac
  done < <(hw_gpus)
  [ "$n" = 0 ] && hw_info "No se detectó ninguna GPU en /sys (¿máquina virtual sin gráficos?)"
  if [ "$(hw_gpu_hybrid)" = 1 ]; then
    hw_info "Gráfica híbrida: el escritorio usa la principal (boot_vga). Para un programa concreto en la dedicada: DRI_PRIME=1 (AMD/Intel)$([ "$nv" = 1 ] && echo ' · prime-run (paquete nvidia-prime) en NVIDIA')"
  fi

  # --- red, Bluetooth, audio ---
  ml=0
  while IFS='|' read -r c d; do
    [ -n "$c" ] || continue; ml=1
    hw_info "Wi-Fi: $c · driver: $d"
  done < <(hw_wifi)
  [ "$ml" = 0 ] && hw_info "Wi-Fi: ninguna interfaz inalámbrica$([ -n "$(hw_pci_unbound | grep '|0x02' || true)" ] && echo ' (pero hay una tarjeta de red sin driver: mira más abajo)')"
  hw_info "Ethernet: $(hw_ethernet_count) interfaz(ces)"
  t=$(hw_rfkill_blocked | tr '\n' ' ')
  if [ -n "$t" ]; then bad "Radio bloqueada: ${t% }  (soft: rfkill unblock all · hard: interruptor físico o tecla Fn de modo avión)"; fi
  case $(hw_bluetooth) in
    activo)     ok "Bluetooth: controlador activo" ;;
    sin-driver) bad "Hay un adaptador Bluetooth USB pero ningún controlador: falta firmware (linux-firmware) o el módulo btusb" ;;
    *)          hw_info "Bluetooth: sin adaptador" ;;
  esac
  if hw_wants_sof; then
    if _hw_pkg sof-firmware; then ok "Audio Intel/AMD moderno: sof-firmware instalado"
    else bad "Tu audio puede necesitar sof-firmware (si no hay sonido): sudo pacman -S sof-firmware"; fi
  fi

  # --- discos ---
  while IFS='|' read -r n t d mod; do
    [ -n "$n" ] || continue
    hw_info "Disco: $n · $t · ${d} GiB${mod:+ · $mod}"
  done < <(hw_disks)
  t=$(hw_disks | cut -d'|' -f2 || true)
  if grep -qx hdd <<<"$t"; then hw_info "Hay discos mecánicos (HDD): para ellos TRIM no aplica; considera BFQ como planificador de E/S"; fi

  if [ "$(hw_root_fs)" = btrfs ]; then
    t=$(hw_root_opts)
    grep -q compress <<<"$t" || hw_info "btrfs sin compresión transparente: añade compress=zstd:1 a las opciones de / en /etc/fstab (comprime solo lo que escribas desde entonces; ahorra espacio y suele acelerar SSD lentos)"
    grep -q noatime <<<"$t" || hw_info "btrfs sin noatime: cada lectura puede escribir metadatos; añade noatime a las opciones de / en /etc/fstab (menos desgaste del SSD)"
  fi

  # --- firmware y drivers que faltan ---
  t=$(hw_missing_firmware | tr '\n' ' ')
  if [ -n "$t" ]; then bad "El kernel no encontró firmware: ${t% }  (prueba sudo pacman -S linux-firmware; en Broadcom o NVIDIA puede ser otro paquete)"
  else ok "Sin firmware faltante en el log del kernel"; fi
  t=$(hw_pci_unbound | while IFS='|' read -r slot ven dev cls; do printf '%s [%s:%s] ' "$slot" "${ven#0x}" "${dev#0x}"; done)
  if [ -n "$t" ]; then bad "Dispositivos PCI sin driver: ${t% }  (consulta: lspci -nnk; puede faltar firmware o un paquete de driver)"
  else ok "Todos los dispositivos PCI relevantes tienen driver"; fi
  return 0
}

# Ajustes del sistema de los que dependen Wine/Proton/DXVK (lo propio de Wine está en «ink-wine status»)
hw_report_gaming() {
  local r icd mm nf pads jsn js
  r=$(_hw_root)
  hdr "Juegos"
  icd=$(ls "$r"/usr/share/vulkan/icd.d/*.json 2>/dev/null | sed 's|.*/||;s|_icd.*||;s|\.json||' | tr '\n' ' ' || true)
  if [ -n "$icd" ]; then ok "Vulkan: ${icd% }"
  else bad "Sin controlador Vulkan (ICD): DXVK/vkd3d abrirían ventanas en negro (vulkan-intel, vulkan-radeon o nvidia-utils)"; fi
  _hw_pkg xorg-xwayland && ok "XWayland instalado (Wine y apps X11 funcionan bajo Wayland)" \
    || bad "Falta xorg-xwayland: Wine y los juegos X11 no abrirán en labwc (sudo pacman -S xorg-xwayland)"
  mm=$(_hw_read "$(_hw_proc)/sys/vm/max_map_count")
  if [ -n "$mm" ]; then
    if [ "$mm" -ge 1048576 ] 2>/dev/null; then ok "vm.max_map_count = $mm (suficiente para Proton/Wine/Unity)"
    else bad "vm.max_map_count = $mm: algunos juegos se cierran al cargar; súbelo: echo 'vm.max_map_count = 1048576' | sudo tee /etc/sysctl.d/80-gaming.conf && sudo sysctl --system"; fi
  fi
  nf=$(awk '/^Max open files/ {print $5}' "$(_hw_proc)/self/limits" 2>/dev/null || true)
  if [ -n "$nf" ] && [ "$nf" != unlimited ]; then
    if [ "$nf" -ge 524288 ] 2>/dev/null; then ok "Límite de archivos abiertos: $nf (esync funciona)"
    else bad "Límite de archivos abiertos: $nf (esync pide ≥ 524288): añade DefaultLimitNOFILE=524288 en /etc/systemd/system.conf.d/ y reinicia"; fi
  fi
  # mandos: gamepad-awake los lee como /dev/input/js* (joydev); sin eso, jugando con mando se bloquearía la pantalla
  pads=$(hw_gamepads)
  if [ -n "$pads" ]; then
    jsn=$(ls "$r"/dev/input/js* 2>/dev/null || true)
    if [ -z "$jsn" ]; then
      bad "Hay un mando conectado pero no aparece como /dev/input/js*: gamepad-awake no lo verá y la pantalla se bloqueará jugando. Carga el módulo:  sudo modprobe joydev  (permanente: echo joydev | sudo tee /etc/modules-load.d/joydev.conf)"
    else
      for js in $jsn; do
        [ -r "$js" ] || bad "${js#"$r"} sin permiso de lectura: gamepad-awake no verá tu mando y la pantalla se bloqueará jugando. Instala game-devices-udev (6-wine.sh) y vuelve a conectar el mando"
      done
      ok "Mando detectado: $(cut -d'|' -f2 <<<"$pads" | head -n1)"
    fi
  else
    hw_info "Sin mando conectado ahora (gamepad-awake vigila y se activa solo al conectar uno)"
  fi
  if [ -e "$r/dev/ntsync" ]; then hw_info "ntsync activo (sincronización de Wine con el kernel)"
  else hw_info "ntsync no disponible ahora: Wine usa esync/fsync (con kernel ≥ 6.14: sudo modprobe ntsync)"; fi
  if grep -q zram "$(_hw_proc)/swaps" 2>/dev/null; then hw_info "zram activo (swap comprimido en RAM)"
  else hw_info "Sin zram: con poca RAM ayuda a que un juego pesado no congele el equipo (2-optimize.sh lo activa)"; fi
  return 0
}

# Vulnerabilidades de CPU (las que el kernel conoce), parches desactivados y permisos de la ESP. Solo lee.
hw_vulns() {   # una línea por vulnerabilidad: nombre|estado (según el kernel en ejecución)
  local f
  for f in "$(_hw_sys)"/devices/system/cpu/vulnerabilities/*; do
    [ -r "$f" ] || continue
    printf '%s|%s\n' "${f##*/}" "$(_hw_read "$f")"
  done
  return 0
}
hw_report_security() {
  local n=0 nbad=0 smt=0 name st cmd bl esp opts m last pkg
  hdr "Seguridad del hardware"
  while IFS='|' read -r name st; do
    [ -n "$name" ] || continue
    n=$((n + 1))
    case $st in
      "Not affected"*|Mitigation*)
        case $st in *"SMT vulnerable"*) smt=1 ;; esac ;;
      Vulnerable*)
        nbad=$((nbad + 1))
        case $st in
          *microcode*) pkg=$(hw_ucode_pkg)
                       bad "CPU $name: $st. Actualiza el microcódigo${pkg:+ ($pkg)} y reinicia: $(ucode_hint "$(detect_bootloader)" "${pkg:-ucode}")" ;;
          *)           bad "CPU $name: $st" ;;
        esac ;;
      *) hw_info "CPU $name: $st" ;;
    esac
  done < <(hw_vulns)
  if [ "$n" = 0 ]; then hw_info "El kernel no expone las vulnerabilidades de CPU (¿máquina virtual o kernel muy antiguo?)"
  elif [ "$nbad" = 0 ]; then ok "CPU: $n vulnerabilidades conocidas revisadas; todas mitigadas o no te afectan"; fi
  [ "$smt" = 1 ] && hw_info "SMT (hyper-threading) sigue activo con algunas vulnerabilidades que lo aprovechan en teoría: cerrarlo (nosmt) costaría 20-30 % de rendimiento; en uso doméstico se acepta"
  cmd=$(cat "$(_hw_proc)/cmdline" 2>/dev/null || true)
  if grep -qw 'mitigations=off' <<<"$cmd"; then
    bad "mitigations=off en la línea del kernel: ganas algo de rendimiento, pero un programa o una web maliciosa podría leer memoria de otros (Spectre/Meltdown). Quítalo de la configuración del gestor de arranque"
  fi
  # systemd-boot guarda ahí su semilla aleatoria: si la ESP es legible por todos, systemd lo avisa en «bootctl status»
  bl=$(detect_bootloader); esp=$(hw_esp)
  if [ "$bl" = systemd-boot ] && [ -n "$esp" ]; then
    opts=${INK_ESP_OPTS:-}
    [ -z "$opts" ] && _hw_have findmnt && opts=$(findmnt -no OPTIONS "$esp" 2>/dev/null || true)
    if [ -n "$opts" ]; then
      m=$(grep -oE 'fmask=[0-7]+' <<<"$opts" | tail -n1 | cut -d= -f2 || true)
      [ -n "$m" ] || m=$(grep -oE 'umask=[0-7]+' <<<"$opts" | tail -n1 | cut -d= -f2 || true)
      [ -n "$m" ] || m=0022
      last=${m: -1}
      if [ "$last" -lt 4 ] 2>/dev/null; then
        bad "La ESP ($esp) es legible por todos los usuarios (máscara $m): systemd-boot guarda ahí su semilla aleatoria. En /etc/fstab usa fmask=0137,dmask=0027 para esa partición"
      else ok "ESP con permisos privados (máscara $m)"; fi
    fi
  fi
  return 0
}
