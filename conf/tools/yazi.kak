## Yazi File Browser Module

try %{
    provide-module -override yazi %{
        evaluate-commands %sh{
            if ! command -v yazi >/dev/null 2>&1; then
                printf "fail 'yazi: binary not found in PATH'\n"
            fi
        }

        define-command -override -hidden -params 3 yazi-dispatch %{
            evaluate-commands %sh{
                mode=$1
                client=$2
                tmp=$3

                if [ "$mode" = "edit" ]; then
                    trap 'rm -f "$tmp"' EXIT
                    esc_client=$(printf '%s' "$client" | sed "s/'/''/g")
                    while IFS= read -r path || [ -n "$path" ]; do
                        [ -n "$path" ] || continue
                        esc_path=$(printf '%s' "$path" | sed "s/'/''/g")
                        if [ -d "$path" ]; then
                            printf "evaluate-commands -client '%s' -verbatim -- change-directory -- '%s'\n" "$esc_client" "$esc_path"
                        else
                            printf "evaluate-commands -client '%s' -verbatim -- edit -- '%s'\n" "$esc_client" "$esc_path"
                        fi
                    done < "$tmp"
                else
                    (
                        trap 'rm -f "$tmp"' EXIT
                        sleep 0.15
                        esc_client=$(printf '%s' "$client" | sed "s/'/''/g")
                        {
                            while IFS= read -r path || [ -n "$path" ]; do
                                [ -n "$path" ] || continue
                                esc_path=$(printf '%s' "$path" | sed "s/'/''/g")
                                if [ -d "$path" ]; then
                                    printf "evaluate-commands -client '%s' -verbatim -- change-directory -- '%s'\n" "$esc_client" "$esc_path"
                                else
                                    case "$mode" in
                                        vertical)
                                            printf "evaluate-commands -client '%s' -verbatim -- edit-vertical '%s'\n" "$esc_client" "$esc_path"
                                            ;;
                                        horizontal)
                                            printf "evaluate-commands -client '%s' -verbatim -- edit-horizontal '%s'\n" "$esc_client" "$esc_path"
                                            ;;
                                        tab)
                                            printf "evaluate-commands -client '%s' -verbatim -- edit-tab '%s'\n" "$esc_client" "$esc_path"
                                            ;;
                                    esac
                                fi
                            done < "$tmp"
                        } | kak -p "$kak_session"
                    ) </dev/null >/dev/null 2>&1 &
                fi
            }
        }

        define-command -override -hidden -params 2 yazi-open %{
            terminal-popup sh -c %{
                tmp=$(mktemp "${TMPDIR:-/tmp}/kak-yazi.XXXXXX")
                action_tmp=$(mktemp "${TMPDIR:-/tmp}/kak-yazi-action.XXXXXX")
                cleanup_needed=1
                trap '[ "$cleanup_needed" = 1 ] && rm -f "$tmp" "$action_tmp"' EXIT INT TERM

                mode=$1
                target=$2
                client=$3
                session=$4

                KAK_YAZI_ACTION_FILE="$action_tmp" yazi --chooser-file="$tmp" "$target"

                if [ -s "$tmp" ]; then
                    if [ -s "$action_tmp" ]; then
                        action=$(tr -d ' \t\r\n' < "$action_tmp")
                        case "$action" in
                            edit|vertical|horizontal|tab) mode=$action ;;
                        esac
                    fi
                    rm -f "$action_tmp"
                    cleanup_needed=0
                    esc_mode=$(printf '%s' "$mode" | sed "s/'/''/g")
                    esc_client=$(printf '%s' "$client" | sed "s/'/''/g")
                    esc_tmp=$(printf '%s' "$tmp" | sed "s/'/''/g")
                    printf "yazi-dispatch '%s' '%s' '%s'\n" "$esc_mode" "$esc_client" "$esc_tmp" | kak -p "$session"
                fi
            } _ %arg{1} %arg{2} %val{client} %val{session}
        }

        define-command -override -hidden -params 1..2 yazi-launch %{
            evaluate-commands %sh{
                mode=$1
                shift

                if [ $# -ge 1 ] && [ -n "$1" ]; then
                    target="$1"
                elif [ -n "$kak_buffile" ] && [ -e "$kak_buffile" ]; then
                    target="$kak_buffile"
                elif [ -n "$kak_buffile" ] && [ -d "$(dirname "$kak_buffile")" ] && [ "${kak_buffile#\*}" = "$kak_buffile" ]; then
                    target=$(dirname "$kak_buffile")
                else
                    target="$PWD"
                fi

                esc_mode=$(printf '%s' "$mode" | sed "s/'/''/g")
                esc_target=$(printf '%s' "$target" | sed "s/'/''/g")
                printf "yazi-open '%s' '%s'\n" "$esc_mode" "$esc_target"
            }
        }

        define-command -override -params ..1 -file-completion \
            -docstring 'yazi [<path>]: open Yazi file browser (defaults to current buffer file or cwd)' \
            yazi %{
            yazi-launch edit %arg{@}
        }

        define-command -override -params ..1 -file-completion \
            -docstring 'yazi-vertical [<path>]: open Yazi and open selected file(s) in vertical split(s)' \
            yazi-vertical %{
            yazi-launch vertical %arg{@}
        }

        define-command -override -params ..1 -file-completion \
            -docstring 'yazi-horizontal [<path>]: open Yazi and open selected file(s) in horizontal split(s)' \
            yazi-horizontal %{
            yazi-launch horizontal %arg{@}
        }

        define-command -override -params ..1 -file-completion \
            -docstring 'yazi-tab [<path>]: open Yazi and open selected file(s) in new tab(s)' \
            yazi-tab %{
            yazi-launch tab %arg{@}
        }

        define-command -override -docstring 'Open Yazi file browser in the current working directory' yazi-cwd %{
            evaluate-commands %sh{
                esc_pwd=$(printf '%s' "$PWD" | sed "s/'/''/g")
                printf "yazi '%s'\n" "$esc_pwd"
            }
        }
    }
}
