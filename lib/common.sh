# shellcheck shell=bash
# lib/common.sh — funciones compartidas (se carga con `source`; no se ejecuta solo).
# Se instala también en /usr/local/lib/ink/common.sh para que ink-doctor lo use.

# detect_bootloader → imprime: limine | grub | systemd-boot | refind | unknown
# Orden: INK_BOOTLOADER (forzado a mano) → entrada UEFI con la que arrancó el equipo → paquetes y archivos instalados.
detect_bootloader() {
  local cur="" f
  if [ -n "${INK_BOOTLOADER:-}" ]; then echo "$INK_BOOTLOADER"; return; fi
  # 1) la entrada UEFI que arrancó esta sesión (BootCurrent): la más fiable si hay varios gestores instalados
  if command -v efibootmgr >/dev/null 2>&1; then
    cur=$(efibootmgr 2>/dev/null | awk '/^BootCurrent:/ {c = $2} c != "" && $1 == "Boot" c "*" {print tolower($0); exit}')
    case $cur in
      *limine*)                       echo limine; return ;;
      *grub*)                         echo grub; return ;;
      *refind*)                       echo refind; return ;;
      *"linux boot manager"*|*systemd*) echo systemd-boot; return ;;
    esac
  fi
  # 2) respaldo: paquete + configuración presentes (BIOS o UEFI sin entrada reconocible)
  if pacman -Qq limine &>/dev/null; then
    f=$(find /boot /efi -maxdepth 4 \( -name limine.conf -o -name limine.cfg \) 2>/dev/null | head -n1)
    [ -n "$f" ] && { echo limine; return; }
  fi
  if pacman -Qq grub &>/dev/null && [ -e /boot/grub/grub.cfg ]; then echo grub; return; fi
  if command -v bootctl >/dev/null 2>&1 && bootctl is-installed &>/dev/null; then echo systemd-boot; return; fi
  if pacman -Qq refind &>/dev/null; then echo refind; return; fi
  echo unknown
}

# limine_conf → ruta del limine.conf en uso (vacío si no se encuentra)
limine_conf() {
  find /boot /efi -maxdepth 4 \( -name limine.conf -o -name limine.cfg \) 2>/dev/null | head -n1
}

# ucode_hint BOOTLOADER PAQUETE-UCODE → texto con lo que falta hacer para cargar el microcódigo
ucode_hint() {
  local bl=$1 img=$2
  case $bl in
    grub)         echo "sudo grub-mkconfig -o /boot/grub/grub.cfg   (detecta ${img}.img solo)" ;;
    limine)       echo "en tu limine.conf, ANTES de la línea del initramfs:  module_path: boot():/${img}.img   (ruta relativa a tu partición de arranque; si usas limine-mkinitcpio-hook revisa /etc/default/limine)" ;;
    systemd-boot) echo "en tu entrada de /boot/loader/entries/*.conf, ANTES de la línea del initramfs:  initrd /${img}.img" ;;
    refind)       echo "en refind_linux.conf añade  initrd=/${img}.img  antes del initramfs, o usa mkrlconf" ;;
    *)            echo "añade ${img}.img como primer initrd en tu gestor de arranque (wiki de Arch: Microcode)" ;;
  esac
}

# aur_helper → imprime paru o yay si existe y arranca de verdad (paru-bin roto tras actualizar pacman no cuenta)
aur_helper() {
  local h
  for h in paru yay; do
    if command -v "$h" >/dev/null 2>&1 && "$h" --version >/dev/null 2>&1; then echo "$h"; return 0; fi
  done
  return 1
}

# confirm "pregunta" s|n → 0 si la respuesta es sí. INK_YES=1 acepta el valor por defecto sin preguntar.
confirm() {
  local def=${2:-s} hint="[S/n]" r
  [ "$def" = n ] && hint="[s/N]"
  if [ "${INK_YES:-0}" = 1 ]; then [ "$def" = s ]; return; fi
  read -rp "$1 $hint " r
  r=${r:-$def}
  [[ $r =~ ^[sSyY]$ ]]
}

# keep_pkgs → paquetes intocables, uno por línea: los fijos + wine (wine-staging, wine-mono, wine-gecko…), winetricks
# y los lib32-* (32 bits) instalados a propósito.
# Los usan 4-cleanup.sh e ink-clean para no quitarlos nunca (ni como huérfanos ni como dependencias).
keep_pkgs() {
  printf '%s\n' cups libcups noto-fonts-cjk yt-dlp
  pacman -Qqe 2>/dev/null | grep -E '^lib32-|^wine$|^wine-|^winetricks$' || true
}
