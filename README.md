# labwc — escritorio Wayland listo para usar

Un escritorio completo para **Arch Linux** basado en [labwc](https://labwc.github.io): ventanas con barra de título, barra superior, lanzador de aplicaciones, terminal, notificaciones, bloqueo de pantalla, capturas, grabación de pantalla y más. Se instala con un solo comando y ya viene configurado.

## Antes de empezar

- Necesitas **Arch Linux** (o derivado) ya instalado, con internet y un usuario con `sudo`.
- Ejecuta todo como usuario normal, **no como root**.

## Instalación

```bash
git clone https://github.com/wxz-78/labwc-ink
cd labwc-ink
./install.sh
```

El instalador te guía: instala los programas, copia la configuración y te pregunta por los pasos opcionales (entre ellos, si quieres **drivers de 32 bits**; ver más abajo). Al terminar, **reinicia** y entra con tu usuario.

> **Tu configuración actual no se pierde.** Lo que ya tengas se guarda en `~/.ink-backup-FECHA/` antes de reemplazarlo.
> Para ver qué haría sin cambiar nada: `./dotfiles.sh --dry-run`.

**El teclado.** `dotfiles.sh` te pregunta la distribución (por defecto español latinoamericano, `latam`). Si te equivocas o cambias de teclado, edita `~/.config/labwc/environment` y cambia `XKB_DEFAULT_LAYOUT` (por ejemplo `es`, `us`) y `XKB_DEFAULT_VARIANT` (la variante `deadtilde` es solo de `latam`; con otro teclado bórrala).

## Primeros pasos

Super es la tecla de Windows. También puedes hacer **clic derecho en el fondo** para abrir un menú con lo básico.

| Atajo | Qué hace |
|---|---|
| `Super + Enter` | Abrir la terminal |
| `Super + D` | Buscar y abrir aplicaciones |
| `Super + Espacio` | **Centro de control**: fondo, Wi-Fi, audio, capturas… todo en un menú |
| `Super + F1` | **Chuleta con todos los atajos** |
| `Super + Q` | Cerrar la ventana |
| `Super + Esc` | Apagar, reiniciar o cerrar sesión |

## Atajos

**Aplicaciones**

| Atajo | Acción |
|---|---|
| `Super + Enter` | Terminal |
| `Super + D` | Buscar aplicaciones |
| `Super + B` | Navegador (`Shift`: modo incógnito) |
| `Super + E` | Archivos |
| `Super + V` | Historial del portapapeles |
| `Ctrl + Shift + Esc` | Monitor del sistema |

**Ventanas y escritorios**

| Atajo | Acción |
|---|---|
| `Super + Q` | Cerrar |
| `Super + F` | Maximizar (`Shift`: pantalla completa) |
| `Super + M` | Minimizar |
| `Super + H / J / K / L` | Acomodar la ventana en la mitad izquierda / abajo / arriba / derecha |
| `Super + T` | Ventana siempre encima (otra vez para quitarlo) |
| `Super + Shift + ← / →` | Enviar la ventana a la pantalla de al lado (varios monitores) |
| `Alt + Tab` o `Super + Tab` | Cambiar de ventana |
| `Super + 1 … 4` | Ir al escritorio 1–4 (`Shift`: enviar la ventana ahí) |
| `Super + Ctrl + ←/→` | Escritorio anterior / siguiente (`Shift`: la ventana viaja contigo) |

Los botones de cerrar, minimizar y maximizar están en la barra de título de cada ventana.

**Capturas y grabación**

| Atajo | Acción |
|---|---|
| `Print` | Captura de toda la pantalla |
| `Shift + Print` | Captura de un área |
| `Ctrl + Print` | Captura de un área, copiada al portapapeles |
| `Super + Print` | Captura de un área para dibujar o anotar encima |
| `Super + Shift + P` | Grabar la pantalla (púlsalo otra vez para parar) |
| `Super + Ctrl + P` | Grabar solo un área |

Las capturas se guardan en tu carpeta de Imágenes.

**Sistema**

| Atajo | Acción |
|---|---|
| `Super + W` | Elegir fondo de pantalla (`Shift`: aleatorio · `Alt`: siguiente) |
| `Super + Z` | Luz nocturna (`Shift`: elegir intensidad) |
| `Super + A` | Elegir salida de audio (`Shift`: micrófono) |
| `Super + Y` | Conectarse a una red Wi-Fi |
| `Super + N` | No molestar (`Shift`: descartar notificaciones) |
| `Super + Ctrl + N` | Historial de notificaciones |
| `Super + U` | Actualizar el sistema |
| `Super + F2` | Revisar el estado y la seguridad del sistema |
| `Super + F3` | Configurar pantallas (resolución, escala, posición) |
| `Super + Shift + L` | Bloquear la pantalla |
| `Super + Shift + R` | Recargar la configuración |

Las teclas de volumen, brillo y reproducción funcionan también con la pantalla bloqueada.

## Cosas que quizá quieras hacer

**Cambiar el fondo de pantalla.** Al principio el fondo es negro liso: no se incluye ninguna imagen. Copia tus imágenes (jpg, png, webp) a `~/.local/share/backgrounds/` o a `Imágenes/Wallpapers/` y pulsa `Super + W`. Para que cambie solo cada 30 minutos: `wallpaper auto 30` (`wallpaper auto off` lo detiene).

**Configurar un monitor** (resolución, escala, posición). Pulsa `Super + F3` (o «Pantallas» en `Super + Espacio`): eliges la pantalla y la acción. Se guarda en `~/.config/ink/monitors` y se reaplica en cada inicio de sesión.

**Cambiar o añadir atajos.** Se editan en `~/.config/labwc/rc.xml` (etiquetas `<keybind>`). Después pulsa `Super + Shift + R`. La chuleta de `Super + F1` es una lista fija: si cambias un atajo, actualiza también el archivo `bin/keys`.

**Qué pasa con la pantalla cuando no haces nada:** a los 5 minutos se bloquea, a los 5:30 se apaga la pantalla y, solo si funcionas con batería, a los 15 minutos se suspende. Un PC de escritorio nunca se suspende solo.

## Pasos opcionales

`install.sh` te los ofrece, pero también puedes ejecutarlos por separado cuando quieras:

| Script | Para qué sirve |
|---|---|
| `./2-optimize.sh` | Mejora el uso de memoria, el disco y el arranque, y añade ahorro de batería si es un portátil. Acepta `--country MX` para usar los servidores de actualización de tu país. |
| `./3-privacy.sh` | DNS cifrado, dirección MAC distinta por red, firewall y endurecimiento del sistema. `./3-privacy.sh --revert` lo deshace. |
| `./4-cleanup.sh` | Quita programas que no se usan (herramientas de compilación que quedaron huérfanas, Qt5, pavucontrol y paquetes huérfanos) y limpia la caché. **No toca wine ni los paquetes `lib32-*`.** Con `--dry-run` solo muestra lo que haría. |
| `./5-snapshots.sh` | Copias de seguridad automáticas del sistema antes y después de cada actualización, y arranque desde ellas. **Solo si tu disco es btrfs.** Detecta tu gestor de arranque (**GRUB** o **Limine**; con otros crea los snapshots pero no salen en el menú). Con `--bootloader grub\|limine\|none` lo fuerzas. |
| `./6-wine.sh` | Instala **Wine Staging + winetricks** y prepara un prefijo para programas y juegos de Windows (ver *Wine* más abajo). Es idempotente: si se corta, vuélvelo a lanzar. |

## Qué se instala

El instalador detecta tu equipo y solo añade lo que necesitas (microcódigo Intel o AMD, controladores de vídeo, Bluetooth si tienes, ahorro de batería si es portátil).

| Función | Programa |
|---|---|
| Escritorio | labwc, waybar (barra), fuzzel (lanzador), mako (notificaciones), swaylock (bloqueo) |
| Terminal y archivos | foot, fish, yazi, Thunar |
| Navegador | Helium (se instala desde el AUR) |
| Medios | mpv (vídeo), imv (imágenes), zathura (PDF) |
| Audio y redes | PipeWire, wiremix, NetworkManager · compartir pantalla (portal wlr + slurp) |
| Inicio de sesión | greetd (con el llavero gnome-keyring desbloqueado automáticamente) |
| Archivos y discos | Thunar con miniaturas (tumbler), soporte exFAT, NTFS, FAT y móviles Android (MTP) |
| Fuentes | JetBrains Mono Nerd, Noto (texto y emoji), Liberation, DejaVu |
| Utilidades | rsync, wget, jq, poppler (vistas previas en yazi), ImageMagick, lsof, pciutils, usbutils |

### Drivers de 32 bits (opcional)

`1-install.sh` pregunta: *«¿Desea agregar drivers de 32 bits? (necesita activar multilib para que convivan 64 y 32 bits)»*. Por defecto es **no**. Si respondes que sí:

- Activa el repositorio **multilib** en `/etc/pacman.conf` (guarda una copia en `/etc/pacman.conf.ink-bak`). Es un repositorio extra: los 64 bits siguen igual y los paquetes de 32 bits (`lib32-*`) se instalan al lado.
- Instala `lib32-mesa` y el Vulkan de tu GPU (`lib32-vulkan-intel` o `lib32-vulkan-radeon`), más audio de 32 bits (`lib32-libpulse`, `lib32-alsa-plugins`, `lib32-pipewire`).
- **NVIDIA:** el driver se instala a mano; añade también `lib32-nvidia-utils` (misma versión que `nvidia-utils`). Si ya tenías `nvidia-utils`, se añade solo.
- Para no responder a mano: `INK_32BIT=1 ./1-install.sh` (sí) o `INK_32BIT=0 ./1-install.sh` (no). Con `install.sh --yes` la respuesta es «no» salvo que pongas `INK_32BIT=1`.

Sirve para Steam y juegos nativos de 32 bits (Steam no se instala aquí: solo sus drivers). **Wine no los necesita**: ver *Wine* más abajo. `./4-cleanup.sh` e `ink-clean` nunca quitan los paquetes `lib32-*` ni wine, y `ink-doctor` comprueba que multilib y los drivers estén en orden.

### Wine (opcional)

`./6-wine.sh` (o la pregunta final de `install.sh`) instala **wine-staging** y **winetricks** y usa el **prefijo por defecto de Wine (`~/.wine`)**, el mismo que usa `wine` a secas; si no existe lo crea y, si ya existe, solo completa lo que falte (nunca lo borra). Lo que hace y por qué:

- **Wine en Arch ya es «nuevo WoW64»**: ejecuta 32 y 64 bits en el mismo prefijo y **no necesita `lib32-*`** ni multilib. A cambio, ya no existen prefijos solo de 32 bits (`WINEARCH=win32` da error) ni se ejecutan programas de 16 bits.
- **wine-staging sustituye al paquete `wine`** (son excluyentes; los prefijos que ya tengas no se tocan). Si usas otro Wine (AUR, git…), no lo reemplaza. `ntsync` viene de serie.
- **Máxima compatibilidad: solo lo que no pisa a Wine.** Por defecto se instalan `vcrun2022`, `mfc42`, `msxml3`, `msxml6`, `vb6run` y `d3dx9/10/11` (archivos con versión en el nombre, que añaden y no sustituyen nada). **No** se instalan las DLL de Microsoft que reemplazan a las de Wine Staging, porque suelen dar ventanas en negro, mandos rotos, audio entrecortado o red sin SSL: `gdiplus`, `riched20`, `wininet`, `d3dcompiler_*`, `xinput`, `dinput8`, `xact`, `openal`, `directmusic`, `directplay`, `xna40`, `dxvk`, `vkd3d` y `dotnet48`. Para un programa concreto que las pida: `INK_WINE_LEGACY=1` (las antiguas), `INK_WINE_DXVK=1`, `INK_WINE_DOTNET=1` o `INK_WINE_EXTRA="verbo"`. `d3dx11` no existe como verbo (son `d3dx11_42` y `d3dx11_43`); `faudio` y `mono`/`gecko` tampoco hacen falta (Wine trae FAudio y los addons vienen como paquetes `wine-mono`/`wine-gecko`); **`win10` va al final**, porque varios verbos dejan el prefijo en Windows 7 al terminar.
- **Reparar un prefijo que ya tiene esas DLL:** `INK_WINE_FIX=1 ./6-wine.sh` quita del registro sus overrides nativos (no borra archivos) y Wine vuelve a usar las suyas. Haz antes una copia del prefijo.
- **Cada verbo se ejecuta por separado**, con un reintento y límite de tiempo: si uno falla, los demás siguen y al final hay un resumen. El registro queda en `~/.local/state/ink-wine/`.
- **DXVK y vkd3d son opcionales** (`INK_WINE_DXVK=1 ./6-wine.sh`, y solo con Vulkan funcionando): reemplazan las DLL de Direct3D del prefijo y, si el controlador Vulkan falla, la ventana se abre en negro y sin mensajes. Por defecto Wine usa su Direct3D propio.
- **Los errores se ven**: `ink-wine` y el registro de instalación solo ocultan los `fixme` (`INK_WINEDEBUG=err+all` para ver más), así que si un programa falla la terminal lo dice.
- **Wine no ensucia tu escritorio**: `winemenubuilder` queda desactivado (sin accesos en fuzzel) y si Wine cambia `~/.config/mimeapps.list`, se restaura.
- Variables: `INK_WINE_DOTNET=1` (con dotnet48, que tarda 10-30 min) · `INK_WINE_LEGACY=1` · `INK_WINE_FIX=1` · `INK_WINE_MEDIA=0` (sin códecs GStreamer/ffmpeg) · `INK_WINE_EXTRA="corefonts"` · `INK_WINE_SKIP="vkd3d"` · `INK_WINE_DXVK=1` · `INK_WINEPREFIX=ruta`.

Para ejecutar: `ink-wine programa.exe` (también `.msi` y `.bat`; arranca desde la carpeta del programa y con un entorno afinado). `ink-wine cfg`, `ink-wine tricks <verbo>`, `ink-wine builtin`, `ink-wine kill` e `ink-wine info` completan el manejo; `ink-doctor` revisa Wine, ntsync y Vulkan. Con `INK_GAMEMODE=1` usa `gamemoderun` si lo tienes. Los juegos muy antiguos (DirectX 7 o anteriores) no los cubre DXVK: prueba dgVoodoo2 o `gamescope` antes de tocar este prefijo.

**Si una ventana sale en negro o no pasa nada:**

1. Ejecuta el programa desde la terminal con `ink-wine programa.exe` y lee los errores (`INK_WINEDEBUG=err+all,warn+module` da más detalle).
2. `ink-wine info` muestra los *overrides* de Direct3D del prefijo. Si ves `d3d11=native` o `dxgi=native`, hay DLL de DXVK/vkd3d.
3. Prueba sin ellas, sin tocar nada: `INK_WINE_BUILTIN=1 ink-wine programa.exe`. Si así funciona, el culpable es DXVK/vkd3d o tu controlador Vulkan (`ink-doctor`). Para dejarlo así de forma permanente: `ink-wine builtin` (quita los overrides del prefijo; no borra archivos).
4. Si falla incluso así, prueba un prefijo nuevo y vacío para descartar que el tuyo esté dañado: `WINEPREFIX=/tmp/prueba wineboot` y luego `INK_WINEPREFIX=/tmp/prueba ink-wine programa.exe`.

Si quieres LibreOffice: `OFFICE=1 ./1-install.sh`. Para no instalar ImageMagick: `IMAGEMAGICK=0 ./1-install.sh`. Si tienes una tarjeta NVIDIA, el instalador te avisará: el controlador se instala a mano porque depende de tu kernel.

## Herramientas incluidas

Son comandos que puedes escribir en la terminal; casi todos están también en el centro de control (`Super + Espacio`).

| Comando | Qué hace |
|---|---|
| `ink-menu` | Abre el centro de control |
| `ink-update` | Muestra las últimas noticias de Arch y actualiza el sistema |
| `ink-doctor` | Revisa el sistema sin modificar nada: servicios, disco, actualizaciones de seguridad, firewall… |
| `wallpaper` | Gestiona el fondo (`pick`, `random`, `next`, `auto`, `status`) |
| `nightlight` | Luz nocturna (`toggle`, `menu`) |
| `shot` / `rec` | Capturas y grabación de pantalla |
| `audio-switch` · `wifi-menu` | Elegir audio y redes Wi-Fi |
| `ink-clean` | Limpieza de mantenimiento: paquetes huérfanos, cachés de pacman y AUR, registros, miniaturas y (con `--trash`) papelera. Pide confirmación en cada paso; `--dry-run` solo muestra lo que limpiaría. Está también en el centro de control (`Super + Espacio`). |
| `battery-watch` | Avisa cuando la batería baja del 15 % y del 7 % (se lanza solo; en un PC de escritorio no hace nada) |

## Gestor de arranque (GRUB, Limine…)

El instalador **detecta** cuál usas y te dice qué falta para cargar el microcódigo de tu CPU:

| Gestor | Microcódigo | Snapshots en el menú (`5-snapshots.sh`) |
|---|---|---|
| GRUB | `sudo grub-mkconfig -o /boot/grub/grub.cfg` lo detecta solo | `grub-btrfs` + `grub-btrfsd`; el script regenera el menú |
| Limine | línea `module_path: boot():/amd-ucode.img` (o `intel-ucode.img`) antes del initramfs en `limine.conf` | `limine-snapper-sync` + `limine-mkinitcpio-hook` (AUR). Después ejecuta `sudo limine-mkinitcpio` y `sudo limine-snapper-sync` una vez |
| systemd-boot / rEFInd | `initrd` de ucode antes del initramfs | solo se crean los snapshots; restaura desde un USB |

Si la detección falla, fuérzala: `INK_BOOTLOADER=limine ./1-install.sh` o `./5-snapshots.sh --bootloader limine`. `Super + F2` (`ink-doctor`) comprueba que todo esté enlazado.

> **Con Limine, los snapshots ocupan la ESP:** se copia un kernel por entrada. Usa una ESP de 1 GiB o más y ajusta el número de entradas en `/etc/limine-snapper-sync.conf`.

## Solución de problemas

**No arranca el escritorio.** Desde un TTY (`Ctrl + Alt + F2`) ejecuta `labwc` y lee el mensaje de error.

**Los bordes inferiores de las ventanas no son redondos.** labwc solo redondea las esquinas superiores; las inferiores las dibuja cada aplicación.

**Los snapshots no salen en el menú de arranque.** Ejecuta `ink-doctor` (`Super + F2`): la sección «Copias» dice qué servicio falta. En GRUB hace falta regenerar el menú tras instalar `grub-btrfs` (el script ya lo hace); en Limine, los dos comandos de la tabla de arriba.

**El navegador pide la contraseña del llavero.** El desbloqueo automático solo funciona si la contraseña del llavero «login» es la de tu usuario. Si ya existía con otra, bórrala con `rm ~/.local/share/keyrings/login.keyring` (pierdes lo guardado en él) y vuelve a entrar.

**Al elegir una red Wi-Fi se abre el lanzador de aplicaciones en vez de pedir la contraseña.** Era un fallo de `wifi-menu` (usaba `--prompt-only` de fuzzel sin `--dmenu`); está corregido. Si una red falla por contraseña incorrecta, se avisa y se vuelve a pedir la clave. El detalle de cada intento queda en `~/.cache/ink/wifi.log`.

**La pantalla no se apaga sola.** Hace falta el programa `wlopm`, que viene del AUR; sin él solo se bloquea y suspende.

**No hay sonido en un portátil Intel reciente.** Instala `sof-firmware` (el instalador ya lo hace en CPUs Intel).

**Un atajo no hace nada.** Pulsa `Super + Shift + R` para recargar y revisa que no esté repetido en `rc.xml`.

**Quiero ver cómo está mi sistema.** Pulsa `Super + F2`.

## Volver atrás

- **Tu configuración anterior:** está en `~/.ink-backup-FECHA/`; copia de vuelta lo que quieras.
- **Entradas ocultas del lanzador:** el instalador oculta algunas aplicaciones que no sirven de nada en el menú. Para recuperar una, borra su archivo en `~/.local/share/applications/`.
- **Privacidad:** `./3-privacy.sh --revert`.

## Notas

- `./check.sh` valida el repositorio sin instalar nada ni tocar tu sesión. Úsalo antes de hacer commit; GitHub Actions también lo ejecuta en cada push, en Ubuntu y en un contenedor de Arch (`.github/workflows/check.yml`). Comprueba:
  - sintaxis de todos los scripts (y `shellcheck` y `fish --no-execute` si están instalados), XML de `rc.xml`/`menu.xml`, JSONC de waybar y fastfetch;
  - sin saltos de línea CRLF, con shebang, y permisos de ejecución en `bin/`, en los `.sh` y en `autostart`;
  - atajos duplicados en `rc.xml`, que la chuleta `bin/keys` coincida con `rc.xml` y que ningún script de `bin/` quede sin usar;
  - que cada programa que usan las configs (foot, waybar, grim, wl-copy…) lo instale `1-install.sh`;
  - que `6-wine.sh` no instale por defecto DLL nativas conflictivas ni oculte los errores de Wine;
  - una instalación real de `dotfiles.sh` en un HOME temporal: copia todo, conserva los permisos y es idempotente (con `INK_NO_RELOAD=1`, que evita reiniciar tu waybar o recargar tu labwc).
- Los scripts principales (`install.sh`, `1-install.sh`…`6-wine.sh`, `dotfiles.sh`) aceptan `--help` para ver su uso sin tocar nada.
- Probado en sintaxis (shell, XML y JSON) pero no en todos los equipos: si algo falla en el tuyo, el mensaje de `labwc` desde un TTY suele indicar la línea exacta.
