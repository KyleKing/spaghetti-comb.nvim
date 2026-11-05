#!/usr/bin/env bash
# Shared helpers for the integration scenarios. Source this file.
# Counters: ITEST_PASS / ITEST_FAIL accumulate across check calls.

ITEST_PASS=0
ITEST_FAIL=0
ITEST_ARTIFACTS="${SC_PLUGIN_ROOT:-.}/tests/itest/artifacts"

check() { # check <name> <ok:0|1> [detail]
    local name="$1" ok="$2" detail="${3:-}"
    if [ "$ok" -eq 0 ]; then
        ITEST_PASS=$((ITEST_PASS + 1))
        printf 'ok   %s\n' "$name"
    else
        ITEST_FAIL=$((ITEST_FAIL + 1))
        printf 'FAIL %s%s\n' "$name" "${detail:+ — $detail}"
    fi
}

check_contains() { # check_contains <name> <haystack> <needle>
    case "$2" in
        *"$3"*) check "$1" 0 ;;
        *) check "$1" 1 "missing '$3'" ;;
    esac
}

check_not_contains() { # check_not_contains <name> <haystack> <needle>
    case "$2" in
        *"$3"*) check "$1" 1 "unexpected '$3'" ;;
        *) check "$1" 0 ;;
    esac
}

itest_summary() {
    printf '\n%d passed, %d failed\n' "$ITEST_PASS" "$ITEST_FAIL"
    [ "$ITEST_FAIL" -eq 0 ]
}

# --- tmux PTY helpers ------------------------------------------------------
# A dedicated socket keeps the session off the user's own tmux server.
TMUX_SOCK="scitest"
TMUX_SESSION="itest"

tmux_itest() { tmux -L "$TMUX_SOCK" "$@"; }

# nvim_start <cwd> [file] — boot nvim at 100x30 with the itest init.
nvim_start() {
    tmux_itest kill-session -t "$TMUX_SESSION" 2>/dev/null || true
    tmux_itest new-session -d -s "$TMUX_SESSION" -x 100 -y 30 \
        -c "$1" "nvim -u '$SC_PLUGIN_ROOT/tests/itest/init.lua' ${2:-}"
}

pane_text() { tmux_itest capture-pane -p -t "$TMUX_SESSION"; }

# wait_pane <needle> [timeout_s] — poll the pane until needle appears.
wait_pane() {
    local needle="$1" timeout="${2:-30}" i=0
    while [ "$i" -lt "$timeout" ]; do
        case "$(pane_text)" in
            *"$needle"*) return 0 ;;
        esac
        sleep 1
        i=$((i + 1))
    done
    return 1
}

send() { tmux_itest send-keys -t "$TMUX_SESSION" "$@"; }
send_lit() { tmux_itest send-keys -l -t "$TMUX_SESSION" "$1"; }

save_frame() { # save_frame <name> — persist the pane as a review artifact
    mkdir -p "$ITEST_ARTIFACTS"
    tmux_itest capture-pane -p -e -t "$TMUX_SESSION" >"$ITEST_ARTIFACTS/$1.ansi"
    pane_text >"$ITEST_ARTIFACTS/$1.txt"
}

nvim_stop() { tmux_itest kill-session -t "$TMUX_SESSION" 2>/dev/null || true; }
