#!/usr/bin/env bash
# 4-cleanup.sh — limpieza de paquetes: quita lo que no se usa y encoge la caché de pacman.
#   sudo ./4-cleanup.sh [--dry-run] [--yes]
#
# QUITA:   el toolchain de compilación que quedó huérfano (clang, llvm, rust, cmake, intltool), Qt5 (ya no hay
#          ninguna app Qt5), pavucontrol (lo sustituye wiremix) y todos los paquetes huérfanos (instalados como
#          dependencia que ya nadie usa). Solo quita lo que ningún otro paquete necesita.
# NO TOCA: wine/winetricks y los paquetes lib32-* (drivers de 32 bits): si los usas, siguen intactos.
#          Tampoco cups/libcups (impresión), noto-fonts-cjk (CJK) ni yt-dlp. Si alguno está instalado
#          solo «como dependencia» y la limpieza lo arrastraría, se marca como explícito antes de quitar nada.
# Es idempotente: si ya está limpio, no hace nada.
set -euo pipefail
case "${1:-}" in
    -h|--help) sed -n '2,/^set /{/^set /!p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
[[ $EUID -eq 0 ]] || exec sudo bash "$0" "$@"

DRY=0
ASSUME=0
for a in "$@"; do
    case "$a" in
        --dry-run) DRY=1 ;;
        --yes|-y)  ASSUME=1 ;;
        -h|--help) sed -n '2,/^set /{/^set /!p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "uso: $0 [--dry-run] [--yes]" >&2; exit 1 ;;
    esac
done

ok()   { printf '\e[32m[ok]\e[0m %s\n' "$*"; }
note() { printf '\e[2m     \e[0m%s\n' "$*"; }
warn() { printf '\e[33m[!]\e[0m %s\n' "$*"; }

# Paquetes que se pueden quitar (si están instalados).
REMOVE=(clang llvm llvm-lit rust cmake intltool qt5-base qt5-translations qt5-x11extras pavucontrol)

command -v pacman >/dev/null || { echo "Este script es para Arch (pacman)." >&2; exit 1; }

# Paquetes intocables (no se quitan nunca): lista compartida con ink-clean (lib/common.sh)
source "$(dirname "$(readlink -f "$0")")/lib/common.sh"
mapfile -t KEEP < <(keep_pkgs)

# Lo intocable que hay instalado ahora: es lo que se comprueba al final (no avisar por lo que nunca estuvo)
kept=()
for p in "${KEEP[@]}"; do
    pacman -Qq "$p" &>/dev/null && kept+=("$p")
done

# --- 1. De la lista, solo los que estén instalados ---
targets=()
for p in "${REMOVE[@]}"; do
    pacman -Qq "$p" &>/dev/null && targets+=("$p")
done

