# shellcheck shell=bash
# lib/common.sh — funciones compartidas (se carga con `source`; no se ejecuta solo).
# Se instala también en /usr/local/lib/ink/common.sh (junto a hwscan.sh) para que ink-doctor e ink-clean lo usen.

# Detección de hardware y de gestor de arranque (detect_bootloader, limine_conf, ucode_hint, hw_*): lib/hwscan.sh.
# Se carga desde aquí para que quien ya hace `source common.sh` (ink-doctor, 5-snapshots, 6-wine…) las tenga.
_ink_lib_dir=$(dirname "${BASH_SOURCE[0]}")
# shellcheck source=lib/hwscan.sh
[ -r "$_ink_lib_dir/hwscan.sh" ] && . "$_ink_lib_dir/hwscan.sh" || true

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

# keep_pkgs → paquetes intocables, uno por línea: los fijos + wine (wine-staging, wine-mono, wine-gecko…), winetricks,
# gamemode, gamescope, las reglas udev de mandos y los lib32-* (32 bits) instalados a propósito.
# Los usan 4-cleanup.sh e ink-clean para no quitarlos nunca (ni como huérfanos ni como dependencias).
keep_pkgs() {
  printf '%s\n' cups libcups noto-fonts-cjk yt-dlp
  pacman -Qqe 2>/dev/null | grep -E '^lib32-|^wine$|^wine-|^winetricks$|^gamemode$|^gamescope$|^game-devices-udev$|^steam-devices$' || true
}
