## Prompt Pickers & Config Helpers (no external tool requirements)

define-command -override -params 1 \
    -shell-script-candidates %{ sh -c "$kak_opt_file_finder_cmd" } \
    -docstring 'find <file>: open a file with completion' \
    find %{
    edit %arg{1}
}

define-command -override -params 1 \
    -shell-script-candidates %{ git ls-files } \
    -docstring 'git-edit <file>: open a git-tracked file with completion' \
    git-edit %{
    edit %arg{1}
}

define-command -override -docstring 'Open main kakrc' kakrc-edit %{
    edit "%val{config}/kakrc"
}

define-command -override -params 1 \
    -shell-script-candidates %{
        cd "$kak_config" 2>/dev/null || exit 0
        find . -maxdepth 3 \
            \( -path './.git' -o -path './autoload' -o -path './vendor' \) -prune \
            -o \( -name 'kakrc' -o -name '*.kak' \) -type f -print \
            | sed 's|^\./||' | sort
    } \
    -docstring 'config-edit <file>: edit a file in the Kakoune config directory' \
    config-edit %{
    edit "%val{config}/%arg{1}"
}
