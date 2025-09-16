# AGENTS.md

## Development Commands

### Testing

- `mise run test` - Run all tests using mini.test framework documented in `mini-test.md`
- `mise run test-file --file=<file>` - Run specific test file (e.g., `mise run test-file --file=tests/test_navigation.lua`)

### Code Quality

- `mise run lint` - Check code formatting using stylua
- `mise run format` - Format code using stylua (fix mode)
- `mise run typecheck` - Run selene type checking
- `mise run luals` - Run lua-language-server type checking (not yet implemented)
- `pre-commit run --all-files` - general formatting

### Documentation

- `mise run docs` - Generate help tags for vim documentation
- `mise run docs-auto` - Attempt automatic documentation generation (experimental)

### Setup

- `mise run deps-mini-nvim` - Install mini.nvim dependency for tests and documentation

## Architecture Overview

This is a Neovim plugin for code exploration called "Spaghetti Comb" - designed to help developers untangle complex codebases by visualizing code relationships and dependencies.

The plugin uses a **split window architecture** similar to vim's `:help` command, with a **focus mode** that expands the window and adds a side-by-side preview panel.

### Current Implementation Status

The plugin is in active development with basic infrastructure completed (Phase 1). The plugin structure follows standard Neovim plugin patterns with a modular architecture.

### Plugin Architecture Pattern

The codebase follows a standard Neovim plugin architecture:

1. **Global plugin object** (`SpaghettiComb`) exposes public API via `init.lua`
1. **Modular structure** separating domains:
    - `analyzer.lua` - LSP-based code analysis and symbol extraction
    - `navigation.lua` - Navigation stack management and history
    - `ui/` - User interface components (split windows, highlights, previews)
        - `relations.lua` - Split window management with focus mode
        - `preview.lua` - Code preview functionality
        - `highlights.lua` - Syntax highlighting
    - `coupling/` - Code coupling analysis and metrics
    - `persistence/` - Session storage and bookmarks
    - `utils.lua` - Shared utilities

### Key Features (Implemented)

- **Relations Panel**: Split window showing code relationships (references, definitions, call hierarchy)
- **Focus Mode**: Press `<Tab>` to expand relations window and show side-by-side code preview
- **Vim Motion Navigation**: Full vim navigation support (j/k, arrows, etc.) within relations panel
- **Navigation Stack**: Bidirectional exploration history with context preservation
- **LSP Integration**: Multi-language support (TypeScript, JavaScript, Python, Rust, Go)
- **Coupling Analysis**: Numerical evaluation of code relationships with visual indicators
- **Session Persistence**: Save/load exploration sessions and bookmarks
- **Advanced Filtering**: Search, sort, and filter relations by various criteria

### Testing Framework

Uses `mini.test` with child Neovim processes for comprehensive plugin testing. See `mini-test.md` for detailed testing documentation and examples.
