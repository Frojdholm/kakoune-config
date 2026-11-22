## Kitty Windowing Extensions
#
# Extends Kakoune's built-in `kitty` windowing module (which provides
# kitty-terminal-window, kitty-terminal-tab, kitty-focus, and aliases
# `terminal` and `focus`) with directional splits and overlay popups.

remove-hooks global user-kitty

hook -group user-kitty global ModuleLoaded kitty %{
    define-command -override -hidden -params 2.. kitty-launch-ext %{
        evaluate-commands %sh{
            mode=$1
            shift

            kitty_listen="${kak_client_env_KITTY_LISTEN_ON:-$KITTY_LISTEN_ON}"
            kitty_win_id="${kak_client_env_KITTY_WINDOW_ID:-$KITTY_WINDOW_ID}"
            kitty_type="${kak_opt_kitty_window_type:-window}"

            rc_bin=""
            if command -v kitten >/dev/null 2>&1; then
                rc_bin="kitten"
            elif [ -x "/Applications/kitty.app/Contents/MacOS/kitten" ]; then
                rc_bin="/Applications/kitty.app/Contents/MacOS/kitten"
            elif command -v kitty >/dev/null 2>&1; then
                rc_bin="kitty"
            elif [ -x "/Applications/kitty.app/Contents/MacOS/kitty" ]; then
                rc_bin="/Applications/kitty.app/Contents/MacOS/kitty"
            fi

            if [ -z "$rc_bin" ]; then
                printf "fail 'kitty: neither kitten nor kitty found in PATH'\n"
                exit 0
            fi

            type_arg="$kitty_type"
            loc_arg=""
            match_arg=""

            case "$mode" in
                vertical)
                    loc_arg="--location=vsplit"
                    [ -n "$kitty_win_id" ] && match_arg="--match=window_id:$kitty_win_id"
                    ;;
                horizontal)
                    loc_arg="--location=hsplit"
                    [ -n "$kitty_win_id" ] && match_arg="--match=window_id:$kitty_win_id"
                    ;;
                popup)
                    type_arg="overlay"
                    [ -n "$kitty_win_id" ] && match_arg="--match=window_id:$kitty_win_id"
                    ;;
                tab)
                    type_arg="tab"
                    [ -n "$kitty_win_id" ] && match_arg="--match=window_id:$kitty_win_id"
                    ;;
            esac

            set -- -- "$@"
            [ -n "$TMPDIR" ] && set -- "--env=TMPDIR=$TMPDIR" "$@"
            [ -n "$XDG_RUNTIME_DIR" ] && set -- "--env=XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" "$@"
            set -- "--env=PATH=$PATH" "$@"
            set -- "--cwd=$PWD" "$@"
            [ -n "$match_arg" ] && set -- "$match_arg" "$@"
            [ -n "$loc_arg" ] && set -- "$loc_arg" "$@"
            set -- "--type=$type_arg" "$@"

            if [ -n "$kitty_listen" ]; then
                "$rc_bin" @ --to="$kitty_listen" launch "$@" >/dev/null 2>&1 ||
                    printf "fail 'kitty-launch-ext: remote control failed (check allow_remote_control and listen_on in kitty.conf)'\n"
            else
                "$rc_bin" @ launch "$@" >/dev/null 2>&1 ||
                    printf "fail 'kitty-launch-ext: remote control failed (set listen_on in kitty.conf)'\n"
            fi
        }
    }

    define-command -override -params 1.. -shell-completion \
        -docstring 'kitty-terminal-vertical <program> [<args>...]: open a program in a vertical (side-by-side) Kitty split' \
        kitty-terminal-vertical %{
        kitty-launch-ext vertical %arg{@}
    }

    define-command -override -params 1.. -shell-completion \
        -docstring 'kitty-terminal-horizontal <program> [<args>...]: open a program in a horizontal (stacked) Kitty split' \
        kitty-terminal-horizontal %{
        kitty-launch-ext horizontal %arg{@}
    }

    define-command -override -params 1.. -shell-completion \
        -docstring 'kitty-terminal-popup <program> [<args>...]: open a program in a Kitty overlay' \
        kitty-terminal-popup %{
        kitty-launch-ext popup %arg{@}
    }

    define-command -override -params 1.. -shell-completion \
        -docstring 'kitty-terminal-tab-ext <program> [<args>...]: open a program in a new Kitty tab' \
        kitty-terminal-tab-ext %{
        kitty-launch-ext tab %arg{@}
    }

    alias global terminal-vertical kitty-terminal-vertical
    alias global terminal-horizontal kitty-terminal-horizontal
    alias global terminal-tab kitty-terminal-tab-ext
    alias global terminal-popup kitty-terminal-popup
}
