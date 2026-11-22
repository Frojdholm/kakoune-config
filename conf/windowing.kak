## Terminal-Native Windowing
#
# Uses Kakoune's built-in `windowing_modules` detection on KakBegin so only the
# matching terminal module is loaded (no tmux or other multiplexers):
#   - Windows (WSL 2): custom `windows-terminal` module (wt.exe)
#   - Linux / macOS:   built-in `kitty` module extended with splits and overlay popups

source "%val{config}/conf/windowing/windows-terminal.kak"
source "%val{config}/conf/windowing/kitty.kak"

set-option global windowing_modules 'windows-terminal' 'kitty'

## Terminal-Agnostic Split & Layout Helpers

define-command -override -params .. -command-completion \
    -docstring 'split-vertical [<commands>]: open a new Kakoune client in a vertical (side-by-side) split' \
    split-vertical %{
    terminal-vertical kak -c %val{session} -e "%arg{@}"
}

define-command -override -params .. -command-completion \
    -docstring 'split-horizontal [<commands>]: open a new Kakoune client in a horizontal (stacked) split' \
    split-horizontal %{
    terminal-horizontal kak -c %val{session} -e "%arg{@}"
}

define-command -override -params .. -command-completion \
    -docstring 'new-tab [<commands>]: open a new Kakoune client in a new terminal tab' \
    new-tab %{
    terminal-tab kak -c %val{session} -e "%arg{@}"
}

define-command -override -hidden -params 3 client-open-path %{
    evaluate-commands %sh{
        term_cmd=$1
        kak_cmd=$2
        esc_path=$(printf '%s' "$3" | sed "s/'/''/g")
        inner_cmd="$kak_cmd -- '$esc_path'"
        esc_inner=$(printf '%s' "$inner_cmd" | sed "s/'/''/g")
        printf "%s kak -c %%val{session} -e '%s'\n" "$term_cmd" "$esc_inner"
    }
}

define-command -override -params 1 -file-completion \
    -docstring 'edit-vertical <file>: open a file in a new vertical (side-by-side) split' \
    edit-vertical %{
    client-open-path terminal-vertical edit %arg{1}
}

define-command -override -params 1 -file-completion \
    -docstring 'edit-horizontal <file>: open a file in a new horizontal (stacked) split' \
    edit-horizontal %{
    client-open-path terminal-horizontal edit %arg{1}
}

define-command -override -params 1 -file-completion \
    -docstring 'edit-tab <file>: open a file in a new terminal tab' \
    edit-tab %{
    client-open-path terminal-tab edit %arg{1}
}

define-command -override -docstring 'Open a shell in a vertical (side-by-side) split' \
    shell-vertical %{
    evaluate-commands %sh{
        esc=$(printf '%s' "${SHELL:-/bin/sh}" | sed "s/'/''/g")
        printf "terminal-vertical '%s'\n" "$esc"
    }
}

define-command -override -docstring 'Open a shell in a horizontal (stacked) split' \
    shell-horizontal %{
    evaluate-commands %sh{
        esc=$(printf '%s' "${SHELL:-/bin/sh}" | sed "s/'/''/g")
        printf "terminal-horizontal '%s'\n" "$esc"
    }
}

define-command -override -docstring 'Set up IDE layout with main (jump) and tools/docs clients' ide %{
    rename-client main
    set-option global jumpclient main

    split-vertical rename-client tools
    set-option global toolsclient tools
    set-option global docsclient tools
}
