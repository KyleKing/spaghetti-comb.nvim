#!/usr/bin/env bash
# Integration test entry point. Ensures the pinned fixture (flask @ 3.1.3,
# cloned into tests/itest/.fixture/, indexed by vera-ai and codanna), then
# runs the CLI contract and, when tmux is available, the PTY scenarios.
#
#   bash tests/itest/run.sh            # fixture + cli + pty
#   SC_SKIP_PTY=1 bash tests/itest/run.sh   # headless layers only
#
# Tools required: nvim, jq, vera-ai; optional: tmux, codanna, codanna.nvim
# (sibling checkout or SC_CODANNA_NVIM env var).
set -uo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

missing=""
for tool in nvim jq vera-ai git; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
    echo "missing required tools:$missing" >&2
    exit 2
fi

bash "$HERE/fixture.sh" || exit 2

fail=0
bash "$HERE/cli.sh" || fail=1

if [ "${SC_SKIP_PTY:-0}" != "1" ] && command -v tmux >/dev/null 2>&1; then
    bash "$HERE/pty.sh" || fail=1
else
    echo "pty scenarios skipped (SC_SKIP_PTY set or tmux missing)"
fi

exit "$fail"
