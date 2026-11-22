## Code Review Module (git diff + custom `review` filetype)
#
# Shows the unified `git diff` (including untracked files) in a dedicated
# `*review*` buffer (`filetype=review`) in the `tools` drawer.
# Pressing `n`/`p` steps hunk-by-hunk in both the diff view and main client;
# pressing `<ret>` jumps to the exact file and line under the cursor and focuses main.

try %{
    provide-module -override review %{
        evaluate-commands %sh{
            command -v git >/dev/null 2>&1 || printf "fail 'review: git not found in PATH'\n"
        }

        try %{
            declare-option -docstring 'Git ref to diff working tree against in :review' \
                str review_base 'HEAD'
        }
        try %{ declare-option -hidden str review_repo_root '' }
        try %{ declare-option -hidden str review_diff_file '' }
        try %{ declare-option -hidden int review_current_line 0 }

        remove-hooks global review-filetype

        hook -group review-filetype global BufSetOption filetype=review %{
            require-module diff
            try %{ remove-highlighter buffer/review }
            add-highlighter buffer/review ref diff
            try %{ remove-highlighter buffer/review-line }
            add-highlighter buffer/review-line line '%opt{review_current_line}' MenuBackground

            map -docstring 'Jump to exact line in main client' buffer normal <ret> ': review-navigate here focus<ret>'
            map -docstring 'Preview exact line in main client' buffer normal o ': review-navigate here preview<ret>'
            map -docstring 'Next hunk (sync diff + main)' buffer normal n ': review-navigate next preview<ret>'
            map -docstring 'Previous hunk (sync diff + main)' buffer normal p ': review-navigate prev preview<ret>'
            map -docstring 'Refresh diff' buffer normal r ': review-refresh<ret>'
            map -docstring 'Close review drawer' buffer normal q ': tools-close<ret>'

            hook -once -always buffer BufSetOption filetype=.* %{
                try %{ remove-highlighter buffer/review }
                try %{ remove-highlighter buffer/review-line }
            }
        }

        hook -group review-filetype global KakEnd .* %{
            nop %sh{
                [ -n "$kak_opt_review_diff_file" ] && rm -f -- "$kak_opt_review_diff_file"
            }
        }

        define-command -override -hidden review-load-diff %{
            set-option buffer readonly false
            execute-keys -draft '%|cat -- "$kak_opt_review_diff_file"<ret>'
            set-option buffer readonly true
        }

        define-command -override -hidden -params 1 review-goto-row %{
            evaluate-commands %sh{
                if [ "$kak_bufname" = "*review*" ]; then
                    printf 'execute-keys %sgvt\n' "$1"
                fi
            }
        }

        define-command -override -hidden -params 1 review-populate %{
            evaluate-commands %sh{
                keep_cursor=$1
                repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
                [ -n "$repo_root" ] || { printf "fail 'review: not inside a git repository'\n"; exit 0; }

                base_ref="${kak_opt_review_base:-HEAD}"
                diff_ref="$base_ref"
                if ! git -C "$repo_root" rev-parse --verify "$base_ref" >/dev/null 2>&1; then
                    if [ "$base_ref" = "HEAD" ]; then
                        diff_ref=$(git -C "$repo_root" hash-object -t tree /dev/null)
                    else
                        esc_ref=$(printf '%s' "$base_ref" | sed "s/'/''/g")
                        printf "fail 'review: invalid git ref: %s'\n" "$esc_ref"
                        exit 0
                    fi
                fi

                diff_file="${kak_opt_review_diff_file}"
                if [ -z "$diff_file" ]; then
                    diff_file="${TMPDIR:-/tmp}/kak-review-${kak_session}.diff"
                fi

                {
                    printf '# Review vs %s  |  n/p: next/prev hunk  <ret>: jump  o: preview  r: refresh  q: close\n\n' "$base_ref"

                    git -C "$repo_root" -c core.quotepath=false -c diff.noprefix=false \
                        diff --no-color --no-ext-diff "$diff_ref" 2>/dev/null

                    git -C "$repo_root" -c core.quotepath=false ls-files --others --exclude-standard 2>/dev/null | \
                    while IFS= read -r uf; do
                        [ -n "$uf" ] && [ -f "$repo_root/$uf" ] || continue
                        git -C "$repo_root" -c core.quotepath=false -c diff.noprefix=false \
                            diff --no-index --no-color --no-ext-diff -- /dev/null "$uf" 2>/dev/null || true
                    done
                } > "$diff_file"

                if [ "$(wc -l < "$diff_file")" -le 2 ]; then
                    printf '# Working tree clean (no changes vs %s)\n' "$base_ref" >> "$diff_file"
                fi

                esc_root=$(printf '%s' "$repo_root" | sed "s/'/''/g")
                esc_diff=$(printf '%s' "$diff_file" | sed "s/'/''/g")
                printf "set-option global review_repo_root '%s'\n" "$esc_root"
                printf "set-option global review_diff_file '%s'\n" "$esc_diff"
                printf "edit -scratch *review*\n"
                printf "review-load-diff\n"
                printf "set-option buffer filetype review\n"
                if [ "$keep_cursor" = "0" ]; then
                    printf "set-option global review_current_line 0\n"
                    printf "execute-keys 1g\n"
                fi
            }
        }

        define-command -override -hidden -params 2 review-navigate %{
            evaluate-commands %sh{
                action=$1
                focus_mode=$2

                diff_file="$kak_opt_review_diff_file"
                if [ -z "$diff_file" ] || [ ! -r "$diff_file" ]; then
                    printf "fail 'review: no diff loaded (press <space>wr to open)'\n"
                    exit 0
                fi

                if [ "$kak_bufname" = "*review*" ]; then
                    cur_row="$kak_cursor_line"
                else
                    cur_row="${kak_opt_review_current_line:-0}"
                fi

                parsed=$(awk -v action="$action" -v cur_row="$cur_row" '
                /^diff --git / {
                    cur_file = ""; del_file = 0; in_hunk = 0; hdr = 1
                    next
                }
                hdr && /^\+\+\+ b\// {
                    cur_file = substr($0, 7)
                    sub(/\t$/, "", cur_file)
                    l_file[NR] = cur_file; l_num[NR] = 1
                    next
                }
                hdr && /^\+\+\+ \/dev\/null/ {
                    del_file = 1; cur_file = ""
                    next
                }
                /^@@ / {
                    hdr = 0
                    if (del_file || cur_file == "") { in_hunk = 0; next }
                    s = $0
                    sub(/^@@ [^+]+\+/, "", s)
                    start = s + 0
                    if (start < 1) start = 1
                    hunks++
                    h_row[hunks] = NR
                    h_file[hunks] = cur_file
                    h_line[hunks] = start
                    l_file[NR] = cur_file; l_num[NR] = start
                    in_hunk = 1
                    cur_line = start
                    next
                }
                in_hunk && /^ / {
                    l_file[NR] = cur_file; l_num[NR] = cur_line
                    cur_line++
                    next
                }
                in_hunk && /^\+/ {
                    if (!h_found[hunks]) { h_line[hunks] = cur_line; h_found[hunks] = 1 }
                    l_file[NR] = cur_file; l_num[NR] = cur_line
                    cur_line++
                    next
                }
                in_hunk && /^-/ {
                    if (!h_found[hunks]) { h_line[hunks] = cur_line; h_found[hunks] = 1 }
                    l_file[NR] = cur_file; l_num[NR] = cur_line
                    next
                }
                END {
                    if (action == "next") {
                        if (hunks == 0) exit 1
                        idx = 0
                        for (i = 1; i <= hunks; i++) {
                            if (h_row[i] > cur_row) { idx = i; break }
                        }
                        if (idx == 0) idx = 1
                        printf "%d\n%s\n%d\n%d\n%d\n", h_row[idx], h_file[idx], h_line[idx], idx, hunks
                    } else if (action == "prev") {
                        if (hunks == 0) exit 1
                        idx = 0
                        for (i = hunks; i >= 1; i--) {
                            if (h_row[i] < cur_row) { idx = i; break }
                        }
                        if (idx == 0) idx = hunks
                        printf "%d\n%s\n%d\n%d\n%d\n", h_row[idx], h_file[idx], h_line[idx], idx, hunks
                    } else {
                        if (l_file[cur_row] != "") {
                            printf "%d\n%s\n%d\n0\n%d\n", cur_row, l_file[cur_row], l_num[cur_row], hunks + 0
                        } else {
                            for (i = 1; i <= hunks; i++) {
                                if (h_row[i] >= cur_row) {
                                    printf "%d\n%s\n%d\n%d\n%d\n", h_row[i], h_file[i], h_line[i], i, hunks
                                    exit 0
                                }
                            }
                            exit 1
                        }
                    }
                }
                ' "$diff_file")

                if [ -z "$parsed" ]; then
                    printf "echo -markup '{Information}review: no hunks to jump to'\n"
                    exit 0
                fi

                row=$(printf '%s\n' "$parsed" | sed -n '1p')
                file=$(printf '%s\n' "$parsed" | sed -n '2p')
                lnum=$(printf '%s\n' "$parsed" | sed -n '3p')
                idx=$(printf '%s\n' "$parsed" | sed -n '4p')
                total=$(printf '%s\n' "$parsed" | sed -n '5p')

                repo_root="${kak_opt_review_repo_root:-$PWD}"
                target="$file"
                [ "$repo_root" != "$PWD" ] && target="$repo_root/$file"
                if [ ! -e "$target" ]; then
                    esc_file=$(printf '%s' "$file" | sed "s/'/''/g")
                    printf "fail 'review: file not found: %s'\n" "$esc_file"
                    exit 0
                fi

                # Resolve destination editing client
                dest=""
                if [ "$kak_client" != "tools" ]; then
                    dest="$kak_client"
                else
                    eval "set -- $kak_quoted_client_list"
                    if [ -n "$kak_opt_jumpclient" ] && [ "$kak_opt_jumpclient" != "tools" ]; then
                        for c in "$@"; do
                            if [ "$c" = "$kak_opt_jumpclient" ]; then
                                dest="$c"
                                break
                            fi
                        done
                    fi
                    if [ -z "$dest" ]; then
                        for c in "$@"; do
                            if [ "$c" != "tools" ]; then
                                dest="$c"
                                break
                            fi
                        done
                    fi
                fi

                esc_target=$(printf '%s' "$target" | sed "s/'/''/g")
                esc_file=$(printf '%s' "$file" | sed "s/'/''/g")

                printf "set-option global review_current_line %s\n" "$row"
                printf "try %%{ evaluate-commands -client tools 'review-goto-row %s' }\n" "$row"

                if [ -n "$dest" ]; then
                    esc_dest=$(printf '%s' "$dest" | sed "s/'/''/g")
                    if [ "$dest" != "$kak_opt_jumpclient" ]; then
                        printf "set-option global jumpclient '%s'\n" "$esc_dest"
                    fi
                    printf "evaluate-commands -client '%s' %%{ edit -- '%s' %s; execute-keys vv }\n" \
                        "$esc_dest" "$esc_target" "$lnum"
                    if [ "$focus_mode" = "focus" ]; then
                        printf "try %%{ focus '%s' }\n" "$esc_dest"
                    fi
                else
                    printf "edit -- '%s' %s; execute-keys vv\n" "$esc_target" "$lnum"
                fi

                if [ "$idx" -gt 0 ]; then
                    printf "echo 'review: hunk %s/%s (%s:%s)'\n" "$idx" "$total" "$esc_file" "$lnum"
                else
                    printf "echo 'review: %s:%s'\n" "$esc_file" "$lnum"
                fi
            }
        }

        define-command -override -docstring 'Jump to the next diff hunk in both diff view and main client' review-next %{
            review-navigate next focus
        }

        define-command -override -docstring 'Jump to the previous diff hunk in both diff view and main client' review-prev %{
            review-navigate prev focus
        }

        define-command -override -docstring 'Refresh the *review* diff and git diff gutter' review-refresh %{
            try %{ evaluate-commands -client tools %{ review-populate 1 } } catch %{ review-populate 1 }
            try %{ evaluate-commands -client %opt{jumpclient} %{ try %{ git update-diff } } }
        }

        define-command -override -params ..1 \
            -shell-script-candidates %{
                git for-each-ref --format='%(refname:short)' refs/heads refs/remotes refs/tags 2>/dev/null
                printf 'HEAD\nHEAD~1\nHEAD~2\nHEAD~3\n'
            } \
            -docstring 'review [<base-ref>]: open git diff review drawer against <base-ref> (default: HEAD)' \
            review %{
            evaluate-commands %sh{
                base_ref="${1:-HEAD}"
                repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
                [ -n "$repo_root" ] || { printf "fail 'review: not inside a git repository'\n"; exit 0; }
                if [ "$base_ref" != "HEAD" ] && ! git -C "$repo_root" rev-parse --verify "$base_ref" >/dev/null 2>&1; then
                    esc_ref=$(printf '%s' "$base_ref" | sed "s/'/''/g")
                    printf "fail 'review: invalid git ref: %s'\n" "$esc_ref"
                    exit 0
                fi
                esc_ref=$(printf '%s' "$base_ref" | sed "s/'/''/g")
                printf "set-option global review_base '%s'\n" "$esc_ref"
                printf "tools-open 'review-populate 0'\n"
            }
        }

        define-command -override -hidden review-toggle-in-tools %{
            evaluate-commands %sh{
                case "$kak_bufname" in
                    '*review*') printf "tools-close\n" ;;
                    *) printf "set-option global review_base 'HEAD'\nreview-populate 0\ntry %%{ focus tools }\n" ;;
                esac
            }
        }

        define-command -override -docstring 'Toggle the vertical git diff review drawer' review-toggle %{
            try %{
                evaluate-commands -client tools nop
                evaluate-commands %sh{
                    if [ "$kak_client" != "tools" ]; then
                        esc=$(printf '%s' "$kak_client" | sed "s/'/''/g")
                        printf "set-option global jumpclient '%s'\n" "$esc"
                    fi
                }
                evaluate-commands -client tools review-toggle-in-tools
            } catch %{
                review
            }
        }
    }
}
