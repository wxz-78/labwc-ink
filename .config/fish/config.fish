# Ink — fish. Prompt de dos líneas: ruta y rama; ● (acento) si el último comando salió bien, ○ y su código si falló.
# Respeta lo que ya tengas definido (p. ej. EDITOR=helix antes de abrir la terminal).
set -q EDITOR;  or set -gx EDITOR nvim
set -q VISUAL;  or set -gx VISUAL nvim
set -q BROWSER; or set -gx BROWSER helium-browser
fish_add_path -m "$HOME/.local/bin"

status is-interactive; or return
set -g fish_greeting

# Colores: grises + el acento del escritorio (ink-theme)
set -g fish_color_normal e4e4e4
set -g fish_color_command ffffff --bold
set -g fish_color_keyword fdfdfd
set -g fish_color_param c8c8c8
set -g fish_color_option c8c8c8
set -g fish_color_quote 9a9a9a
set -g fish_color_redirection 9a9a9a
set -g fish_color_end 6e6e6e
set -g fish_color_operator 9a9a9a
set -g fish_color_escape 9a9a9a
set -g fish_color_comment 5c5c5c
set -g fish_color_error fdfdfd --underline
set -g fish_color_autosuggestion 6e6e6e
set -g fish_color_valid_path --underline
set -g fish_pager_color_prefix fdfdfd --bold
set -g fish_pager_color_completion c8c8c8
set -g fish_pager_color_description 6e6e6e
set -g fish_pager_color_selected_background --background=3a3a3a

# fzf: tarjeta redonda en grises
set -gx FZF_DEFAULT_OPTS '--height=40% --layout=reverse --border=rounded --info=inline --prompt="● " --pointer="▶" --color=fg:#c8c8c8,bg:-1,hl:#fdfdfd,fg+:#ffffff,bg+:#1e1e1e,hl+:#fdfdfd,info:#6e6e6e,prompt:#fdfdfd,pointer:#fdfdfd,marker:#fdfdfd,spinner:#6e6e6e,header:#6e6e6e,border:#3a3a3a'
command -q fd; and set -gx FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
# man con colores de bat (ANSI → grises)
command -q bat; and set -gx MANPAGER "sh -c 'col -bx | bat -l man -p --theme=ansi'"

function __ink_branch   # una sola llamada a git: rama + estado sucio
    set -l out (git status --porcelain=v2 --branch 2>/dev/null); or return
    set -l b (string replace -rf '^# branch\.head (.+)$' '$1' -- $out)
    if test "$b" = '(detached)'
        set b (string sub -l 7 -- (string replace -rf '^# branch\.oid (.+)$' '$1' -- $out))
    end
    set -l dirty ''
    string match -rq '^[^#]' -- $out; and set dirty ' ✱'
    printf ' %s%s%s%s' (set_color 8a8a8a) $b $dirty (set_color normal)
end

# Comandos lentos: el prompt muestra cuánto tardó el último (≥ 5 s) y, si pasó de 30 s, avisa con una notificación
# (así puedes cambiar de ventana mientras compila o descarga). No avisa para editores, pagers ni shells interactivas.
set -g __ink_slow_ignore nvim vim vi hx nano less man bat htop btop yazi y ssh fzf lazygit tmux zellij mpv
function __ink_postexec --on-event fish_postexec
    set -g __ink_dur $CMD_DURATION
    test "$CMD_DURATION" -ge 30000; or return
    set -l cmd (string split -m1 ' ' -- $argv[1])[1]
    contains -- $cmd $__ink_slow_ignore; and return
    command -q notify-send; and notify-send -u low -a fish "󰄬  Terminó ($(math -s0 $CMD_DURATION / 1000) s)" (string sub -l 80 -- $argv[1])
end
function __ink_duration   # «1m 05s» si el último comando tardó ≥ 5 s; nada en otro caso
    set -q __ink_dur; or return
    test "$__ink_dur" -ge 5000; or return
    set -l s (math -s0 $__ink_dur / 1000)
    if test $s -ge 60; printf ' %s%dm %02ds%s' (set_color 6e6e6e) (math -s0 $s / 60) (math $s % 60) (set_color normal)
    else; printf ' %s%ds%s' (set_color 6e6e6e) $s (set_color normal); end
end
# Entorno virtual de Python activo: se muestra su nombre (útil para no instalar paquetes en el sitio equivocado)
function __ink_venv
    set -q VIRTUAL_ENV; or return
    printf ' %s(%s)%s' (set_color 6e6e6e) (path basename $VIRTUAL_ENV) (set_color normal)
end

function fish_prompt
    set -l last $status
    set -q SSH_CONNECTION; and echo -n -s (set_color 8a8a8a) $USER@(prompt_hostname) ' '
    echo -s (set_color --bold ffffff) (prompt_pwd --dir-length=0) (set_color normal) (__ink_branch) (__ink_venv) (__ink_duration)
    # ● en el acento si el último comando salió bien; ○ blanco + código de salida si falló
    if test $last -eq 0
        echo -n -s (set_color fdfdfd) '● ' (set_color normal)
    else
        echo -n -s (set_color ffffff) '○ ' (set_color 6e6e6e) $last ' ' (set_color normal)
    end
end
function fish_right_prompt; end

if command -q eza
    alias ls 'eza --group-directories-first --icons=auto'
    alias ll 'eza -lh --group-directories-first --icons=auto'
    alias la 'eza -lah --group-directories-first --icons=auto'
end
command -q bat; and alias cat 'bat --paging=never --theme=ansi'
if command -q paru; alias update 'paru -Syu'; else if command -q yay; alias update 'yay -Syu'; else; alias update 'sudo pacman -Syu'; end   # repos + AUR
alias grep 'grep --color=auto'
abbr -a g git
abbr -a gs 'git status -sb'
abbr -a gl 'git log --oneline --graph -15'
abbr -a gd 'git diff'

# Comando que no existe: sugiere qué paquete lo trae (pacman -F; la base se crea con `sudo pacman -Fy`, sin ella solo avisa)
function fish_command_not_found
    echo "fish: «$argv[1]» no existe." >&2
    command -q pacman; or return 127
    set -l hits (pacman -F -q -- "usr/bin/$argv[1]" 2>/dev/null)
    test -n "$hits"; and echo "     lo trae: $hits[1]  →  sudo pacman -S $hits[1]" >&2
    return 127
end

command -q zoxide; and zoxide init fish | source
command -q fzf; and fzf --fish | source

function y   # yazi: al salir, cd al directorio donde te quedaste
    set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
    yazi $argv --cwd-file="$tmp"
    if set -l cwd (command cat -- "$tmp"); and test -n "$cwd"; and test "$cwd" != "$PWD"
        cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

# `if` y no `; and`: en shells anidadas (SHLVL > 1) la condición falla y el primer prompt saldría con ○
if test "$SHLVL" -le 1; and command -q fastfetch
    fastfetch
end
