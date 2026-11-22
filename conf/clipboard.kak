## Modular Cross-Platform Clipboard
#
# Mirrors Kakoune's `windowing_modules` pattern: tries each module in
# `clipboard_modules` in order on KakBegin and activates the first one that
# matches the current environment. Set `clipboard_modules` to an empty list
# to disable auto-detection and load a module manually via `require-module`.

try %{
    declare-option -docstring 'Ordered list of clipboard modules to try on startup' \
        str-list clipboard_modules \
            'clipboard-wsl' \
            'clipboard-macos' \
            'clipboard-wayland' \
            'clipboard-x11' \
            'clipboard-kitty'
}

try %{
    declare-option -docstring 'Active clipboard module loaded by auto-detection' \
        str clipboard_module ''
}

define-command -override -hidden -params 1..2 clipboard-register %{
    evaluate-commands %sh{
        if [ -n "$1" ]; then
            printf "map -docstring 'Yank to system clipboard' global user y %%{<a-|>%s<ret>}\n" "$1"
        fi
        if [ $# -ge 2 ] && [ -n "$2" ]; then
            printf "map -docstring 'Paste after from system clipboard' global user v %%{<a-!>%s<ret>}\n" "$2"
            printf "map -docstring 'Paste before from system clipboard' global user V %%{!%s<ret>}\n" "$2"
            printf "map -docstring 'Replace selection from system clipboard' global user R %%{|%s<ret>}\n" "$2"
        fi
    }
}

source "%val{config}/conf/clipboard/wsl.kak"
source "%val{config}/conf/clipboard/macos.kak"
source "%val{config}/conf/clipboard/wayland.kak"
source "%val{config}/conf/clipboard/x11.kak"
source "%val{config}/conf/clipboard/kitty.kak"

remove-hooks global clipboard-detection

hook -group clipboard-detection global KakBegin .* %{
    evaluate-commands %sh{
        eval "set -- $kak_quoted_opt_clipboard_modules"
        [ $# -eq 0 ] && exit 0

        n=$#
        for mod in "$@"; do
            esc=$(printf '%s' "$mod" | sed "s/'/''/g")
            printf "try %%{ require-module '%s'; set-option global clipboard_module '%s' } catch %%{\n" "$esc" "$esc"
        done
        printf "echo -debug 'no clipboard module detected'\n"
        i=0
        while [ "$i" -lt "$n" ]; do
            printf '}\n'
            i=$((i + 1))
        done
    }
}
