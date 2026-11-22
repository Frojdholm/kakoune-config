## X11 Clipboard Module (xclip / xsel)

try %{
    provide-module -override clipboard-x11 %{
        evaluate-commands %sh{
            if [ -n "$kak_opt_clipboard_modules" ] && [ -z "$DISPLAY" ]; then
                printf "fail 'clipboard-x11: DISPLAY is not set'\n"
                exit 0
            fi

            if command -v xclip >/dev/null 2>&1; then
                printf 'clipboard-register %%{xclip -i -selection clipboard >/dev/null 2>&1} %%{xclip -o -selection clipboard}\n'
            elif command -v xsel >/dev/null 2>&1; then
                printf 'clipboard-register %%{xsel -b -i >/dev/null 2>&1} %%{xsel -b -o}\n'
            else
                printf "fail 'clipboard-x11: neither xclip nor xsel found'\n"
            fi
        }
    }
}