if (( ${#targets[@]} == 0 )); then
    ok "No hay nada que quitar: la lista ya estaba limpia."
else
    note "Paquetes instalados en la lista: ${targets[*]}"

    # --- 2. Preflight: si algo fuera de la lista los necesita, se conserva ---
    skip=()
    for p in "${targets[@]}"; do
        # Con LC_ALL=C el campo siempre es "Required By"; "None" = sin dependientes
        deps=$(LC_ALL=C pacman -Qi "$p" 2>/dev/null | sed -n 's/^Required By *: *//p' \
               | tr -s ' ' '\n' | grep -vE '^$|^None$' || true)
        for d in $deps; do
            if ! printf '%s\n' "${REMOVE[@]}" | grep -qx "$d"; then
                warn "$p hace falta para '$d' (no está en la lista): se conserva."
                skip+=("$p")
                break
            fi
        done
    done
    if (( ${#skip[@]} > 0 )); then
        filtered=()
        for p in "${targets[@]}"; do
            if ! printf '%s\n' "${skip[@]}" | grep -qx "$p"; then filtered+=("$p"); fi
        done
        targets=("${filtered[@]}")
    fi

    if (( ${#targets[@]} == 0 )); then
        warn "Nada seguro que quitar (todo hace falta para otra cosa)."
    else
        note "Se quitan: ${targets[*]}"

        # `pacman -Rns` arrastra también las dependencias que nadie más necesita. Si una de ellas es de KEEP
        # (p. ej. cups, que otro paquete pudo traer como dependencia), caería con él: se marca como explícita antes.
        dep_installed=$(pacman -Qqd 2>/dev/null || true)
        at_risk=$(pacman -Rns --print --print-format '%n' "${targets[@]}" 2>/dev/null \
                  | grep -xF -f <(printf '%s\n' "${KEEP[@]}") || true)
        for k in $at_risk; do
            grep -qxF "$k" <<<"$dep_installed" || continue
            if (( DRY )); then
                warn "$k caería como dependencia (sale en la lista de abajo): en la ejecución real se marca como explícito y se salva."
            else
                pacman -D --asexplicit "$k" >/dev/null && note "$k marcado como explícito: queda protegido."
            fi
        done

        if (( ! DRY )); then
            note "Con sus dependencias sin uso se quitarían: $(pacman -Rns --print --print-format '%n' "${targets[@]}" 2>/dev/null | tr '\n' ' ')"
        fi
        if (( DRY )); then
            warn "SIMULACIÓN: no se toca nada."
            pacman -Rns --print "${targets[@]}" | sed 's/^/     /' || warn "pacman no pudo calcular la operación."
        elif (( ASSUME )); then
            pacman -Rns --noconfirm "${targets[@]}"
            ok "Paquetes eliminados."
        else
            printf '     ¿Continuar? [s/N] '
            read -r r
            [[ $r == [sSyY] ]] || { warn "Cancelado."; exit 0; }
            pacman -Rns --noconfirm "${targets[@]}"
            ok "Paquetes eliminados."
        fi
    fi
fi

# --- 2b. Huérfanos: paquetes instalados como dependencia que ya nadie necesita ---
# Lo intocable (KEEP) que figure como huérfano se marca como explícito para que no caiga.
orphans=()
while IFS= read -r p; do [[ -n $p ]] && orphans+=("$p"); done < <(pacman -Qdtq 2>/dev/null || true)
safe=()
for p in "${orphans[@]}"; do
    if printf '%s\n' "${KEEP[@]}" | grep -qx "$p"; then
        (( DRY )) || pacman -D --asexplicit "$p" >/dev/null
        note "$p era huérfano pero está protegido: se conserva."
    else
        safe+=("$p")
    fi
done
if (( ${#safe[@]} == 0 )); then
    ok "No hay paquetes huérfanos."
else
    note "Huérfanos: ${safe[*]}"
    if (( DRY )); then
        warn "SIMULACIÓN: no se toca nada."
    else
        if (( ASSUME )); then r=s; else printf '     ¿Quitar los huérfanos? [s/N] '; read -r r; fi
        if [[ $r == [sSyY] ]]; then
            pacman -Rns --noconfirm "${safe[@]}" && ok "Huérfanos eliminados."
        else
            warn "Huérfanos conservados."
        fi
    fi
fi

# --- 3. Caché de pacman: deja 2 versiones de cada paquete (paccache -rk2) ---
# Ojo: -rk2 conserva las 2 últimas versiones; si la caché solo tiene 2 por
# paquete (caso normal) no borra nada. Con -rk1 se libera la mitad.
if command -v paccache >/dev/null; then
    # `du` puede fallar (sin permisos en algunos subdirectorios): con pipefail
    # eso abortaría el script, así que se ignora su código de salida.
    cache_size() {
        local s
        s=$(du -sh /var/cache/pacman/pkg 2>/dev/null | head -1 | cut -f1) || true
        printf '%s' "${s:-?}"
    }
    before=$(cache_size)
    if (( DRY )); then
        # paccache sólo admite una operación: -d (simulación) o -r (borrar)
        paccache -dk2 2>&1 | sed 's/^/     /' || warn "paccache no pudo listar candidatos."
        note "Caché de pacman ahora: ${before}"
    else
        paccache -rk2 || warn "paccache falló; la caché no se ha limpiado."
        after=$(cache_size)
        ok "Caché de pacman: ${before} -> ${after}"
    fi
else
    warn "paccache no está instalado (pacman-contrib): la caché no se toca."
fi

# --- 4. Comprobación de seguridad: lo que no se debía tocar sigue ahí ---
missing=()
for p in "${kept[@]}"; do
    pacman -Qq "$p" &>/dev/null || missing+=("$p")
done
if (( ${#missing[@]} > 0 )); then
    warn "ATENCIÓN: ya no están instalados: ${missing[*]}"
elif (( ${#kept[@]} > 0 )); then
    ok "Intactos: ${kept[*]}"
fi
