## Yazi File Browser Module

try %{
    provide-module -override yazi %{
        evaluate-commands %sh{
            if ! command -v yazi >/dev/null 2>&1; then
                printf "fail 'yazi: binary not found in PATH'\n"
            fi
        }

        define-command -override -hidden -params 1 yazi-open %{
            terminal-popup sh -c %{
                tmp=$(mktemp "${TMPDIR:-/tmp}/kak-yazi.XXXXXX")
                trap 'rm -f "$tmp"' EXIT INT TERM
                yazi --chooser-file="$tmp" "$1"
                if [ -s "$tmp" ]; then
                    esc_client=$(printf '%s' "$2" | sed "s/'/''/g")
                    {
                        while IFS= read -r path || [ -n "$path" ]; do
                            [ -n "$path" ] || continue
                            esc_path=$(printf '%s' "$path" | sed "s/'/''/g")
                            if [ -d "$path" ]; then
                                printf "evaluate-commands -client '%s' change-directory -- '%s'\n" "$esc_client" "$esc_path"
                            else
                                printf "evaluate-commands -client '%s' edit -- '%s'\n" "$esc_client" "$esc_path"
                            fi
                        done < "$tmp"
                    } | kak -p "$3"
                fi
            } _ %arg{1} %val{client} %val{session}
        }

        define-command -override -params ..1 -file-completion \
            -docstring 'yazi [<path>]: open Yazi file browser (defaults to current buffer file or cwd)' \
            yazi %{
            evaluate-commands %sh{
                if [ $# -ge 1 ] && [ -n "$1" ]; then
                    target="$1"
                elif [ -n "$kak_buffile" ] && [ -e "$kak_buffile" ]; then
                    target="$kak_buffile"
                elif [ -n "$kak_buffile" ] && [ -d "$(dirname "$kak_buffile")" ] && [ "${kak_buffile#\*}" = "$kak_buffile" ]; then
                    target=$(dirname "$kak_buffile")
                else
                    target="$PWD"
                fi

                esc_target=$(printf '%s' "$target" | sed "s/'/''/g")
                printf "yazi-open '%s'\n" "$esc_target"
            }
        }

        define-command -override -docstring 'Open Yazi file browser in the current working directory' yazi-cwd %{
            evaluate-commands %sh{
                esc_pwd=$(printf '%s' "$PWD" | sed "s/'/''/g")
                printf "yazi '%s'\n" "$esc_pwd"
            }
        }
    }
}
