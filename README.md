# Kakoune Configuration

Modular, cross-platform Kakoune configuration designed to work natively with **Windows Terminal (WSL 2)** on Windows and **Kitty** on Linux and macOS — without a terminal multiplexer like `tmux`.

Built around Kakoune's native `provide-module` / `require-module` and `ModuleLoaded` pattern:
- **`windowing_modules`** (`'windows-terminal' 'kitty'`) — built-in Kakoune auto-detection; loads only the matching terminal module.
- **`clipboard_modules`** (`'clipboard-wsl' 'clipboard-macos' 'clipboard-wayland' 'clipboard-x11' 'clipboard-kitty'`) — first-match-wins clipboard backend detection on `KakBegin`.
- **`tool_modules`** (`'yazi' 'fzf' 'lsp-config'`) — loads each optional tool module whose binary is available in `PATH` on `KakBegin`, activating its keybindings via `ModuleLoaded`.

## Layout

```text
.
├── kakrc                              # Entry point; sources modules + .kakrc.local
├── conf/
│   ├── options.kak                    # Colorscheme, UI, highlighters, soft-tabs (respects Go/Make), completion
│   ├── windowing.kak                  # Sets windowing_modules + terminal-agnostic splits & :ide
│   ├── windowing/
│   │   ├── windows-terminal.kak       # provide-module windows-terminal (WSL 2 + wt.exe)
│   │   └── kitty.kak                  # ModuleLoaded kitty (extends built-in kitty with vsplit/hsplit/overlay)
│   ├── clipboard.kak                  # clipboard_modules detector + shared clipboard-register helper
│   ├── clipboard/
│   │   ├── wsl.kak                    # provide-module clipboard-wsl (win32yank.exe / clip.exe + powershell.exe)
│   │   ├── macos.kak                  # provide-module clipboard-macos (pbcopy / pbpaste)
│   │   ├── wayland.kak                # provide-module clipboard-wayland (wl-copy / wl-paste)
│   │   ├── x11.kak                    # provide-module clipboard-x11 (xclip / xsel)
│   │   └── kitty.kak                  # provide-module clipboard-kitty (kitten clipboard)
│   ├── tools.kak                      # tool_modules loader + file_finder_cmd detection (fd/fdfind/find)
│   ├── tools/
│   │   ├── helpers.kak                # Always-available helpers: :find, :git-edit, :kakrc-edit, :config-edit
│   │   ├── yazi.kak                   # provide-module yazi
│   │   └── fzf.kak                    # provide-module fzf (files, git files, buffers, live rg)
│   ├── lsp.kak                        # provide-module lsp-config (kak-lsp, formatting, semantic tokens, Python)
│   └── mappings.kak                   # Centralized mappings + ModuleLoaded hooks for yazi, fzf, lsp-config
└── colors/
    └── catppuccin_mocha.kak           # Catppuccin Mocha colorscheme
```

## Platform Setup

### Linux / macOS — Kitty

Kakoune's built-in `kitty` module (extended by [conf/windowing/kitty.kak](conf/windowing/kitty.kak)) uses Kitty remote control for native splits, overlays (`yazi`/`fzf`), tabs, and client focusing (`:focus` / `:ide`). Add to `~/.config/kitty/kitty.conf`:

```conf
allow_remote_control socket-only
listen_on unix:/tmp/kitty
enabled_layouts splits,tall,stack
```

### Windows — WSL 2 + Windows Terminal

