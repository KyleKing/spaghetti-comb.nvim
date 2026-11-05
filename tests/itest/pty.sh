#!/usr/bin/env bash
# PTY scenarios: a real nvim TUI in tmux against the indexed fixture.
# Asserts on rendered pane text; full frames are saved to
# tests/itest/artifacts/ (gitignored) as the review "screenshots".
# Requires: tmux, vera-ai. Relations scenarios additionally need the
# codanna binary and a codanna.nvim checkout (sibling dir or SC_CODANNA_NVIM).
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SC_PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
export SC_PLUGIN_ROOT
# shellcheck source=lib.sh
. "$HERE/lib.sh"

FIXTURE="${SC_FIXTURE_DIR:-$HERE/.fixture/flask}"

# Throwaway data dir so trail persistence never touches real user state.
export XDG_DATA_HOME
XDG_DATA_HOME="$(mktemp -d)"
trap 'nvim_stop; rm -rf "$XDG_DATA_HOME"' EXIT

HAS_CODANNA=0
if command -v codanna >/dev/null 2>&1 &&
    { [ -n "${SC_CODANNA_NVIM:-}" ] || [ -f "$SC_PLUGIN_ROOT/../codanna.nvim/lua/codanna/core.lua" ]; }
then
    HAS_CODANNA=1
fi
[ "$HAS_CODANNA" -eq 0 ] && echo "note: codanna.nvim/binary absent — relations scenarios skipped"

# --- seek: picker opens on real Vera hits, <CR> jumps into the target window -
nvim_start "$FIXTURE" src/flask/sessions.py
wait_pane "sessions.py" 10
send_lit ":SpaghettiCombSeek session signing"
send Enter
if wait_pane "Seek: session signing" 90; then check "seek picker lists vera hits" 0; else check "seek picker lists vera hits" 1 "$(pane_text | tail -5)"; fi
save_frame seek_picker
# Choose the first hit — the jump must land in the target window, not in the
# picker's doomed one (the 323-line open_session hit is ranked first).
send Enter
if wait_pane "323,1" 15; then check "seek choice jumps to hit line" 0; else check "seek choice jumps to hit line" 1 "$(pane_text | tail -5)"; fi
save_frame seek_after_choose
nvim_stop

# --- related: query-by-example from the current line -----------------------
nvim_start "$FIXTURE" src/flask/sessions.py
send_lit ":call cursor(100, 1)"
send Enter
send_lit ":SpaghettiCombRelated"
send Enter
if wait_pane "Related implementations" 90; then check "related picker opens" 0; else check "related picker opens" 1 "$(pane_text | tail -5)"; fi
save_frame related_picker
send Enter
sleep 3
check_not_contains "related picker closed after choose" "$(pane_text)" "Related implementations"
check_not_contains "related choose raised no error" "$(pane_text)" "Error during choose"
save_frame related_after_choose
nvim_stop

# --- orient: project map renders grouped sections --------------------------
nvim_start "$FIXTURE" src/flask/sessions.py
send_lit ":SpaghettiCombOrient"
send Enter
if wait_pane "flask —" 90; then
    check "orient tree opens" 0
else
    check "orient tree opens" 1 "$(pane_text | tail -5)"
fi
check_contains "orient shows Routes group" "$(pane_text)" "Routes"
save_frame orient_tree
send q
sleep 1
check_not_contains "orient q closes tree" "$(pane_text)" "Routes"
nvim_stop

# --- callers: relations tree renders, re-roots, quits ----------------------
if [ "$HAS_CODANNA" -eq 1 ]; then
    # Explicit symbol arg: flask@3.1.3 wsgi_app has exactly one verified
    # caller (__call__, app.py:1536). Pinned fixture keeps this stable.
    nvim_start "$FIXTURE" src/flask/app.py
    send_lit ":SpaghettiCombCallers wsgi_app"
    send Enter
    if wait_pane "Callers: wsgi_app" 60; then
        check "callers tree opens" 0
    else
        check "callers tree opens" 1 "$(pane_text | tail -5)"
    fi
    check_contains "callers tree shows __call__" "$(pane_text)" "__call__"
    save_frame callers_tree
    # <CR> on the __call__ item jumps to the call site (app.py:1536)
    send Enter
    if wait_pane "1536" 15; then
        check "callers jump lands at call site" 0
    else
        check "callers jump lands at call site" 1 "$(pane_text | tail -5)"
    fi
    save_frame callers_after_jump
    # Re-open and <C-]> re-root on __call__: flask has no internal callers of
    # __call__ (the WSGI server calls it), so the adapter reports no callers.
    # Escape first — a pending hit-enter prompt would swallow the command line.
    send Escape
    send_lit ":SpaghettiCombCallers wsgi_app"
    send Enter
    if wait_pane "Callers: wsgi_app" 60; then
        check "callers tree reopens" 0
    else
        check "callers tree reopens" 1 "$(pane_text | tail -5)"
    fi
    send C-]
    if wait_pane "no callers for '__call__'" 30; then
        check "C-] re-roots and reports empty" 0
    else
        check "C-] re-roots and reports empty" 1 "$(pane_text | tail -5)"
    fi
    send q
    sleep 1
    nvim_stop
fi

# --- history: content search filters, <C-o> widens to codebase -------------
# Seed one vera_seek entry in this nvim instance, then filter the history
# picker by text that only exists in the recorded context (function/snippet),
# then widen the same query into a codebase search.
nvim_start "$FIXTURE" src/flask/sessions.py
send_lit ":SpaghettiCombSeek session signing"
send Enter
wait_pane "Seek: session signing" 90
send Enter
wait_pane "323,1" 15
send_lit ":SpaghettiCombHistory"
send Enter
wait_pane "Navigation History" 15
# "open_session" lives in the entry's recorded context (function_name) but
# the display row only shows "sessions.py:323 (vera_seek)" — matching proves
# the search text covers recorded context, not just the filename.
send_lit "open_session"
sleep 2
check_contains "history filters by recorded context" "$(pane_text)" "vera_seek"
send C-o
if wait_pane "— open_session" 90; then
    check "C-o widens history query to codebase" 0
else
    check "C-o widens history query to codebase" 1 "$(pane_text | tail -5)"
fi
save_frame history_widen
send Escape
nvim_stop

# --- unindexed dir: seek fails loudly, not silently ------------------------
EMPTY="$(mktemp -d)"
nvim_start "$EMPTY"
send_lit ":SpaghettiCombSeek anything"
send Enter
sleep 8
frame="$(pane_text)"
case "$frame" in
    *"index"*|*"vera"*|*"Index"*|*"not found"*|*"error"*|*"Error"*)
        check "unindexed seek surfaces an error" 0 ;;
    *) check "unindexed seek surfaces an error" 1 "$(echo "$frame" | tail -5)" ;;
esac
save_frame unindexed_seek
send Escape
nvim_stop
rm -rf "$EMPTY"

itest_summary
