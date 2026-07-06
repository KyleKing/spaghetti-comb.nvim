# AGENTS.md - AI Development Guide

Concise reference for AI agents working on this codebase. For detailed human-focused documentation, see [DEVELOPER.md](DEVELOPER.md). For planned work, see [ROADMAP.md](ROADMAP.md).

## Quick Commands

- `mise run test` - Run all tests (mini.test, headless nvim)
- `mise run test-file --file=<file>` - Run a specific spec file
- `mise run lint` - Check formatting (stylua)
- `mise run format` - Format code (stylua fix)
- `mise run typecheck` - Run selene lint
- `mise run deps-mini-nvim` - Install mini.nvim test dependency (required before first test run)

## Architecture Overview

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
- **Before committing**: `mise run format && mise run test`
