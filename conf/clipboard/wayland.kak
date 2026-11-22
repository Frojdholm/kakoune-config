## Wayland Clipboard Module (wl-copy / wl-paste)

try %{
    provide-module -override clipboard-wayland %{
        evaluate-commands %sh{
            if [ -n "$kak_opt_clipboard_modules" ] && [ -z "$WAYLAND_DISPLAY" ]; then
                printf "fail 'clipboard-wayland: WAYLAND_DISPLAY is not set'\n"
                exit 0
            fi

            if ! command -v wl-copy >/dev/null 2>&1; then
                printf "fail 'clipboard-wayland: wl-copy not found'\n"
                exit 0
            fi

            paste_cmd=""
            if command -v wl-paste >/dev/null 2>&1; then
                paste_cmd='wl-paste --no-newline'
            fi

            printf 'clipboard-register %%{wl-copy >/dev/null 2>&1} %%{%s}\n' "$paste_cmd"
        }
    }
}
