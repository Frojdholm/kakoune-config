## Important: setup tree sitter first
# eval %sh{ kak-tree-sitter -dks --init $kak_session }

colorscheme catppuccin_mocha

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

define-command -docstring "Open files with fzf using find" -params 0 fzf-find-edit %{
    evaluate-commands %sh{
        if [ -z "$kak_client_env_TMUX" ]; then
            printf "fail 'client is not started in tmux'\n"
        else
            file=$(fd . --type f | TMUX="$kak_client_env_TMUX" fzf-tmux -d 15)
            if [ -n "$file" ]; then
                printf "edit '%s'\n" "$file"
            fi
        fi
    }
}

define-command -docstring "Open files with fzf" -params 0 fzf-edit %{
    evaluate-commands %sh{
        if [ -z "$kak_client_env_TMUX" ]; then
            printf "fail 'client is not started in tmux'\n"
        else
            file=$(git ls-files | TMUX="$kak_client_env_TMUX" fzf-tmux -d 15)
            if [ -n "$file" ]; then
                printf "edit '%s'\n" "$file"
            fi
        fi
    }
}

define-command -docstring "Select buffer with fzf" fzf-buffer %{
    evaluate-commands %sh{
        if [ -z "$kak_client_env_TMUX" ]; then
            printf "fail 'client is not started in tmux'\n"
        else
            BUFFER=$(
                (
                    eval "set -- $kak_buflist"
                    while [ $# -gt 0 ]; do
                        printf "%s\0" "$1"
                        shift
                    done
                ) | fzf-tmux -d 15 --read0
            )
            if [ -n "$BUFFER" ]; then
                printf "buffer '%s'\n" "${BUFFER}"
            fi
        fi
    }
}

define-command nnn %{
    nop %sh{
        tmux split-window -f -h -b -l 36 "KAK_CLIENT=$kak_client KAK_SESSION=$kak_session VISUAL=open-in-kak nnn -Se -s $kak_session"
    }
}

define-command kakrc-edit %{ edit "~/.config/kak/kakrc" }

## Options

set-option global grepcmd 'rg -Hn --no-heading'
set-option global scrolloff 8,8

# Tab related stuff
set-option global indentwidth 4
set-option global tabstop 4

# Convert inserted tab to tabstop spaces
hook global InsertChar \t %{ execute-keys -draft h@ }
# This hook:
# h                 - Move one step to the left to move into indent space
# <a-h>             - Select all indent region
# <a-k>\A\h+\z<ret> - Keep only whitespace
# i<space>          - Insert the deleted space
# <esc>             - Back to normal mode
# <lt>              - dedent one indentwidth
hook global InsertDelete ' ' %{
    try %{ execute-keys -draft 'h<a-h><a-k>\A\h+\z<ret>i<space><esc><lt>' }
}

hook global InsertCompletionShow .* %{
    try %{
        # this command temporarily removes cursors preceded by whitespace;
        # if there are no cursors left, it raises an error, does not
        # continue to execute the mapping commands, and the error is eaten
        # by the `try` command so no warning appears.
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

# set-option global windowing_placement horizontal

add-highlighter global/ number-lines -hlcursor
# add-highlighter global/ show-matching

hook global BufCreate (.*/)?(\.kakrc\.local) %{
    set-option buffer filetype kak
}

## User mappings
map -docstring "Open file browser" global user f ": nnn<ret>"
map global normal <c-p> ": find "

map -docstring "Toggle comments on the selection"  global user c ": comment-line<ret>"
map -docstring "Access alt file" global user o ": alt<ret>"

map -docstring "Yank to the system clipboard" global user y "<a-|>xclip -i -selection clipboard<ret>"

map global user p ': find-edit ' -docstring 'Find files'

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
