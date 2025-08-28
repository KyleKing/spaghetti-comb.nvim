# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing

- `make test` - Run all tests using mini.test framework documented in `mini-test.md`
- `make test_file FILE=<file>` - Run specific test file (e.g., `make test_file FILE=tests/test_navigation.lua`)

### Code Quality

- `make lint` - Check code formatting using stylua
- `make format` - Format code using stylua (fix mode)
- `make typecheck` - Run selene type checking
- `make luals` - Run lua-language-server type checking (not yet implemented)
- `pre-commit run --all-files` - general formatting

### Documentation

- `make docs` - Generate plugin documentation using mini.doc

### Setup

- `make deps` - Install mini.nvim dependency for tests and documentation

## Architecture Overview

This is a Neovim plugin for code exploration called "Spaghetti Comb" - designed to help developers untangle complex codebases by visualizing code relationships and dependencies.

### Current Implementation Status

The plugin is in active development with basic infrastructure completed (Phase 1). The plugin structure follows standard Neovim plugin patterns with a modular architecture.

### Plugin Architecture Pattern

The codebase follows a standard Neovim plugin architecture:

1. **Global plugin object** (`SpaghettiComb`) exposes public API via `init.lua`
1. **Modular structure** separating domains:
    - `analyzer.lua` - LSP-based code analysis and symbol extraction
    - `navigation.lua` - Navigation stack management and history
    - `ui/` - User interface components (floating windows, highlights, previews)
    - `coupling/` - Code coupling analysis and metrics
    - `persistence/` - Session storage and bookmarks
    - `utils.lua` - Shared utilities

### Key Features (Planned)

- **Relations Panel**: Floating window showing code relationships (references, definitions, call hierarchy)
- **Navigation Stack**: Bidirectional exploration history with context preservation
- **LSP Integration**: Multi-language support (TypeScript, JavaScript, Python, Rust, Go)
- **Coupling Analysis**: Numerical evaluation of code relationships with visual indicators
- **Session Persistence**: Save/load exploration sessions and bookmarks

### Testing Framework

Uses `mini.test` with child Neovim processes for comprehensive plugin testing. See `mini-test.md` for detailed testing documentation and examples.
