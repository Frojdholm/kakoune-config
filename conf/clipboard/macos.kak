## macOS Clipboard Module (pbcopy / pbpaste)

try %{
    provide-module -override clipboard-macos %{
        evaluate-commands %sh{
            if [ -n "$kak_opt_clipboard_modules" ] && [ "$(uname -s)" != "Darwin" ]; then
                printf "fail 'clipboard-macos: not running on macOS'\n"
                exit 0
            fi

            if ! command -v pbcopy >/dev/null 2>&1; then
                printf "fail 'clipboard-macos: pbcopy not found'\n"
                exit 0
            fi

            printf 'clipboard-register %%{pbcopy} %%{pbpaste}\n'
        }
    }
}
