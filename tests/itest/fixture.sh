#!/usr/bin/env bash
# Clone the pinned fixture repo and build its Vera and codanna indexes.
# Idempotent: a .itest-ready marker keyed on the pinned SHA and tool
# versions skips all work on re-runs. Delete the clone to start over.
#
# Env:
#   SC_FIXTURE_DIR  clone location (default: tests/itest/.fixture/flask).
#                   Point at a persistent dir to reuse indexes across runs
#                   or machines (the whole dir is the CI cache unit).
#   SC_SKIP_INDEX=1 clone/checkout only; do not run vera or codanna.
set -euo pipefail

FLASK_REPO="https://github.com/pallets/flask.git"
FLASK_SHA="22d924701a6ae2e4cd01e9a15bbaf3946094af65" # tag 3.1.3

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="${SC_FIXTURE_DIR:-$HERE/.fixture/flask}"
MARKER="$FIXTURE/.itest-ready"

tool_versions() {
    local vera_v codanna_v
    vera_v="$(vera-ai --version 2>/dev/null || echo missing)"
    codanna_v="$(codanna --version 2>/dev/null || echo missing)"
    echo "$FLASK_SHA|$vera_v|$codanna_v"
}

if [ -f "$MARKER" ] && [ "$(cat "$MARKER")" = "$(tool_versions)" ]; then
    echo "fixture ready: $FIXTURE"
    exit 0
fi

if [ -d "$FIXTURE" ]; then
    head="$(git -C "$FIXTURE" rev-parse HEAD 2>/dev/null || echo none)"
    if [ "$head" != "$FLASK_SHA" ]; then
        echo "fixture at wrong revision ($head), re-cloning"
        rm -rf "$FIXTURE"
    fi
fi

if [ ! -d "$FIXTURE" ]; then
    mkdir -p "$(dirname "$FIXTURE")"
    git clone --filter=blob:none "$FLASK_REPO" "$FIXTURE"
    git -C "$FIXTURE" checkout --quiet "$FLASK_SHA"
fi

if [ "${SC_SKIP_INDEX:-0}" != "1" ]; then
    echo "vera-ai index (one-off; watch mode is not used in tests)"
    (cd "$FIXTURE" && vera-ai index . --quiet 2>/dev/null || vera-ai index .)
    echo "codanna init + index"
    (cd "$FIXTURE" && [ -d .codanna ] || codanna init)
    (cd "$FIXTURE" && codanna index . --no-progress)
fi

tool_versions >"$MARKER"
echo "fixture ready: $FIXTURE"
