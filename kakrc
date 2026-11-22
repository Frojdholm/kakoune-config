## Important: setup tree-sitter first (if enabled)
# evaluate-commands %sh{ kak-tree-sitter -dks --init "$kak_session" }

## Modular Configuration

source "%val{config}/conf/options.kak"
source "%val{config}/conf/windowing.kak"
source "%val{config}/conf/clipboard.kak"
source "%val{config}/conf/tools.kak"
source "%val{config}/conf/lsp.kak"
source "%val{config}/conf/mappings.kak"

## Project-local settings (loaded last so projects can override anything)

try %{ source .kakrc.local }
