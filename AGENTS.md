# AGENTS.md - AI Development Guide

Concise reference for AI agents working on this codebase. For detailed human-focused documentation, see [DEVELOPER.md](DEVELOPER.md).

## Quick Commands

### Testing
- `mise run test` - Run all v2 tests (mini.test framework)
- `mise run test-file --file=<file>` - Run specific test file

### Code Quality
- `mise run lint` - Check formatting (stylua)
- `mise run format` - Format code (stylua fix)
- `mise run typecheck` - Run selene type checking

### Documentation
- `mise run docs` - Generate vim help tags
- `mise run docs-auto` - Auto-generate docs (experimental)

### Setup
- `mise run deps-mini-nvim` - Install mini.nvim dependency

## Architecture Overview

**Plugin**: Spaghetti Comb v2 - Code exploration via breadcrumb navigation

**Current Status**: v2 in active development (history manager implemented, UI components in progress)

**Architecture Pattern**:
- Modular structure: `history/`, `ui/`, `navigation/`, `utils/`
- Extends built-in Neovim (jumplist, LSP) rather than replacing
- Project-aware history with intelligent pruning

**Key Modules**:
- `history/manager.lua` - Core history tracking (✅ implemented)
- `ui/breadcrumbs.lua` - Breadcrumb rendering (🚧 TODO)
- `navigation/commands.lua` - Navigation commands (🚧 TODO)
- `navigation/lsp.lua` - LSP integration (🚧 TODO)

**v1 vs v2**:
- v1: Relations panel UI (fully implemented, will be removed)
- v2: Breadcrumb-based (in development, extends Neovim built-ins)

## Code Locations

- **v2 Code**: `lua/spaghetti-comb-v2/`
- **v1 Code**: `lua/spaghetti-comb-v1/` (to be removed after migration)
- **Tests**: `lua/spaghetti-comb-v2/tests/` (v2), `tests-v1/` (v1)
- **Plugin Loaders**: `plugin/spaghetti-comb-v2.lua`

## Testing Framework

Uses `mini.test` with child Neovim processes. See `deps/mini-test.md` for framework details.

## Common Tasks

**Add a feature**: Check `lua/spaghetti-comb-v2/` for TODO comments, implement in appropriate module
**Fix a bug**: Check test coverage, add test if missing, fix implementation
**Port from v1**: See ticket 006 for porting checklist, adapt v1 code to v2 architecture
