# Fixing the CursorMoved/BufEnter hang in navigation/lsp.lua

## Problem

Running the full test suite in `.config/nvim` (a separate repo that loads this plugin locally) pins the CPU at 100% partway through and never recovers. Bisecting by removing autocmd groups isolated it to `SpaghettiCombLsp`, the group `navigation/lsp.lua:setup_lsp_autocmds` creates. Its `CursorMoved`/`BufEnter` handler, `handle_cursor_movement`, calls `history_manager.record_jump` whenever the cursor moves far enough or the buffer changes, and `record_jump` calls `project_utils.detect_project_root(to_location.file_path)` on every such call.

`detect_project_root` caches by exact file path (`utils/project.lua:78`), so it only helps when the same buffer is revisited. Two things break down under heavy churn:

- Terminal buffers (`term://...`) and per-test scratch/temp files each get a unique name, so the cache never hits for them, and every one triggers a fresh upward filesystem walk checking a dozen marker names per directory level.
- The cache itself never evicts, so a long session (or test run) that touches thousands of distinct paths keeps growing it, though that's a memory concern, not the CPU one.

The `.config/nvim` test suite spawns many real `termopen` shells and temp-file buffers in a row without cleaning them up between specs, and each cursor move across that pile becomes a synchronous filesystem walk with no yield back to the event loop. That reads as a hang because nothing else can run while it's in progress, but it's better described as an unbounded amount of synchronous work triggered by an event that fires constantly.

Worth noting separately: `navigation/events.lua` already does a debounced version of the same job (`on_cursor_moved`, `SpaghettiCombNavigation` group, `vim.fn.timer_start` with a 100ms `jump_debounce_ms`) and also calls into `history_manager`. `navigation/lsp.lua`'s cursor tracking looks like an independent, older heuristic for guessing whether a jump came from LSP, not something the LSP request-interception path (`hook_lsp_requests`) depends on. The two systems appear to duplicate jump detection rather than share it.

## Options

### A. Debounce `handle_cursor_movement` the way `events.lua` already does

Mirror `on_cursor_moved`: cancel and restart a `vim.fn.timer_start(jump_debounce_ms, ...)` timer on each `CursorMoved`/`BufEnter` instead of calling `record_jump` synchronously inline.

Cuts the *frequency* of calls sharply (one per debounce window instead of one per event), but does nothing about the per-call cost. A single slow filesystem walk still runs to completion once the timer fires, and rapid legitimate navigation (jumping between many distinct real files in a short window) still pays for cache misses in the same way. This is the smallest change and matches existing project convention, but treats the symptom, not the cache-effectiveness problem.

### B. Fix the cache so it actually covers this workload

Two independent improvements, either alone or together:

- Normalize the cache key to the *containing directory*, not the raw `file_path`. Right now the cache is keyed on the exact file, so two files in the same directory both walk the filesystem independently even though they'd resolve to the same root. Keying on `dirname(file_path)` (or better, caching per-directory during the walk itself, the way many "find project root" implementations memoize every directory visited, not just the starting one) would make revisits to the same *directory* free, which covers "many temp files in one tmpdir" and "many buffers in one project" far better than exact-path keying does.
- Short-circuit paths that can't have a real project root before touching the filesystem at all: empty string, and non-file schemes like `term://`, `fugitive://`, or other URI-shaped buffer names Neovim buffer name should be checked with something like `file_path:match("^%w+://")` and skipped (falling back to `vim.fn.getcwd()` or returning nil), since a filesystem walk starting from a synthetic path is doing wasted work chasing something that was never going to resolve into a real marker file.

This fixes the actual root cause (the cache not covering the access pattern) rather than reducing how often the code path runs. It's more code and slightly changes `detect_project_root`'s behavior for callers who rely on it walking synthetic paths today (unlikely, but worth a grep before changing). Combine with Option A for defense in depth, since debouncing and a better cache address different failure modes (call frequency vs. per-call cost).

### C. Skip loading in headless/test environments

