# Project guidance

## Commands

- `mise run ci` runs every gate: lint (stylua check + selene), typecheck (emmylua_check), and test
- `mise run itest` runs the integration suite (`tests/itest/`): clones pallets/flask @ a pinned SHA into `tests/itest/.fixture/`, indexes it with vera-ai and codanna, then asserts the `sc` CLI JSON contract and drives real nvim in a dedicated tmux socket (`tests/itest/pty.sh`). `SC_SKIP_PTY=1` or `mise run itest-cli` skips the tmux layer. Pane frames are saved to `tests/itest/artifacts/` (gitignored). The codanna relations scenarios additionally need a codanna.nvim checkout — the sibling `../codanna.nvim` is used automatically, or set `SC_CODANNA_NVIM`.

## Architecture

**Plugin**: spaghetti-comb.nvim, code exploration via project-aware navigation history and breadcrumbs.

**Pattern**: extends built-in Neovim behavior (jumplist, LSP) rather than replacing it. Modular structure under `lua/spaghetti-comb/`: `history/`, `ui/`, `navigation/`, `utils/`, `tests/`. Each module is a table with `setup(config)` and module-local state; most expose `reset()` for tests.

**Key modules**:

- `history/manager.lua` - Trail recording, branching, pruning, exploration state
- `history/bookmarks.lua` - Manual and frequency-based bookmarks
- `history/storage.lua` - JSON persistence in `stdpath('data')/spaghetti-comb/`
- `navigation/lsp.lua` - LSP hooks recording jumps
- `ui/floating_tree.lua` + `ui/preview.lua` - Tree view with code preview
- `plugin/spaghetti-comb.lua` - User commands and default keymaps

## Constraints

- Neovim 0.10+ (uses `vim.lsp.get_clients`)
- Tests must not depend on state from earlier cases; use `reset()` in hooks
- mini.test quirk: `MiniTest.run()` takes options, not a test set; the runner in `tests/init.lua` passes spec file paths via `collect.find_files`
- `MiniTest.expect` has no `truthy`; use `equality` or the local helper in `bookmarks_spec.lua`

## Common Tasks

- **Add a feature**: write the spec test alongside; if it touches the substrate adapters, also check the integration suite (`tests/itest/`)
- **Fix a bug**: add a regression case to the matching `*_spec.lua`
