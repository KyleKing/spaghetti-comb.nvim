# Project guidance

For planned work, see [ROADMAP.md](ROADMAP.md).

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

- **Add a feature**: check ROADMAP.md phasing first; write the spec test alongside
- **Fix a bug**: add a regression case to the matching `*_spec.lua`
