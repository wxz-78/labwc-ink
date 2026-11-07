# labwc — escritorio Wayland listo para usar

Un escritorio completo para **Arch Linux** basado en [labwc](https://labwc.github.io): ventanas con barra de título, barra superior, lanzador de aplicaciones, terminal, notificaciones, bloqueo de pantalla, capturas, grabación de pantalla y más. Se instala con un solo comando y ya viene configurado.

## Antes de empezar

- Necesitas **Arch Linux** (o derivado) ya instalado, con internet y un usuario con `sudo`.
- Ejecuta todo como usuario normal, **no como root**.

## Instalación

```bash
git clone <URL-de-este-repositorio>
cd labwc-ink
./install.sh
```

El instalador te guía: instala los programas, copia la configuración y te pregunta por los pasos opcionales. Al terminar, **reinicia** y entra con tu usuario.

> **Tu configuración actual no se pierde.** Lo que ya tengas se guarda en `~/.ink-backup-FECHA/` antes de reemplazarlo.
> Para ver qué haría sin cambiar nada: `./dotfiles.sh --dry-run`.

**Antes de reiniciar, revisa el teclado.** Está en español latinoamericano. Si el tuyo es otro, edita `~/.config/labwc/environment` y cambia `XKB_DEFAULT_LAYOUT=latam` (por ejemplo `es`, `us`) y `XKB_DEFAULT_VARIANT`.

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
| `Alt + Tab` o `Super + Tab` | Cambiar de ventana |
| `Super + 1 … 4` | Ir al escritorio 1–4 (`Shift`: enviar la ventana ahí) |

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
| `Super + Shift + L` | Bloquear la pantalla |
| `Super + Shift + R` | Recargar la configuración |

Las teclas de volumen, brillo y reproducción funcionan también con la pantalla bloqueada.

## Cosas que quizá quieras hacer

**Cambiar el fondo de pantalla.** Copia tus imágenes (jpg, png, webp) a `~/.local/share/backgrounds/` o a `Imágenes/Wallpapers/` y pulsa `Super + W`. Para que cambie solo cada 30 minutos: `wallpaper auto 30` (`wallpaper auto off` lo detiene).

**Configurar un monitor** (resolución, escala, posición). Ejecuta `wlr-randr` para ver los nombres de tus pantallas y descomenta y ajusta las líneas de ejemplo de `~/.config/labwc/autostart`.

**Cambiar o añadir atajos.** Se editan en `~/.config/labwc/rc.xml` (etiquetas `<keybind>`). Después pulsa `Super + Shift + R`. La chuleta de `Super + F1` es una lista fija: si cambias un atajo, actualiza también el archivo `bin/keys`.

**Qué pasa con la pantalla cuando no haces nada:** a los 5 minutos se bloquea, a los 5:30 se apaga la pantalla y, solo si funcionas con batería, a los 15 minutos se suspende. Un PC de escritorio nunca se suspende solo.

## Pasos opcionales

`install.sh` te los ofrece, pero también puedes ejecutarlos por separado cuando quieras:

| Script | Para qué sirve |
|---|---|
| `./2-optimize.sh` | Mejora el uso de memoria, el disco y el arranque, y añade ahorro de batería si es un portátil. Acepta `--country MX` para usar los servidores de actualización de tu país. |
| `./3-privacy.sh` | DNS cifrado, dirección MAC distinta por red, firewall y endurecimiento del sistema. `./3-privacy.sh --revert` lo deshace. |
| `./4-cleanup.sh` | Quita programas que no se usan (wine, herramientas de compilación, paquetes huérfanos) y limpia la caché. Con `--dry-run` solo muestra lo que haría. |
| `./5-snapshots.sh` | Copias de seguridad automáticas del sistema antes y después de cada actualización. **Solo si tu disco es btrfs.** |

## Qué se instala

El instalador detecta tu equipo y solo añade lo que necesitas (microcódigo Intel o AMD, controladores de vídeo, Bluetooth si tienes, ahorro de batería si es portátil).

| Función | Programa |
|---|---|
| Escritorio | labwc, waybar (barra), fuzzel (lanzador), mako (notificaciones), swaylock (bloqueo) |
| Terminal y archivos | foot, fish, yazi, Thunar |
| Navegador | Helium (se instala desde el AUR) |
| Medios | mpv (vídeo), imv (imágenes), zathura (PDF) |
| Audio y redes | PipeWire, wiremix, NetworkManager |
| Inicio de sesión | greetd |

Si quieres LibreOffice: `OFFICE=1 ./1-install.sh`. Si tienes una tarjeta NVIDIA, el instalador te avisará: el controlador se instala a mano porque depende de tu kernel.

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

## Solución de problemas

**No arranca el escritorio.** Desde un TTY (`Ctrl + Alt + F2`) ejecuta `labwc` y lee el mensaje de error.

**Los bordes inferiores de las ventanas no son redondos.** labwc solo redondea las esquinas superiores; las inferiores las dibuja cada aplicación.

**La pantalla no se apaga sola.** Hace falta el programa `wlopm`, que viene del AUR; sin él solo se bloquea y suspende.

**No hay sonido en un portátil Intel reciente.** Instala `sof-firmware` (el instalador ya lo hace en CPUs Intel).

**Un atajo no hace nada.** Pulsa `Super + Shift + R` para recargar y revisa que no esté repetido en `rc.xml`.

**Quiero ver cómo está mi sistema.** Pulsa `Super + F2`.

## Volver atrás

- **Tu configuración anterior:** está en `~/.ink-backup-FECHA/`; copia de vuelta lo que quieras.
- **Entradas ocultas del lanzador:** el instalador oculta algunas aplicaciones que no sirven de nada en el menú. Para recuperar una, borra su archivo en `~/.local/share/applications/`.
- **Privacidad:** `./3-privacy.sh --revert`.

## Notas

- Probado en sintaxis (shell, XML y JSON) pero no en todos los equipos: si algo falla en el tuyo, el mensaje de `labwc` desde un TTY suele indicar la línea exacta.
- Regenerar el fondo incluido: `python3 tools/gen-wallpaper.py ~/.local/share/backgrounds/fondo.png` (requiere python-pillow, numpy, scipy y opencv).
