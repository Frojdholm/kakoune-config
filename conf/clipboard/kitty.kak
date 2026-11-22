## Kitty Clipboard Module (kitten clipboard — OSC 52, works over SSH/headless)

try %{
    provide-module -override clipboard-kitty %{
        evaluate-commands %sh{
            if [ -n "$kak_opt_clipboard_modules" ] && [ "$TERM" != "xterm-kitty" ]; then
                printf "fail 'clipboard-kitty: not running in Kitty'\n"
                exit 0
            fi

            kitten_bin=""
            if command -v kitten >/dev/null 2>&1; then
                kitten_bin="kitten"
            elif [ -x "/Applications/kitty.app/Contents/MacOS/kitten" ]; then
                kitten_bin="/Applications/kitty.app/Contents/MacOS/kitten"
            fi

            if [ -z "$kitten_bin" ]; then
                printf "fail 'clipboard-kitty: kitten not found'\n"
                exit 0
            fi

            printf 'clipboard-register %%{%s clipboard} %%{%s clipboard --get-clipboard}\n' "$kitten_bin" "$kitten_bin"
        }
    }
}
