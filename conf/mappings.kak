## Normal Mode Mappings

map global normal <c-p> ': find '

## Core User Mode Mappings (<space>)
# Note: clipboard mappings (y, v, V, R) are registered by the active clipboard module

map -docstring 'Toggle comments on the selection' global user c ': comment-line<ret>'
map -docstring 'Access alt file' global user o ': alt<ret>'

## Window / Terminal Splits Mode (<space>w)

try %{ declare-user-mode window }

map -docstring 'Window / terminal splits' global user w ': enter-user-mode window<ret>'

map -docstring 'Vertical split (new client)' global window v ': split-vertical<ret>'
map -docstring 'Horizontal split (new client)' global window h ': split-horizontal<ret>'
map -docstring 'New tab (new client)' global window t ': new-tab<ret>'
map -docstring 'New client (auto split)' global window n ': new<ret>'
map -docstring 'Vertical shell split' global window s ': shell-vertical<ret>'
map -docstring 'Horizontal shell split' global window S ': shell-horizontal<ret>'
map -docstring 'IDE layout (main + tools)' global window i ': ide<ret>'

## Core Goto Mode Mappings (g)

map global goto N '<esc>: buffer-next<ret>' -docstring 'next buffer'
map global goto P '<esc>: buffer-previous<ret>' -docstring 'previous buffer'
map global goto b '<esc>: prompt -buffer-completion buffer: %{ buffer %val{text} }<ret>' -docstring 'buffer'
map global goto n '<esc>: grep-next-match<ret>' -docstring 'next grep match'
map global goto p '<esc>: grep-previous-match<ret>' -docstring 'previous grep match'

## Module-Scoped Mappings (activated only when the corresponding module loads)

remove-hooks global user-mappings

hook -group user-mappings global ModuleLoaded yazi %{
    map -docstring 'Open file browser (yazi)' global user f ': yazi<ret>'
    map -docstring 'Open file browser at cwd (yazi)' global user F ': yazi-cwd<ret>'
}

hook -group user-mappings global ModuleLoaded fzf %{
    map -docstring 'Find files (fzf)' global user p ': fzf-find-edit<ret>'
    map -docstring 'Find git files (fzf)' global user P ': fzf-edit<ret>'
    map -docstring 'Switch buffer (fzf)' global user b ': fzf-buffer<ret>'
    map -docstring 'Search project (rg + fzf)' global user / ': fzf-grep<ret>'
}

hook -group user-mappings global ModuleLoaded lsp-config %{
    map global user l ': enter-user-mode lsp<ret>' -docstring 'LSP mode'

    map global goto d '<esc>: lsp-definition<ret>' -docstring 'LSP definition'
    map global goto r '<esc>: lsp-references<ret>' -docstring 'LSP references'
    map global goto y '<esc>: lsp-type-definition<ret>' -docstring 'LSP type definition'
    map global goto o '<esc>: lsp-find-error<ret>' -docstring 'LSP next error'
    map global goto O '<esc>: lsp-find-error --previous<ret>' -docstring 'LSP previous error'

    map global insert <tab> '<a-;>:try lsp-snippets-select-next-placeholders catch %{ execute-keys -with-hooks <lt>tab> }<ret>' \
        -docstring 'Select next snippet placeholder'

    map global object a '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
    map global object <a-a> '<a-semicolon>lsp-object<ret>' -docstring 'LSP any symbol'
    map global object f '<a-semicolon>lsp-object Function Method<ret>' -docstring 'LSP function or method'
    map global object t '<a-semicolon>lsp-object Class Interface Module Namespace Struct<ret>' -docstring 'LSP class or module'
    map global object d '<a-semicolon>lsp-diagnostic-object error warning<ret>' -docstring 'LSP errors and warnings'
    map global object D '<a-semicolon>lsp-diagnostic-object error<ret>' -docstring 'LSP errors'
}
