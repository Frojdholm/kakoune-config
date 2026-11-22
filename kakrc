## Important: setup tree sitter first
# eval %sh{ kak-tree-sitter -dks --init $kak_session }

colorscheme catppuccin_mocha

## Cross-Platform Terminal Abstraction (WSL 2 / Ghostty / tmux)

define-command -hidden -params 1.. cross-terminal %{
    nop %sh{
        script=$(mktemp "${TMPDIR:-/tmp}/kak-term.XXXXXX")
        esc_pwd=$(printf '%s' "$PWD" | sed "s/'/'\\\\''/g")
        {
            printf '#!/bin/sh\n'
            printf "rm -f '%s'\n" "$script"
            printf "cd '%s' || exit 1\n" "$esc_pwd"
            printf 'exec'
            for arg in "$@"; do
                esc_arg=$(printf '%s' "$arg" | sed "s/'/'\\\\''/g")
                printf " '%s'" "$esc_arg"
            done
            printf '\n'
        } > "$script"
        chmod +x "$script"

        if [ -n "$WSL_DISTRO_NAME" ] && command -v wt.exe >/dev/null 2>&1; then
            # Windows Terminal native split inside the current window
            wt.exe -w 0 split-pane wsl.exe -d "$WSL_DISTRO_NAME" -- "$script" >/dev/null 2>&1 &
        elif [ -n "$kak_client_env_TMUX" ]; then
            TMUX="$kak_client_env_TMUX" tmux split-window -h "$script"
        elif command -v ghostty >/dev/null 2>&1; then
            ghostty -e "$script" >/dev/null 2>&1 &
        elif [ -x "/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
            /Applications/Ghostty.app/Contents/MacOS/ghostty -e "$script" >/dev/null 2>&1 &
        else
            xterm -e "$script" >/dev/null 2>&1 &
        fi
    }
}

# Override after Kakoune's built-in windowing auto-detection runs
hook global KakBegin .* %{
    alias global terminal cross-terminal
}

## Commands

define-command ide %{
    rename-client main
    set-option global jumpclient main

    new rename-client tools
    set-option global toolsclient tools
    set-option global docsclient tools
}

define-command find -params 1 -shell-script-candidates %{ find . -type f } %{ edit %arg{1} }
define-command git-edit -params 1 -shell-script-candidates %{ git ls-files } %{ edit %arg{1} }

# Shared fzf picker: %arg{1} = candidate command, %arg{2} = kakoune command
define-command -hidden fzf-pick -params 2 %{
    terminal sh -c %{
        sel=$(eval "$1" | fzf)
        if [ -n "$sel" ]; then
            escaped=$(printf '%s' "$sel" | sed "s/'/''/g")
            printf "evaluate-commands -client '%s' %s -- '%s'\n" "$3" "$2" "$escaped" | kak -p "$4"
        fi
    } _ %arg{1} %arg{2} %val{client} %val{session}
}

define-command -docstring "Open files with fzf using fd" fzf-find-edit %{
    fzf-pick 'fd . --type f' 'edit'
}

define-command -docstring "Open git-tracked files with fzf" fzf-edit %{
    fzf-pick 'git ls-files' 'edit'
}

define-command -hidden fzf-buffer-open -params 1 %{
    terminal sh -c %{
        sel=$(fzf --read0 < "$1")
        rm -f "$1"
        if [ -n "$sel" ]; then
            escaped=$(printf '%s' "$sel" | sed "s/'/''/g")
            printf "evaluate-commands -client '%s' buffer -- '%s'\n" "$2" "$escaped" | kak -p "$3"
        fi
    } _ %arg{1} %val{client} %val{session}
}

define-command -docstring "Select buffer with fzf" fzf-buffer %{
    evaluate-commands %sh{
        tmp=$(mktemp "${TMPDIR:-/tmp}/kak-bufs.XXXXXX")
        eval "set -- $kak_quoted_buflist"
        for buf in "$@"; do
            printf '%s\0' "$buf"
        done > "$tmp"
        printf "fzf-buffer-open '%s'\n" "$tmp"
    }
}

define-command nnn %{
    terminal env "KAK_CLIENT=%val{client}" "KAK_SESSION=%val{session}" VISUAL=open-in-kak nnn -Se -s %val{session}
}

define-command kakrc-edit %{ edit "%val{config}/kakrc" }

## Options

set-option global grepcmd 'rg -Hn --no-heading'
set-option global scrolloff 8,8

# Tab related stuff
set-option global indentwidth 4
set-option global tabstop 4

# Convert inserted tab to tabstop spaces
hook global InsertChar \t %{ execute-keys -draft h@ }
hook global InsertDelete ' ' %{
    try %{ execute-keys -draft 'h<a-h><a-k>\A\h+\z<ret>i<space><esc><lt>' }
}

hook global InsertCompletionShow .* %{
    try %{
        execute-keys -draft 'h<a-K>\h<ret>'
        map window insert <tab> <c-n>
        map window insert <s-tab> <c-p>
        hook -once -always window InsertCompletionHide .* %{
            unmap window insert <tab> <c-n>
            unmap window insert <s-tab> <c-p>
        }
    }
}

# hook global WinCreate ^[^*].*[^*]$ %{ git show-diff }
# hook global BufWritePost ^[^*].*[^*]$ %{ git update-diff }

add-highlighter global/ number-lines -hlcursor
# add-highlighter global/ show-matching

hook global BufCreate (.*/)?(\.kakrc\.local) %{
    set-option buffer filetype kak
}

## Cross-Platform Clipboard (<space>y)

evaluate-commands %sh{
    if [ -n "$WSL_DISTRO_NAME" ]; then
        if command -v win32yank.exe >/dev/null 2>&1; then
            cmd="win32yank.exe -i --crlf"
        else
            cmd="clip.exe"
        fi
    elif [ "$(uname -s)" = "Darwin" ]; then
        cmd="pbcopy"
    elif [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy >/dev/null 2>&1; then
        cmd="wl-copy"
    elif command -v xclip >/dev/null 2>&1; then
        cmd="xclip -i -selection clipboard"
    elif command -v xsel >/dev/null 2>&1; then
        cmd="xsel -b -i"
    fi

    if [ -n "$cmd" ]; then
        printf "map -docstring 'Yank to the system clipboard' global user y '<a-|>%s<ret>'\n" "$cmd"
    fi
}

## User mappings

map -docstring "Open file browser" global user f ": nnn<ret>"
map global normal <c-p> ": find "

map -docstring "Toggle comments on the selection" global user c ": comment-line<ret>"
map -docstring "Access alt file" global user o ": alt<ret>"

map -docstring "Find files (fzf)" global user p ": fzf-find-edit<ret>"
map -docstring "Find git files (fzf)" global user P ": fzf-edit<ret>"
map -docstring "Switch buffer (fzf)" global user b ": fzf-buffer<ret>"

map global goto N '<esc>: buffer-next<ret>' -docstring 'next buffer'
map global goto P '<esc>: buffer-previous<ret>' -docstring 'previous buffer'
map global goto b '<esc>: prompt -buffer-completion buffer: %{ buffer %val{text} }<ret>' -docstring 'buffer'
map global goto o '<esc>: lsp-find-error<ret>'
map global goto n '<esc>: grep-next-match<ret>'
map global goto p '<esc>: grep-previous-match<ret>'

## LSP

eval %sh{kak-lsp}
hook global WinSetOption filetype=(c|cpp|rust|zig|python|go) %{
    lsp-enable-window

    hook window -group semantic-tokens BufReload .* lsp-semantic-tokens
    hook window -group semantic-tokens NormalIdle .* lsp-semantic-tokens
    hook window -group semantic-tokens InsertIdle .* lsp-semantic-tokens
    hook -once -always window WinSetOption filetype=.* %{
        remove-hooks window semantic-tokens
    }
}

hook global BufSetOption filetype=(c|cpp|rust|zig|python|go|templ) %{
    hook buffer BufWritePre .* lsp-formatting-sync
}

set-option global lsp_auto_show_code_actions true

hook -group lsp-filetype-python global BufSetOption filetype=python %{
    set-option buffer lsp_servers %{
        [basedpyright-langserver]
        args = ["--stdio"]
        root_globs = ["pyproject.toml", "setup.py", "poetry.lock", "pyrightconfig.json", ".git", ".hg"]
    }
    set-option -add buffer lsp_servers %{
        [ruff]
        args = ["server", "--quiet"]
        root_globs = ["pyproject.toml", "setup.py", "poetry.lock", ".git", ".hg"]
        settings_section = "_"
        [ruff.settings._.globalSettings]
        organizeImports = true
        fixAll = true
    }
}

set-option global modelinefmt "%opt{lsp_modeline} %opt{modelinefmt}"

map global user l ':enter-user-mode lsp<ret>' -docstring 'LSP mode'

map global goto d <esc>:lsp-definition<ret> -docstring 'LSP definition'
map global goto r <esc>:lsp-references<ret> -docstring 'LSP references'
map global goto y <esc>:lsp-type-definition<ret> -docstring 'LSP type definition'

map global insert <tab> '<a-;>:try lsp-snippets-select-next-placeholders catch %{ execute-keys -with-hooks <lt>tab> }<ret>' -docstring 'Select next snippet placeholder'

map global object a '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
map global object <a-a> '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
map global object f '<a-semicolon>lsp-object Function Method<ret>' -docstring 'LSP function or method'
map global object t '<a-semicolon>lsp-object Class Interface Module Namespace Struct<ret>' -docstring 'LSP class or module'
map global object d '<a-semicolon>lsp-diagnostic-object error warning<ret>' -docstring 'LSP errors and warnings'
map global object D '<a-semicolon>lsp-diagnostic-object error<ret>' -docstring 'LSP errors'

## Project local settings
try %{ source .kakrc.local }
