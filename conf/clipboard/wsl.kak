## WSL 2 Clipboard Module (win32yank.exe / clip.exe + powershell.exe)

try %{
    provide-module -override clipboard-wsl %{
        evaluate-commands %sh{
            if [ -n "$kak_opt_clipboard_modules" ] && [ -z "$WSL_DISTRO_NAME" ]; then
                printf "fail 'clipboard-wsl: not running in WSL'\n"
                exit 0
            fi

            copy_cmd=""
            paste_cmd=""

            if command -v win32yank.exe >/dev/null 2>&1; then
                copy_cmd='win32yank.exe -i --crlf'
                paste_cmd='win32yank.exe -o --lf'
            else
                if command -v clip.exe >/dev/null 2>&1; then
                    copy_cmd='clip.exe'
                fi
                if command -v powershell.exe >/dev/null 2>&1; then
                    paste_cmd="powershell.exe -NoProfile -Command Get-Clipboard | tr -d '\r'"
                fi
            fi

            if [ -z "$copy_cmd" ] && [ -z "$paste_cmd" ]; then
                printf "fail 'clipboard-wsl: no Windows clipboard utility found'\n"
                exit 0
            fi

            printf 'clipboard-register %%{%s} %%{%s}\n' "$copy_cmd" "$paste_cmd"
        }
    }
}
