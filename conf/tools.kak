## Modular Tools Loader
#
# Loads all available optional tool modules listed in `tool_modules` on KakBegin.
# Each module self-checks for its underlying binary and skips cleanly if missing.
# Override `tool_modules` (e.g. in .kakrc.local) to enable/disable specific tools.

try %{
    declare-option -docstring 'List of optional tool modules to load if their binaries are available' \
        str-list tool_modules 'yazi' 'fzf' 'lsp-config'
}

try %{
    declare-option -docstring 'Shell command used to list project files for :find and :fzf-find-edit' \
        str file_finder_cmd ''
}

evaluate-commands %sh{
    [ -n "$kak_opt_file_finder_cmd" ] && exit 0
    if command -v fd >/dev/null 2>&1; then
        printf "set-option global file_finder_cmd 'fd . --type f'\n"
    elif command -v fdfind >/dev/null 2>&1; then
        printf "set-option global file_finder_cmd 'fdfind . --type f'\n"
    else
        printf "set-option global file_finder_cmd 'find . -type f'\n"
    fi
}

source "%val{config}/conf/tools/helpers.kak"
source "%val{config}/conf/tools/yazi.kak"
source "%val{config}/conf/tools/fzf.kak"

remove-hooks global tool-detection

hook -group tool-detection global KakBegin .* %{
    evaluate-commands %sh{
        eval "set -- $kak_quoted_opt_tool_modules"
        for mod in "$@"; do
            esc=$(printf '%s' "$mod" | sed "s/'/''/g")
            printf "try %%{ require-module '%s' } catch %%{ echo -debug 'tool module %s not loaded' }\n" "$esc" "$esc"
        done
    }
}
