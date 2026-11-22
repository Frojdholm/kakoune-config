## Appearance & UI

colorscheme catppuccin_mocha

# Reload unmodified buffers automatically when changed on disk
set-option global autoreload yes

# Keep vertical and horizontal context around the cursor
set-option global scrolloff 8,8

# Line numbers (idempotent on config reload)
try %{ remove-highlighter global/number-lines }
add-highlighter global/number-lines number-lines -hlcursor -separator '  '

# Optional highlighters / git diff indicators (uncomment to enable)
try %{ remove-highlighter global/show-matching }
add-highlighter global/show-matching show-matching
hook global WinCreate ^[^*].*[^*]$ %{ git show-diff }
hook global BufWritePost ^[^*].*[^*]$ %{ git update-diff }

## Search

# Use ripgrep with column numbers and smart case
set-option global grepcmd 'rg -Hn --no-heading --column --smart-case'

## Indentation & Soft Tabs

set-option global indentwidth 4
set-option global tabstop 4

remove-hooks global user-indentation

# Expand inserted tabs to spaces and smart-backspace indentation,
# scoped to the window so tab-indented filetypes (Go, Makefiles) can opt out cleanly.
hook -group user-indentation global WinCreate .* %{
    hook -group soft-tabs window InsertChar \t %{ execute-keys -draft h@ }
    hook -group soft-tabs window InsertDelete ' ' %{
        try %{ execute-keys -draft 'h<a-h><a-k>\A\h+\z<ret>i<space><esc><lt>' }
    }
}

hook -group user-indentation global WinSetOption filetype=(go|makefile) %{
    set-option buffer indentwidth 0
    remove-hooks window soft-tabs
}

## Completion

remove-hooks global user-completion

# Use <tab>/<s-tab> to cycle insert completion candidates when the menu is open.
# Window-scoped mappings take precedence over the global LSP snippet <tab> mapping
# while the popup is visible, and restore it automatically when hidden.
hook -group user-completion global InsertCompletionShow .* %{
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

## Filetypes

remove-hooks global user-filetypes

hook -group user-filetypes global BufCreate (.*/)?(\.kakrc\.local) %{
    set-option buffer filetype kak
}
