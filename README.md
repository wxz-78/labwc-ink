# labwc — escritorio Wayland listo para usar

Un escritorio completo para **Arch Linux** basado en [labwc](https://labwc.github.io): ventanas con barra de título, barra superior, lanzador de aplicaciones, terminal, notificaciones, bloqueo de pantalla, capturas, grabación de pantalla y más. Se instala con un solo comando y ya viene configurado.

## Antes de empezar

- Necesitas **Arch Linux** (o derivado) ya instalado, con internet y un usuario con `sudo`. Pensado para Arch y probado en **CachyOS**; no sirve fuera del ecosistema pacman.
- Ejecuta todo como usuario normal, **no como root**.

## Instalación

```bash
git clone https://github.com/wxz-78/labwc-ink
cd labwc-ink
./install.sh
```

El instalador te guía: instala los programas, copia la configuración y te pregunta por los pasos opcionales (entre ellos, si quieres **drivers de 32 bits**; ver más abajo). Al terminar, **reinicia** y entra con tu usuario.

> **Tu configuración actual no se pierde.** Lo que ya tengas se guarda en `~/.ink-backup-FECHA/` antes de reemplazarlo.
> Para ver qué haría sin cambiar nada: `./dotfiles.sh --dry-run`. Para volver atrás: `./dotfiles.sh --restore` devuelve lo que se respaldó en la última carpeta `~/.ink-backup-*` (y respalda de nuevo lo que había, así nada se pierde); puedes indicar otra carpeta: `./dotfiles.sh --restore ~/.ink-backup-FECHA`.

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
| `Super + C` | **Color de acento** de todo el escritorio (`Shift`: sacarlo del fondo de pantalla) |
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

**Cambiar el color de acento.** El escritorio es tinta negra y grises con **un solo acento** (por defecto blanco: todo sigue en blanco y negro): el borde de la ventana enfocada, el botón de sesión de la barra, el escritorio actual, el ● del prompt, el cursor del terminal, las coincidencias del buscador, las notificaciones urgentes, el anillo del bloqueo y el degradado de btop. Pulsa `Super + C` para elegir uno (cinabrio, jade, índigo, ámbar, glicina o tinta, que es el blanco por defecto) o `Super + Shift + C` para que lo saque de tu fondo de pantalla. También vale `ink-theme '#ff8800'` con cualquier color. La barra, las notificaciones y labwc cambian al instante; el terminal, fish y las apps GTK, la próxima vez que los abras. Si reinstalas los dotfiles, tu acento se reaplica solo.

**Configurar un monitor** (resolución, escala, rotación, posición). Pulsa `Super + F3` (o «Pantallas» en `Super + Espacio`): eliges la pantalla y la acción. Se guarda en `~/.config/ink/monitors` y se reaplica en cada inicio de sesión.

**Cambiar o añadir atajos.** Se editan en `~/.config/labwc/rc.xml` (etiquetas `<keybind>`). Después pulsa `Super + Shift + R`. La chuleta de `Super + F1` es una lista fija: si cambias un atajo, actualiza también el archivo `bin/keys`.

**Qué pasa con la pantalla cuando no haces nada:** a los 5 minutos se bloquea, a los 5:30 se apaga la pantalla y, solo si funcionas con batería, a los 15 minutos se suspende, salvo que suene audio, haya una sesión SSH activa o algún programa bloquee la suspensión. Un PC de escritorio nunca se suspende solo. **Jugando con mando no se bloquea nada:** mientras pulses botones o muevas los sticks (el drift se ignora), `gamepad-awake` mantiene despierta la pantalla; si dejas el mando quieto, vuelve el reposo normal. Con batería: avisos al 15 % y 7 % (con el tiempo restante estimado) y suspensión automática al 3 %.

**Terminal inteligente (fish).** El prompt muestra cuánto tardó el último comando si pasó de 5 s y el entorno virtual de Python activo; si un comando tarda más de 30 s, avisa con una notificación al terminar. Si escribes un comando que no existe, sugiere el paquete que lo trae (necesita `sudo pacman -Fy` una vez).

## Pasos opcionales

`install.sh` te los ofrece, pero también puedes ejecutarlos por separado cuando quieras:

| Script | Para qué sirve |
|---|---|
| `./2-optimize.sh` | Mejora el uso de memoria, el disco y el arranque, y añade ahorro de batería si es un portátil. Acepta `--country MX` para usar los servidores de actualización de tu país. Activa **fwupd** (avisa de firmware nuevo; solo descarga la lista, nunca instala solo: tú aplicas con `fwupdmgr update`). En portátiles también deja explícito qué hacen la **tapa** (cerrar suspende; con monitor externo no hace nada) y el **botón de encendido** (un toque suspende, mantenerlo apaga) en `/etc/systemd/logind.conf.d/10-ink.conf`; bórralo para volver a lo de fábrica. Además ajusta el **planificador de E/S** por tipo de disco (NVMe sin cola extra, SSD `mq-deadline`, HDD `bfq`; `/etc/udev/rules.d/60-ink-ioschedulers.rules`), limita el caché de escritura (`vm.dirty_bytes`: copiar a un USB lento ya no congela el equipo), sube `vm.max_map_count` solo si tu valor es menor de 1048576 (juegos con Wine/Proton) y acorta a 10 s la parada de los servicios de tu sesión. |
| `./3-privacy.sh` | DNS cifrado, dirección MAC distinta por red en Wi-Fi (Ethernet no se toca), firewall (si tienes SSH activo, su puerto se permite antes de cerrar lo entrante) y endurecimiento del sistema (parámetros del kernel, sin volcados de memoria y bloqueo de módulos que un escritorio no usa: protocolos y sistemas de archivos obsoletos, FireWire; nunca los de discos externos como UDF o HFS+). `./3-privacy.sh --revert` lo deshace. |
| `./4-cleanup.sh` | Quita programas que no se usan (herramientas de compilación que quedaron como dependencia, Qt5, pavucontrol y paquetes huérfanos) y limpia la caché. **No toca wine ni los paquetes `lib32-*`, ni compiladores o cmake que instalaste tú a propósito.** Con `--dry-run` solo muestra lo que haría. |
| `./5-snapshots.sh` | Copias de seguridad automáticas del sistema antes y después de cada actualización, y arranque desde ellas. **Solo si tu disco es btrfs.** Detecta tu gestor de arranque (**GRUB** o **Limine**; con otros crea los snapshots pero no salen en el menú). Con `--bootloader grub\|limine\|none` lo fuerzas. |
| `./6-wine.sh` | Instala **Wine Staging + winetricks** y prepara un prefijo para programas y juegos de Windows (ver *Wine* más abajo). Es idempotente: si se corta, vuélvelo a lanzar. |

## Qué se instala

El instalador **escanea tu equipo** (`lib/hwscan.sh`) y solo añade lo que necesitas: microcódigo Intel o AMD (no en máquinas virtuales), controladores de vídeo de **todas** tus GPU (también en gráficas híbridas), `sof-firmware` si tu audio lo necesita, Bluetooth si hay adaptador, y ahorro de batería si es portátil (por la batería **o** por el tipo de chasis que declara la BIOS). Al empezar muestra un resumen y al terminar comprueba que el microcódigo realmente se vaya a cargar.

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
- **Compatibilidad máxima, con DXVK para los FPS.** Por defecto se instalan `vcrun2022`, `mfc42`, `msxml3`, `msxml6`, `vb6run` y `d3dx9/10/11` (archivos con versión en el nombre, que añaden y no sustituyen nada). **No** se instalan las DLL de Microsoft que reemplazan a las de Wine Staging, porque suelen dar ventanas en negro, mandos rotos, audio entrecortado o red sin SSL: `gdiplus`, `riched20`, `wininet`, `d3dcompiler_*`, `xinput`, `dinput8`, `xact`, `openal`, `directmusic`, `directplay`, `xna40` y `dotnet48` (DXVK y vkd3d sí van, ver el punto siguiente). Para un programa concreto que las pida: `INK_WINE_LEGACY=1` (las antiguas), `INK_WINE_DOTNET=1` o `INK_WINE_EXTRA="verbo"`. `d3dx11` no existe como verbo (son `d3dx11_42` y `d3dx11_43`); `faudio` y `mono`/`gecko` tampoco hacen falta (Wine trae FAudio y los addons vienen como paquetes `wine-mono`/`wine-gecko`); **`win10` va al final**, porque varios verbos dejan el prefijo en Windows 7 al terminar.
- **Mandos: se reparan solos.** Si un prefijo antiguo tiene `dinput8`/`xinput` nativos instalados por winetricks, `./6-wine.sh` quita esos overrides (sin borrar archivos) e `ink-wine` fuerza la DLL integrada en cada ejecución: `joy.cpl` vuelve a ver el mando aunque Linux ya lo detectara. `ink-wine pad` repara el prefijo y abre el Panel de control → Mandos (`ink-wine pad check` solo diagnostica). Para conservar DLL nativas de entrada a propósito: `INK_WINE_INPUT_FIX=0` en el script o `INK_WINE_NATIVE_INPUT=1` en `ink-wine`.
- **Reparar un prefijo que ya tiene otras DLL conflictivas:** `INK_WINE_FIX=1 ./6-wine.sh` quita del registro sus overrides nativos (no borra archivos ni toca los de DXVK) y Wine vuelve a usar las suyas. Haz antes una copia del prefijo.
- **Cada verbo se ejecuta por separado**, con un reintento y límite de tiempo: si uno falla, los demás siguen y al final hay un resumen. El registro queda en `~/.local/state/ink-wine/`.
- **DXVK y vkd3d-proton vienen activados** (Direct3D 8-11 y 12 sobre Vulkan: es lo que da el rendimiento en juegos). Solo se instalan si hay un controlador Vulkan (`vulkan-intel`, `vulkan-radeon` o `nvidia-utils`); sin él se omiten con un aviso, porque la ventana se abriría en negro y sin mensajes. Para un prefijo que ya tenías sin ellos: `ink-wine dxvk` (o relanzar `./6-wine.sh`). Para no instalarlos: `INK_WINE_DXVK=0 ./6-wine.sh` (`INK_WINE_VKD3D=0` deja solo DXVK). `ink-doctor` avisa si el prefijo no los tiene.
- **Los errores se ven**: `ink-wine` y el registro de instalación solo ocultan los `fixme` (`INK_WINEDEBUG=err+all` para ver más), así que si un programa falla la terminal lo dice.
- **Mandos y juegos** (sección «Mandos y juegos» de `6-wine.sh`): instala `game-devices-udev` y, si no está en tus repositorios (es de AUR), `steam-devices` como alternativa (reglas udev para que tu usuario use mandos PS4/PS5, Xbox, Switch… sin root; recarga udev y, si el mando no aparece, basta con desconectarlo y volver a conectarlo). También comprueba que los mandos detectados por el kernel sean legibles por tu usuario. Si aceptas, instala `gamemode` y `gamescope`. Te añade al grupo `gamemode` (cuenta tras cerrar sesión y volver a entrar). `INK_WINE_PAD=0` omite las reglas; `INK_WINE_GAMING=1|0` responde a la pregunta de gamemode/gamescope sin preguntar. Si un paquete no está en tus repositorios, avisa y sigue. `4-cleanup.sh` e `ink-clean` no los quitan.
- **Si el ratón se escapa en un juego a pantalla completa** (de menos a más invasivo): `ink-wine grab on` fuerza la captura del ratón en ventanas a pantalla completa (`off` la quita) · `ink-wine desktop 1920x1080` mete todo en un escritorio virtual de Wine (`off` lo quita; solo para una ejecución: `INK_WINE_DESKTOP=1920x1080 ink-wine juego.exe`) · `INK_GAMESCOPE=1 ink-wine juego.exe` lo ejecuta dentro de gamescope, que captura el ratón y escala por ti (argumentos con `INK_GAMESCOPE_ARGS`, por defecto `-f`; p. ej. `"-W 2560 -H 1440 -w 1920 -h 1080 -f"`). Con `INK_GAMEMODE=1` se combina con gamemode. `ink-doctor` muestra qué tienes instalado.
- **Ajustes del prefijo** (`INK_WINE_TWEAKS=0` los omite): sin el diálogo de `winedbg` al caerse un programa (en Wayland se queda colgado) y fuentes con suavizado ClearType, para que el texto se vea nítido. Del lado del escritorio, labwc mantiene **XWayland persistente** (Wine arranca sin esperar), la bandeja de Wine no aparece en Alt-Tab y `DISPLAY` llega a los servicios D-Bus/systemd de usuario; `ink-doctor` comprueba que `Xwayland` esté instalado.
- **Wine no ensucia tu escritorio**: `winemenubuilder` queda desactivado (sin accesos en fuzzel) y si Wine cambia `~/.config/mimeapps.list`, se restaura.
- Variables: `INK_WINE_DXVK=0` (sin DXVK/vkd3d) · `INK_WINE_DOTNET=1` (con dotnet48, que tarda 10-30 min) · `INK_WINE_LEGACY=1` · `INK_WINE_INPUT_FIX=0` (no reparar dinput/xinput) · `INK_WINE_FIX=1` · `INK_WINE_MEDIA=0` (sin códecs GStreamer/ffmpeg) · `INK_WINE_EXTRA="corefonts"` · `INK_WINE_SKIP="vkd3d"` · `INK_WINE_DXVK=1` · `INK_WINEPREFIX=ruta`. En `ink-wine`: `INK_WINE_NATIVE_INPUT=1` conserva los overrides nativos de entrada.

Para ejecutar: `ink-wine programa.exe` (también `.msi` y `.bat`; arranca desde la carpeta del programa y con un entorno afinado). `ink-wine cfg`, `ink-wine tricks <verbo>`, `ink-wine dxvk` (instala/actualiza DXVK y vkd3d), `ink-wine builtin`, `ink-wine kill` e `ink-wine info` completan el manejo; `ink-wine tweaks` aplica los ajustes del prefijo a uno que ya tenías (p. ej. creado antes de esta versión), `ink-wine new NOMBRE` crea un prefijo limpio aparte (para aislar un programa o descartar que el principal esté dañado), `ink-wine pad` repara y muestra los mandos (abre `joy.cpl`), `ink-wine dpi 144` agranda la interfaz de Windows en pantallas grandes y `ink-wine dark` / `ink-wine light` ponen la paleta oscura a juego con el escritorio (solo afecta a los controles clásicos; si un programa queda ilegible, `ink-wine light`); `ink-doctor` revisa Wine, ntsync y Vulkan. Con `INK_GAMEMODE=1` usa `gamemoderun` si lo tienes. Los juegos muy antiguos (DirectX 7 o anteriores) no los cubre DXVK: prueba dgVoodoo2 o `gamescope` antes de tocar este prefijo.

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
| `ink-doctor` | Revisa el sistema sin modificar nada: servicios, disco, hora, sesión (barra, notificaciones, audio, llavero, portal de pantalla), firmware (fwupd), seguridad, arranque y hardware (lo mismo que `ink-hw`) y, en portátiles, TLP y salud de la batería. |
| `ink-hw` | Escaneo a fondo del hardware y del arranque (solo lee): UEFI o BIOS, Secure Boot, ESP y su espacio libre, **gestor de arranque en uso**, microcódigo, GPU, Wi-Fi, Bluetooth, audio, discos y firmware que falta. Con `sudo ink-hw` también lee `/boot` y la ESP si son privados; `ink-hw --env` da líneas `CLAVE=VALOR` para scripts. Está en el centro de control (`Super + Espacio`). |
| `wallpaper` | Gestiona el fondo (`pick`, `random`, `next`, `auto`, `status`) |
| `ink-theme` | Color de acento del escritorio (`menu`, `list`, `wall`, un nombre o `#RRGGBB`) |
| `nightlight` | Luz nocturna (`toggle`, `menu`) |
| `shot` / `rec` | Capturas y grabación de pantalla |
| `audio-switch` · `wifi-menu` | Elegir audio y redes Wi-Fi |
| `ink-clean` | Limpieza de mantenimiento: paquetes huérfanos, cachés de pacman y AUR, registros, miniaturas y (con `--trash`) papelera. Pide confirmación en cada paso; `--dry-run` solo muestra lo que limpiaría. Está también en el centro de control (`Super + Espacio`). |
| `battery-watch` | Avisa cuando la batería baja del 15 % y del 7 % (se lanza solo; en un PC de escritorio no hace nada) |

## Gestor de arranque (GRUB, Limine…)

El escaneo **identifica el gestor que arrancó este equipo**, no el que tiene el paquete instalado. Mira la ruta de la entrada UEFI (`\EFI\arch\grubx64.efi` es GRUB aunque la entrada se llame «Arch»), inspecciona por dentro el binario de la ruta genérica `\EFI\BOOT\BOOTX64.EFI` y, si hace falta, recurre a los archivos y paquetes. Reconoce GRUB, Limine, systemd-boot, rEFInd, Syslinux, UKI y EFISTUB, avisa si quedan rastros de otro gestor y, con `ink-hw`, comprueba:

- modo **UEFI o BIOS**, **Secure Boot** y que la **ESP** esté montada y con espacio libre (menos de 100 MiB avisa);
- que exista la configuración del gestor y, con GRUB, que haya kernels en `/boot`;
- el generador de initramfs (mkinitcpio o dracut), los kernels instalados y, con DKMS, que no falten sus *headers*;
- el **microcódigo**: `activo` (el kernel confirma que lo aplicó), `configurado` (hook `microcode` de mkinitcpio, dracut o una línea `initrd`/`module_path`), o `falta` (instalado pero nada lo carga, con el arreglo exacto para tu gestor);
- si hay un Windows en la misma máquina (arranque dual).

| Gestor | Microcódigo | Snapshots en el menú (`5-snapshots.sh`) |
|---|---|---|
| GRUB | `sudo grub-mkconfig -o /boot/grub/grub.cfg` lo detecta solo (o el hook `microcode` de mkinitcpio) | `grub-btrfs` + `grub-btrfsd`; el script regenera el menú |
| Limine | lo más simple: hook `microcode` en `HOOKS` de `/etc/mkinitcpio.conf` y `sudo mkinitcpio -P` (o línea `module_path: boot():/amd-ucode.img` antes del initramfs) | `limine-snapper-sync` + `limine-mkinitcpio-hook` (AUR). Después ejecuta `sudo limine-mkinitcpio` y `sudo limine-snapper-sync` una vez |
| systemd-boot / rEFInd / UKI | hook `microcode`, o `initrd` de ucode antes del initramfs | solo se crean los snapshots; restaura desde un USB |

Si la detección falla, fuérzala: `INK_BOOTLOADER=limine ./1-install.sh` o `./5-snapshots.sh --bootloader limine`. `Super + F2` (`ink-doctor`) y `ink-hw` repiten la comprobación cuando quieras.

## Hardware: qué revisa el escaneo

- **GPU**: lee los dispositivos PCI de vídeo (aunque aún no tengan driver), detecta gráficas híbridas e indica cuál es la principal. En **NVIDIA** clasifica la generación y dice qué paquete toca: Turing o posterior → `nvidia-open` (`-lts`/`-dkms` según tu kernel); Maxwell, Pascal y Volta → rama legacy del AUR `nvidia-580xx-dkms` (el driver 590 de Arch ya no los soporta); más antiguas → nouveau o el AUR. La clasificación va por rango de ID PCI y es orientativa: confírmala en la wiki de Arch («NVIDIA»). El driver NVIDIA no se instala solo; avisa si falta `nvidia_drm.modeset`, que Wayland necesita.
- **Red y radios**: interfaces Wi-Fi y su driver, bloqueos `rfkill` y adaptadores Bluetooth USB sin controlador.
- **Audio**: `sof-firmware` solo cuando hace falta de verdad (controlador SOF, o audio Intel/AMD con DSP y ninguna tarjeta de sonido registrada). Un Intel con HDA clásico, como un Skylake, suena sin él y no se instala.
- **Discos**: NVMe, SSD, HDD, USB y MMC.
- **Firmware que falta**: lo que el kernel no pudo cargar en este arranque y los dispositivos PCI sin driver.
- **Portátil**: soporte de límite de carga de la batería y perfiles de energía.
- **Máquinas virtuales**: se detectan; no se instala microcódigo ni se activa TLP.
- **Juegos** (sección aparte de `ink-hw`): hay controlador Vulkan, XWayland instalado, `vm.max_map_count` ≥ 1048576 y límite de archivos abiertos ≥ 524288 (los dos que hacen cerrarse a Proton/Wine/Unity y a esync), más ntsync y zram como información. Lo propio de Wine sigue en `ink-wine status`.
- **Seguridad del hardware** (también solo lectura): revisa las vulnerabilidades de CPU que conoce el kernel (si alguna falta de microcódigo, te dice cómo arreglarlo), avisa si tienes `mitigations=off` en la línea del kernel y, con systemd-boot, si la ESP es legible por todos. En btrfs sugiere `compress=zstd:1` y `noatime`. `ink-doctor` añade que pacman no tenga firmas desactivadas y que `~/.ssh` y `~/.gnupg` sean privados.
- **Caché de shaders** de Mesa de 4 GiB (`MESA_SHADER_CACHE_MAX_SIZE` en `.config/labwc/environment`): menos tirones al volver a jugar con varios juegos instalados.

`ink-doctor` incluye todo esto en modo breve (solo ✔ y avisos) y remite a `ink-hw` para el detalle: cada herramienta hace una cosa.

> **Con Limine, los snapshots ocupan la ESP:** se copia un kernel por entrada. Usa una ESP de 1 GiB o más y ajusta el número de entradas en `/etc/limine-snapper-sync.conf`.

## Solución de problemas

**No arranca el escritorio.** Desde un TTY (`Ctrl + Alt + F2`) ejecuta `labwc` y lee el mensaje de error.

**Los bordes inferiores de las ventanas no son redondos.** labwc solo redondea las esquinas superiores; las inferiores las dibuja cada aplicación.

**Los snapshots no salen en el menú de arranque.** Ejecuta `ink-doctor` (`Super + F2`): la sección «Copias» dice qué servicio falta. En GRUB hace falta regenerar el menú tras instalar `grub-btrfs` (el script ya lo hace); en Limine, los dos comandos de la tabla de arriba.

**El navegador pide la contraseña del llavero.** El desbloqueo automático solo funciona si la contraseña del llavero «login» es la de tu usuario. Si ya existía con otra, bórrala con `rm ~/.local/share/keyrings/login.keyring` (pierdes lo guardado en él) y vuelve a entrar.

**Al elegir una red Wi-Fi se abre el lanzador de aplicaciones en vez de pedir la contraseña.** Era un fallo de `wifi-menu` (usaba `--prompt-only` de fuzzel sin `--dmenu`); está corregido. Si una red falla por contraseña incorrecta, se avisa y se vuelve a pedir la clave. El detalle de cada intento queda en `~/.cache/ink/wifi.log`.

**Linux detecta el mando pero Wine no lo ve (`wine control joy.cpl` sale vacío).** Casi siempre es un override `*dinput8=native` que dejó winetricks al instalar `dinput8`/`directx9`: esa DLL nativa suele estar rota y `joy.cpl`, que se apoya en `dinput8.dll`, ni siquiera abre (en la consola sale `import_dll ... dinput8.dll ... not found`). `./6-wine.sh` quita ese override automáticamente e `ink-wine` usa siempre el `dinput8` integrado de Wine, que sí detecta el mando por HID. Para reparar un prefijo que ya tenías, sin reinstallar nada: `ink-wine pad` (repara, lista los mandos detectados y abre el Panel de control → Mandos); `ink-wine pad check` solo diagnostica. Si necesitas conservar una DLL nativa de entrada para un juego muy antiguo: `INK_WINE_NATIVE_INPUT=1 ink-wine juego.exe`. Para ver la enumeración con trazas: `WINEPREFIX="$HOME/.wine" WINEDEBUG=+dinput wine control joy.cpl` debe mostrar `assign_joystick_ids` con tu mando.

**Se me bloquea la pantalla jugando con mando.** `gamepad-awake` (lo lanza el autostart) necesita `wlrctl` y permiso de lectura sobre el mando (reglas udev de `./6-wine.sh`; si el mando se conectó antes, desconéctalo y vuelve a conectarlo). `gamepad-awake` lee el mando como `/dev/input/js*` (módulo `joydev`, que el kernel carga solo al conectarlo; si no aparece: `sudo modprobe joydev`). `ink-hw` avisa si hay un mando sin `js*` o sin permiso de lectura. Compruébalo con `ink-doctor` o ejecuta `gamepad-awake --debug` en una terminal y mueve el mando: debe mostrar la actividad. Si Steam Input acapara el mando, el programa no verá sus botones; en ese caso usa el botón «café» de la barra para mantener la pantalla encendida.

**La pantalla no se apaga sola.** Hace falta el programa `wlopm`, que viene del AUR; sin él solo se bloquea y suspende. `wlrctl` (también AUR si no está en los repos) lo usa `gamepad-awake`.

**No hay sonido en un portátil Intel o AMD reciente.** Instala `sof-firmware` (el instalador solo lo añade cuando detecta que hace falta: controlador SOF o audio con DSP sin ninguna tarjeta de sonido registrada; `ink-hw` te avisa si falta).

**Waybar, mako u otro programa del inicio no aparece.** Mira `~/.cache/ink/autostart.log`: guarda los errores de lo que lanza `autostart` (se reinicia en cada sesión).

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
  - que `6-wine.sh` no instale por defecto DLL nativas conflictivas ni oculte los errores de Wine, que sigan los ajustes del prefijo y XWayland persistente, y `ink-wine` (dark/light/dpi/new/grab/desktop/gamescope) con un `wine` y un `gamescope` simulados;
  - una instalación real de `dotfiles.sh` en un HOME temporal: copia todo, conserva los permisos y es idempotente (con `INK_NO_RELOAD=1`, que evita reiniciar tu waybar o recargar tu labwc), y que `--restore` devuelve lo respaldado;
  - guardias contra regresiones (TLP sin `powersupersave`, firewall que permite SSH, sin MAC aleatoria en Ethernet, fwupd y logind presentes) y `4-cleanup.sh --dry-run` con un `pacman` simulado (solo como root, p. ej. en el contenedor de Arch del CI).
- Los scripts principales (`install.sh`, `1-install.sh`…`6-wine.sh`, `dotfiles.sh`) aceptan `--help` para ver su uso sin tocar nada.
- Probado en sintaxis (shell, XML y JSON) pero no en todos los equipos: si algo falla en el tuyo, el mensaje de `labwc` desde un TTY suele indicar la línea exacta.
