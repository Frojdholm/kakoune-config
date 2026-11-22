## Windows Terminal Windowing Module (WSL 2)
#
# Provides native Windows Terminal splits and tabs from inside WSL 2 via wt.exe.
# Loaded automatically by Kakoune's windowing_modules detection on KakBegin.

try %{
    provide-module -override windows-terminal %{
        # Self-check during auto-detection (bypassed when windowing_modules is empty for manual loading)
        evaluate-commands %sh{
            if [ -n "$kak_opt_windowing_modules" ]; then
                if [ -z "$WSL_DISTRO_NAME" ] || ! command -v wt.exe >/dev/null 2>&1; then
                    printf "fail 'windows-terminal: not running in WSL with wt.exe'\n"
                fi
            fi
        }

        declare-option -docstring 'Split size ratio (0.0-1.0) for popup panes in Windows Terminal' \
            str windowing_wt_popup_size '0.45'

        define-command -override -hidden -params 2.. wt-terminal-impl %{
            nop %sh{
                mode=$1
                shift

                wsl_distro="${kak_client_env_WSL_DISTRO_NAME:-$WSL_DISTRO_NAME}"
                wt_popup_size="${kak_opt_windowing_wt_popup_size:-0.45}"

                print_sh_quoted() {
                    printf "'"
                    printf '%s' "$1" | sed "s/'/'\\\\''/g"
                    printf "'"
                }

                # Use a self-deleting wrapper script to preserve environment, cwd,
                # and arbitrary argument quoting (including ';' which wt.exe parses
                # as a subcommand separator).
                script=$(mktemp "${TMPDIR:-/tmp}/kak-term.XXXXXX")
                chmod 700 "$script"
                {
                    printf '#!/bin/sh\n'
                    if [ -n "$kak_session" ]; then
                        printf 'export KAK_SESSION='; print_sh_quoted "$kak_session"; printf '\n'
                    fi
                    printf 'export PATH='; print_sh_quoted "$PATH"; printf '\n'
                    if [ -n "$XDG_RUNTIME_DIR" ]; then
                        printf 'export XDG_RUNTIME_DIR='; print_sh_quoted "$XDG_RUNTIME_DIR"; printf '\n'
                    fi
                    if [ -n "$TMPDIR" ]; then
                        printf 'export TMPDIR='; print_sh_quoted "$TMPDIR"; printf '\n'
                    fi
                    printf 'cd '; print_sh_quoted "$PWD"; printf ' || exit 1\n'
                    printf 'rm -f '; print_sh_quoted "$script"; printf '\n'
                    printf 'exec'
                    for arg in "$@"; do
                        printf ' '; print_sh_quoted "$arg"
                    done
                    printf '\n'
                } > "$script"

                case "$mode" in
                    vertical)
                        wt.exe -w 0 split-pane -V -- wsl.exe -d "$wsl_distro" -- "$script" >/dev/null 2>&1 &
                        ;;
                    horizontal)
                        wt.exe -w 0 split-pane -H -- wsl.exe -d "$wsl_distro" -- "$script" >/dev/null 2>&1 &
                        ;;
                    drawer)
                        drawer_pct="${kak_opt_windowing_drawer_size:-40}"
                        case "$drawer_pct" in
                            ''|*[!0-9]*) drawer_pct=40 ;;
                        esac
                        [ "$drawer_pct" -lt 10 ] && drawer_pct=10
                        [ "$drawer_pct" -gt 90 ] && drawer_pct=90
                        wt_drawer_size=$(printf '0.%02d' "$drawer_pct")
                        wt.exe -w 0 split-pane -V --size "$wt_drawer_size" -- wsl.exe -d "$wsl_distro" -- "$script" >/dev/null 2>&1 &
                        ;;
                    tab)
                        wt.exe -w 0 new-tab -- wsl.exe -d "$wsl_distro" -- "$script" >/dev/null 2>&1 &
                        ;;
                    popup)
                        wt.exe -w 0 split-pane -H --size "$wt_popup_size" -- wsl.exe -d "$wsl_distro" -- "$script" >/dev/null 2>&1 &
                        ;;
                    *)
                        wt.exe -w 0 split-pane -- wsl.exe -d "$wsl_distro" -- "$script" >/dev/null 2>&1 &
                        ;;
                esac
            }
        }

        define-command -override -params 1.. -shell-completion \
            -docstring 'wt-terminal <program> [<args>...]: open a program in a Windows Terminal split' \
            wt-terminal %{
            wt-terminal-impl default %arg{@}
        }

        define-command -override -params 1.. -shell-completion \
            -docstring 'wt-terminal-vertical <program> [<args>...]: open a program in a vertical (side-by-side) split' \
            wt-terminal-vertical %{
            wt-terminal-impl vertical %arg{@}
        }

        define-command -override -params 1.. -shell-completion \
            -docstring 'wt-terminal-horizontal <program> [<args>...]: open a program in a horizontal (stacked) split' \
            wt-terminal-horizontal %{
            wt-terminal-impl horizontal %arg{@}
        }

        define-command -override -params 1.. -shell-completion \
            -docstring 'wt-terminal-drawer <program> [<args>...]: open a program in a sized vertical Windows Terminal split' \
            wt-terminal-drawer %{
            wt-terminal-impl drawer %arg{@}
        }

        define-command -override -params 1.. -shell-completion \
            -docstring 'wt-terminal-tab <program> [<args>...]: open a program in a new Windows Terminal tab' \
            wt-terminal-tab %{
            wt-terminal-impl tab %arg{@}
        }

        define-command -override -params 1.. -shell-completion \
            -docstring 'wt-terminal-popup <program> [<args>...]: open a program in a bottom Windows Terminal split' \
            wt-terminal-popup %{
            wt-terminal-impl popup %arg{@}
        }

        define-command -override -params ..1 -client-completion \
            -docstring 'wt-focus [<client>]: no-op placeholder (Windows Terminal does not expose pane focus via CLI)' \
            wt-focus %{
            nop
        }

        alias global terminal wt-terminal
        alias global terminal-vertical wt-terminal-vertical
        alias global terminal-horizontal wt-terminal-horizontal
        alias global terminal-drawer wt-terminal-drawer
        alias global terminal-tab wt-terminal-tab
        alias global terminal-popup wt-terminal-popup
        alias global focus wt-focus
    }
}
