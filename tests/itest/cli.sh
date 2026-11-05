#!/usr/bin/env bash
# CLI contract checks: scripts/sc against the real indexed fixture.
# Covers the agent-facing DX layer — JSON shape, error paths, exit codes.
# Requires: jq, vera-ai; codanna checks need the codanna binary only
# (scripts/sc stubs the codanna.nvim core itself).
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SC_PLUGIN_ROOT="$(cd "$HERE/../.." && pwd)"
export SC_PLUGIN_ROOT
# shellcheck source=lib.sh
. "$HERE/lib.sh"

SC="$SC_PLUGIN_ROOT/scripts/sc"
FIXTURE="${SC_FIXTURE_DIR:-$HERE/.fixture/flask}"

# Throwaway data dir so the CLI never touches real user state.
export XDG_DATA_HOME
XDG_DATA_HOME="$(mktemp -d)"
trap 'rm -rf "$XDG_DATA_HOME"' EXIT

cd "$FIXTURE"

# --- happy-path JSON contract ---------------------------------------------
out="$("$SC" status 2>/dev/null)" && rc=$? || rc=$?
check "sc status exits 0" "$rc" "$out"
echo "$out" | jq -e '.vera' >/dev/null 2>&1; check "sc status has vera health" "$?" "$out"
echo "$out" | jq -e '.codanna' >/dev/null 2>&1; check "sc status has codanna health" "$?" "$out"

out="$("$SC" seek session signing 2>/dev/null)" && rc=$? || rc=$?
check "sc seek exits 0" "$rc"
echo "$out" | jq -e 'length > 0' >/dev/null 2>&1; check "sc seek returns hits" "$?" "$out"
echo "$out" | jq -e '.[0].file_path' >/dev/null 2>&1; check "sc seek hits carry file_path" "$?" "$out"
echo "$out" | jq -r '.[].file_path' | grep -q 'sessions\.py$'
check "sc seek finds sessions.py" "$?" "$(echo "$out" | jq -r '.[].file_path' | head -5)"

out="$("$SC" related src/flask/sessions.py 95 115 2>/dev/null)" && rc=$? || rc=$?
check "sc related exits 0" "$rc"
echo "$out" | jq -e 'length > 0' >/dev/null 2>&1; check "sc related returns hits" "$?" "$out"

out="$("$SC" orient 2>/dev/null)" && rc=$? || rc=$?
check "sc orient exits 0" "$rc"
echo "$out" | jq -e '.groups | length >= 3' >/dev/null 2>&1; check "sc orient returns groups" "$?" "$out"
echo "$out" | jq -r '.groups[].label' | grep -qx 'Routes'; check "sc orient has Routes group" "$?" "$out"
echo "$out" | jq -r '.root.name' | grep -q 'symbols'; check "sc orient root carries index stats" "$?" "$out"

# codanna-backed verbs — exercised whenever the binary is installed.
if command -v codanna >/dev/null 2>&1; then
    out="$("$SC" callers wsgi_app 2>/dev/null)" && rc=$? || rc=$?
    check "sc callers wsgi_app exits 0" "$rc" "$out"
    echo "$out" | jq -e 'length > 0' >/dev/null 2>&1
    check "sc callers wsgi_app returns call sites" "$?" "$out"
    echo "$out" | jq -r '.[].name' | grep -q '__call__'
    check "sc callers wsgi_app finds __call__" "$?" "$out"

    # url_for is ambiguous in flask (Function + Method); the error must carry
    # actionable symbol_id candidates, not just "ambiguous".
    out="$("$SC" callers url_for 2>&1 >/dev/null)" && rc=$? || rc=$?
    [ "$rc" -ne 0 ] && check "sc callers ambiguous symbol fails" 0 || check "sc callers ambiguous symbol fails" 1
    check_contains "sc ambiguous error carries symbol_id candidates" "$out" "symbol_id:"

    out="$("$SC" callers __definitely_not_a_symbol__ 2>&1 >/dev/null)" && rc=$? || rc=$?
    [ "$rc" -ne 0 ] && check "sc callers unknown symbol fails" 0 || check "sc callers unknown symbol fails" 1 "$out"
fi

# --- error contract --------------------------------------------------------
out="$("$SC" 2>&1 >/dev/null)" && rc=$? || rc=$?
[ "$rc" -ne 0 ] && check "sc bare fails" 0 || check "sc bare fails" 1
check_contains "sc bare prints usage" "$out" "usage: sc"

out="$("$SC" frobnicate 2>&1 >/dev/null)" && rc=$? || rc=$?
[ "$rc" -ne 0 ] && check "sc unknown verb fails" 0 || check "sc unknown verb fails" 1
check_contains "sc unknown verb says so" "$out" "unknown verb"

out="$("$SC" related src/flask/sessions.py x y 2>&1 >/dev/null)" && rc=$? || rc=$?
[ "$rc" -ne 0 ] && check "sc related non-numeric lines fails" 0 || check "sc related non-numeric lines fails" 1

# Unindexed directory: seek must fail loudly, never return silent empties.
UNINDEXED="$(mktemp -d)"
out="$(cd "$UNINDEXED" && "$SC" seek anything 2>&1 >/dev/null)" && rc=$? || rc=$?
[ "$rc" -ne 0 ] && check "sc seek in unindexed dir fails" 0 || check "sc seek in unindexed dir fails" 1
rm -rf "$UNINDEXED"

itest_summary