- Run WSL 2 inside **Windows Terminal** (`windows-terminal` detects `$WSL_DISTRO_NAME` and `wt.exe` automatically).
- Splits, tabs, and popups open as native Windows Terminal panes/tabs while preserving `PATH`, `XDG_RUNTIME_DIR`, `TMPDIR`, and the working directory.
- For fast clipboard yank/paste, install [`win32yank.exe`](https://github.com/equalsraf/win32yank) on your Windows `PATH` (`clipboard-wsl` falls back to `clip.exe` / `powershell.exe` otherwise).

### Recommended CLI Tools

- [`yazi`](https://yazi-rs.github.io/) — terminal file manager (`<space>pv`, `<space>pV`)
- [`fzf`](https://github.com/junegunn/fzf) — fuzzy picker (`<space>pf`, `<space>pF`, `<space>pg`, `<space>pb`, `<space>b`)
- [`fd`](https://github.com/sharkdp/fd) (or `fdfind` on Ubuntu/Debian) — fast file listing
- [`rg`](https://github.com/BurntSushi/ripgrep) — fast grep (`:grep`, `<space>pg`)
- [`kak-lsp`](https://github.com/kakoune-lsp/kakoune-lsp) — LSP client (skipped cleanly if not installed)

### Yazi Splits & Tabs Setup (`~/.config/yazi/`)

`yazi.kak` exposes `KAK_YAZI_ACTION_FILE` to Yazi so you can multi-select files with `<Space>` and pick how to open them right inside Yazi.

1. Create a small synchronous plugin at `~/.config/yazi/plugins/kak-open.yazi/main.lua` (a `shell` command in a `run = [...]` array runs asynchronously and races with `open`, whereas `--- @sync entry` writes the action before `open` exits Yazi):

```lua
--- @sync entry

return {
	entry = function(_, job)
		local action = (job.args and job.args[1]) or job[1]
		local path = os.getenv("KAK_YAZI_ACTION_FILE")
		if path and path ~= "" and action and action ~= "" then
			local f = io.open(path, "w")
			if f then
				f:write(action)
				f:close()
			end
		end
		local emit = ya.emit or ya.mgr_emit or ya.manager_emit
		emit("open", {})
	end,
}
```

2. Add the keybindings to `~/.config/yazi/keymap.toml` (for Yazi < v25, use `[[manager.prepend_keymap]]`):

```toml
[[mgr.prepend_keymap]]
on   = "<C-v>"
run  = "plugin kak-open -- vertical"
desc = "Open selected file(s) in Kakoune vertical split"

[[mgr.prepend_keymap]]
on   = "<C-x>"
run  = "plugin kak-open -- horizontal"
desc = "Open selected file(s) in Kakoune horizontal split"

[[mgr.prepend_keymap]]
on   = "<C-t>"
run  = "plugin kak-open -- tab"
desc = "Open selected file(s) in Kakoune tab(s)"
```

*(You can also invoke `:yazi-vertical`, `:yazi-horizontal`, or `:yazi-tab` directly from Kakoune without modifying Yazi's config.)*

### Per-Project / Machine Overrides (`.kakrc.local`)

Because module detection runs on `KakBegin` (after `.kakrc.local` is sourced), you can override any module list per project or machine:

```kak
# Disable LSP in a specific repo
set-option global tool_modules 'yazi' 'fzf'

# Force Kitty OSC 52 clipboard (e.g. over SSH)
set-option global clipboard_modules 'clipboard-kitty'

# Customize file finder command
set-option global file_finder_cmd 'fd --hidden --exclude .git --type f'
```

> **Portability note on `autoload/`:** If `autoload/autoload` points to a machine-specific path (e.g. a local source build), either remove the `autoload/` directory on other machines so Kakoune uses its built-in runtime autoload, or update the symlink to match that machine's Kakoune runtime directory.

## Keybindings

### User Mode (`<space>`)

| Key | Action |
| --- | --- |
| `<space>p` | Enter **project / picker** mode |
| `<space>b` | Switch buffer (`fzf`) |
| `<space>c` | Toggle line comments |
| `<space>o` | Open alternate file (`:alt`) |
| `<space>y` | Yank selection to system clipboard |
| `<space>v` / `<space>V` | Paste after / before from system clipboard |
| `<space>R` | Replace selection from system clipboard |
| `<space>w` | Enter **window / split** mode |
| `<space>l` | Enter **LSP** mode |

### Project Mode (`<space>p`)

| Key | Action |
| --- | --- |
| `f` | Find files (`fzf` + `file_finder_cmd`, multi-select; `:find` fallback) |
| `F` | Find git-tracked files (`fzf`, multi-select) |
| `g` | Live search project (`rg` + `fzf`; `:grep` fallback) |
| `v` | Open **Yazi** at current file (or cwd) |
| `V` | Open **Yazi** at cwd |
| `b` | Switch buffer (`fzf`) |

### Window Mode (`<space>w`)

| Key | Action |
| --- | --- |
| `v` / `h` | New Kakoune client in vertical / horizontal split |
| `t` | New Kakoune client in new terminal tab |
| `n` | New Kakoune client (auto split) |
| `s` / `S` | New shell in vertical / horizontal split |
| `i` | Set up IDE layout (`main` + `tools` clients) |

### Goto Mode (`g`)

| Key | Action |
| --- | --- |
| `gN` / `gP` | Next / previous buffer |
| `gb` | Switch buffer prompt |
| `gn` / `gp` | Next / previous grep match |
| `gd` / `gr` / `gy` | LSP definition / references / type definition |
| `go` / `gO` | LSP next / previous error |
