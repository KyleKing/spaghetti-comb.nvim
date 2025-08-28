# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing
- `make test` - Run all tests using mini.test framework
- `make test-nightly` - Run tests on nightly Neovim (requires `bob`)
- `make test-0.8.3` - Run tests on Neovim 0.8.3 (requires `bob`)
- `make test-ci` - Install dependencies and run tests (useful for CI)

### Code Quality
- `make lint` - Format code using stylua
- `make luals` - Run lua-language-server type checking
- `make luals-ci` - Run lua-language-server with CI configuration

### Documentation
- `make documentation` - Generate plugin documentation using mini.doc
- `make documentation-ci` - Install dependencies and generate documentation

### Setup
- `make setup` - Initialize plugin from template (interactive script)
- `make deps` - Install mini.nvim dependency for tests and documentation
- `make all` - Run documentation, lint, luals, and test

## Architecture Overview

This is a Neovim plugin for displaying interactive call graphs that help developers navigate and understand code relationships.

### Core Structure
- **Main plugin logic**: `lua/call-graph/` (to be renamed from template)
  - `init.lua` - Public API with setup(), show_call_graph(), hide_call_graph() methods
  - `main.lua` - Core call graph generation and display logic
  - `config.lua` - Configuration management for display options and language support
  - `state.lua` - Plugin state management for active call graphs
  - `util/debug.lua` - Debug utilities

### Current Implementation Status
- **Template Base**: Built from Neovim plugin template with boilerplate structure
- **Plugin Entry Points**: `plugin/` directory contains plugin initialization files
- **Testing Framework**: Uses mini.test framework with `tests/test_API.lua` and `tests/helpers.lua`

### Plugin Architecture Pattern
The codebase follows a standard Neovim plugin architecture:
1. Global plugin object exposes public API for call graph operations
2. Configuration merging with user-provided display and behavior options
3. Event-driven call graph generation based on cursor position
4. Modular structure separating graph generation, display, and navigation

### Key Features (Planned)
- **Function Call Graph Display**: Show callers and callees of the currently highlighted function
- **Interactive Navigation**: Jump between functions in the call graph
- **Code Preview**: Preview function implementations without leaving the graph
- **Multi-language Support**: Language server integration for accurate call relationships
- **Customizable Display**: Configurable graph layout, depth, and visual styling

### Development Workflow
1. Use `make setup` to rename template files to `call-graph`
2. Implement call graph generation logic in `lua/call-graph/main.lua`
3. Add language server integration for function relationship detection
4. Create interactive display buffer with navigation capabilities
5. Add configuration options for graph appearance and behavior
6. Implement tests for core functionality
7. Run `make all` to verify implementation

The plugin will provide an intuitive way to understand code structure by visualizing function call relationships and enabling quick navigation between related code sections.