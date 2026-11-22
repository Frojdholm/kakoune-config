## Fuzzy Picker Module (fzf)

try %{
    provide-module -override fzf %{
        evaluate-commands %sh{
            if ! command -v fzf >/dev/null 2>&1; then
                printf "fail 'fzf: binary not found in PATH'\n"
            fi
        }

        # Shared multi-select fzf picker: %arg{1} = candidate command, %arg{2} = kakoune command
        define-command -override -hidden -params 2 fzf-pick %{
            terminal-popup sh -c %{
                sel=$(sh -c "$1" | fzf -m)
                if [ -n "$sel" ]; then
                    esc_client=$(printf '%s' "$3" | sed "s/'/''/g")
                    {
                        printf '%s\n' "$sel" | while IFS= read -r item; do
                            [ -n "$item" ] || continue
                            esc_item=$(printf '%s' "$item" | sed "s/'/''/g")
                            printf "evaluate-commands -client '%s' %s -- '%s'\n" "$esc_client" "$2" "$esc_item"
                        done
                    } | kak -p "$4"
                fi
            } _ %arg{1} %arg{2} %val{client} %val{session}
        }

        define-command -override -docstring 'Open files with fzf (uses file_finder_cmd)' fzf-find-edit %{
            fzf-pick %opt{file_finder_cmd} 'edit'
        }

        define-command -override -docstring 'Open git-tracked files with fzf' fzf-edit %{
            fzf-pick 'git ls-files' 'edit'
        }

        define-command -override -hidden -params 1 fzf-buffer-open %{
            terminal-popup sh -c %{
                trap 'rm -f "$1"' EXIT INT TERM
                sel=$(fzf --read0 < "$1")
                if [ -n "$sel" ]; then
                    esc_client=$(printf '%s' "$2" | sed "s/'/''/g")
                    esc_sel=$(printf '%s' "$sel" | sed "s/'/''/g")
                    printf "evaluate-commands -client '%s' buffer -- '%s'\n" "$esc_client" "$esc_sel" | kak -p "$3"
                fi
            } _ %arg{1} %val{client} %val{session}
        }

        define-command -override -docstring 'Select buffer with fzf' fzf-buffer %{
            evaluate-commands %sh{
                tmp=$(mktemp "${TMPDIR:-/tmp}/kak-bufs.XXXXXX")
                eval "set -- $kak_quoted_buflist"
                for buf in "$@"; do
                    printf '%s\0' "$buf"
                done > "$tmp"
                esc_tmp=$(printf '%s' "$tmp" | sed "s/'/''/g")
                printf "fzf-buffer-open '%s'\n" "$esc_tmp"
            }
        }

        define-command -override -hidden fzf-grep-open %{
            terminal-popup sh -c %{
                rg_cmd='rg --line-number --column --no-heading --color=always --smart-case --'
                sel=$(fzf --ansi --disabled \
                    --prompt 'rg> ' \
                    --bind "change:reload:$rg_cmd {q} || true" \
                    --delimiter :)
                if [ -n "$sel" ]; then
                    file=$(printf '%s' "$sel" | cut -d: -f1)
                    line=$(printf '%s' "$sel" | cut -d: -f2)
                    col=$(printf '%s' "$sel" | cut -d: -f3)
                    esc_client=$(printf '%s' "$1" | sed "s/'/''/g")
                    esc_file=$(printf '%s' "$file" | sed "s/'/''/g")
                    printf "evaluate-commands -client '%s' edit -- '%s' %s %s\n" \
                        "$esc_client" "$esc_file" "$line" "$col" | kak -p "$2"
                fi
            } _ %val{client} %val{session}
        }

        define-command -override -docstring 'Live search project with ripgrep + fzf' fzf-grep %{
            evaluate-commands %sh{
                if ! command -v rg >/dev/null 2>&1; then
                    printf "fail 'rg (ripgrep) is not installed'\n"
                    exit 0
                fi
                printf 'fzf-grep-open\n'
            }
        }
    }
}
