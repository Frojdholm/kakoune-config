## Language Server Protocol Module (kak-lsp)
#
# Loaded automatically via `tool_modules` on KakBegin when `kak-lsp` is installed.
# Keybindings are attached in conf/mappings.kak via `ModuleLoaded lsp-config`.

try %{
    provide-module -override lsp-config %{
        evaluate-commands %sh{
            if ! command -v kak-lsp >/dev/null 2>&1; then
                printf "fail 'lsp-config: kak-lsp not found in PATH'\n"
                exit 0
            fi
            kak-lsp
        }

        set-option global lsp_auto_show_code_actions true
        set-option global modelinefmt "%opt{lsp_modeline} %opt{modelinefmt}"

        remove-hooks global lsp-config

        # Enable LSP and semantic tokens for supported languages
        hook -group lsp-config global WinSetOption filetype=(c|cpp|rust|zig|python|go|templ) %{
            lsp-enable-window

            hook window -group semantic-tokens BufReload .* lsp-semantic-tokens
            hook window -group semantic-tokens NormalIdle .* lsp-semantic-tokens
            hook window -group semantic-tokens InsertIdle .* lsp-semantic-tokens
            hook -once -always window WinSetOption filetype=.* %{
                remove-hooks window semantic-tokens
            }
        }

        # Format on save (gracefully skipped if no formatter is attached)
        hook -group lsp-config global BufSetOption filetype=(c|cpp|rust|zig|python|go|templ) %{
            remove-hooks buffer lsp-format
            hook -group lsp-format buffer BufWritePre .* %{
                try %{ lsp-formatting-sync }
            }
            hook -once -always buffer BufSetOption filetype=.* %{
                remove-hooks buffer lsp-format
            }
        }

        # Override default kak-lsp Python servers with basedpyright + ruff
        remove-hooks global lsp-filetype-python
        hook -group lsp-filetype-python global BufSetOption filetype=python %{
            set-option buffer lsp_servers %{
                [basedpyright-langserver]
                args = ["--stdio"]
                root_globs = ["pyproject.toml", "setup.py", "poetry.lock", "pyrightconfig.json", ".git", ".hg"]
            }
            set-option -add buffer lsp_servers %{
                [ruff]
                args = ["server", "--quiet"]
                root_globs = ["pyproject.toml", "setup.py", "poetry.lock", ".git", ".hg"]
                settings_section = "_"
                [ruff.settings._.globalSettings]
                organizeImports = true
                fixAll = true
            }
        }
    }
}