`AGENTS.md` in `.config/nvim` already documents skipping some plugins entirely when Neovim runs headless. The `.config/nvim` side could add spaghetti-comb.nvim (or just its `navigation/lsp.lua` autocmds) to that list, since a WIP personal plugin's navigation history has no reason to run during a CI or test invocation.

Simplest possible fix, and it's arguably correct regardless of whether A/B happen too, since navigation history tracking during a test run is never wanted output. But it's a workaround scoped to `.config/nvim`, not a fix to the plugin, and it wouldn't protect a *real* editing session from the same slowdown if someone opens enough terminals and temp buffers by hand. It belongs alongside a real fix, not instead of one.

### D. Remove the duplicate heuristic instead of hardening it

If `navigation/lsp.lua`'s cursor-based jump guessing was meant as a stand-in before `hook_lsp_requests` existed, and `events.lua`'s debounced, better-thresholded (`MIN_LINE_DISTANCE`/`MIN_COL_DISTANCE` are configurable state there, vs. hardcoded `> 5`/`> 20` in `lsp.lua`) implementation already covers "record a jump when the cursor moves significantly," then `handle_cursor_movement` and its `CursorMoved`/`BufEnter` autocmd may be dead weight that duplicates `events.lua`'s job less carefully. Removing it (keeping only `LspAttach` + `hook_lsp_requests` in `navigation/lsp.lua` for genuine LSP-triggered jumps, and letting `events.lua` own all generic cursor-jump detection) would delete the bug rather than patch it.

This is a bigger, riskier change: it requires confirming nothing else depends on `handle_cursor_movement`'s specific detection (e.g., its jump_type of `"lsp_jump"` vs. `events.lua`'s `"manual"`, if anything downstream branches on that), and probably needs its own test-suite pass. Right sizing for a dedicated cleanup task, not a quick hang fix, but worth flagging now since fixing the cache (Option B) on code that may be redundant is wasted effort if D happens later anyway.

## Recommendation

A + B together: debounce `handle_cursor_movement` (small, matches existing convention, cheap insurance) and fix the cache to key on directory plus short-circuit non-file buffer names (fixes the actual gap that let this happen). Do C in `.config/nvim` regardless, since test/headless runs have no business paying for navigation history at all. Treat D as a follow-up ROADMAP item once someone has time to verify `handle_cursor_movement` is truly redundant with `events.lua`, rather than folding it into this fix.

## Status

A + B implemented in `navigation/lsp.lua` (debounced `record_jump` call via a timer keyed to `jump_debounce_ms`) and `utils/project.lua` (directory-keyed cache, `^%w+://` short-circuit). Verified against the full `spaghetti-comb.nvim` test suite (98 cases, 0 fails, matching pre-change baseline).

C was attempted and rolled back. Skipping the whole plugin load in `.config/nvim`'s headless guard broke its `spaghetti_comb_spec.lua`, which `require()`s spaghetti-comb modules directly. A narrower fix (a config flag to disable just `navigation/lsp.lua`'s `CursorMoved`/`BufEnter` autocmd) was tried next, but a diagnostic run of `.config/nvim`'s full CI suite showed the actual hang there is a *different* problem: it persists even with both `navigation/lsp.lua`'s and `events.lua`'s `CursorMoved`/`BufEnter` autocmds disabled, hanging at the same point (entering `custom/terminal_integration_spec.lua` after `custom/sorting_spec.lua`, pinned at 100% CPU for minutes past the suite's normal ~40s). So the `.config/nvim` full-suite hang is not caused by the mechanism this plan targeted. Remaining suspects, untested: `events.lua`'s `WinEnter`/`WinLeave`/`BufLeave`/`CmdlineLeave` autocmds (still always-on), `navigation/lsp.lua`'s `hook_lsp_requests` re-wrapping `client.request` on every `LspAttach` (could nest unboundedly if attach fires repeatedly), or UI-side code (breadcrumbs/statusline) reacting to recorded jumps. This needs its own investigation with instrumentation inside the hung process, not more black-box autocmd-group bisection. No changes were made in `.config/nvim` as part of this pass.
