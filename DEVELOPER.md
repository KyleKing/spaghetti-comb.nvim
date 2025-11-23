# DEVELOPER.md - Development Guide

Comprehensive guide for developers working on Spaghetti Comb. For quick AI reference, see [AGENTS.md](AGENTS.md).

## Table of Contents

1. [Development Setup](#development-setup)
2. [Project Structure](#project-structure)
3. [Testing](#testing)
4. [Code Organization](#code-organization)
5. [Development Workflow](#development-workflow)
6. [Contributing](#contributing)
7. [Troubleshooting](#troubleshooting)

## Development Setup

### Prerequisites

- **Neovim 0.8+** - Required for plugin development
- **mise** - Tool version manager (replaces asdf/nvm)
- **Lua 5.4** - Managed by mise
- **stylua** - Code formatter (managed by mise)
- **selene** - Lua linter (managed by mise)

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd spaghetti-comb.nvim
   ```

2. **Install dependencies**
   ```bash
   mise install
   mise run deps-mini-nvim  # Install mini.nvim for testing
   ```

3. **Verify setup**
   ```bash
   mise run test  # Should run tests (may have failures initially)
   mise run lint  # Should check code formatting
   ```

### Development Environment

The project uses `mise` for tool management. All development commands are defined in `mise.toml`.

**Key tools:**
- `lua 5.4` - Lua runtime
- `stylua` - Code formatter
- `selene` - Lua linter
- `mini.nvim` - Testing framework (in `deps/mini.nvim/`)

## Project Structure

### Directory Layout

```
spaghetti-comb.nvim/
├── lua/
│   ├── spaghetti-comb-v1/     # v1 implementation (to be removed)
│   └── spaghetti-comb/     # implementation (current focus)
│       ├── init.lua           # Plugin entry point
│       ├── config.lua         # Configuration management
│       ├── types.lua          # Core data models
│       ├── history/            # History management
│       ├── ui/                # UI components
│       ├── navigation/        # Navigation commands
│       ├── utils/             # Utility modules
│       └── tests/             # Test suite
├── plugin/                    # Plugin loaders
├── tests-v1/                  # v1 test suite
├── scripts/                   # Utility scripts
├── doc/                       # Vim help documentation
└── tickets/                   # Implementation tickets
```

### Module Organization

**Core Modules:**
- `init.lua` - Plugin initialization and public API
- `config.lua` - Configuration schema and validation
- `types.lua` - Data model definitions (NavigationEntry, NavigationTrail, etc.)

**History Management:**
- `history/manager.lua` - Core history tracking (✅ implemented)
- `history/storage.lua` - Persistence (🚧 TODO)
- `history/events.lua` - Event handling (🚧 TODO)
- `history/bookmarks.lua` - Bookmark management (🚧 TODO)

**UI Components:**
- `ui/breadcrumbs.lua` - Breadcrumb rendering (🚧 TODO)
- `ui/floating_tree.lua` - Floating tree window (🚧 TODO)
- `ui/preview.lua` - Code preview (🚧 TODO)
- `ui/picker.lua` - Picker integration (🚧 TODO)
- `ui/statusline.lua` - Statusline integration (🚧 TODO)

**Navigation:**
- `navigation/commands.lua` - Navigation commands (🚧 TODO)
- `navigation/lsp.lua` - LSP integration (🚧 TODO)
- `navigation/jumplist.lua` - Jumplist enhancement (🚧 TODO)
- `navigation/events.lua` - Navigation events (🚧 TODO)

**Utilities:**
- `utils/project.lua` - Project detection
- `utils/debug.lua` - Debug logging

## Testing

### Test Framework

The project uses `mini.test` framework with child Neovim processes for isolated testing.

**Test Structure:**
- Tests are in `lua/spaghetti-comb/tests/`
- Each test file is a Lua module that returns a test set
- Test runner is in `lua/spaghetti-comb/tests/init.lua`

### Running Tests

**Run all tests:**
```bash
mise run test
```

**Run specific test file:**
```bash
mise run test-file --file=lua/spaghetti-comb/tests/history_spec.lua
```

**Run tests manually:**
```bash
nvim --headless --noplugin -u ./scripts/minimal_init.lua \
  -c "lua require('spaghetti-comb.tests.init').run_all()" \
  -c "qa"
```

### Writing Tests

**Test File Structure:**
```lua
local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set({
    hooks = {
        pre_case = function()
            -- Setup before each test
        end,
        post_case = function()
            -- Cleanup after each test
        end,
    },
})

T["feature name"] = new_set()

T["feature name"]["test case"] = function()
    -- Test implementation
    expect.no_error(function()
        -- Assertions
    end)
end

return T
```

**Example Test:**
```lua
T["history manager"]["records jumps"] = function()
    local history = require("spaghetti-comb.history.manager")
    history.setup({})
    history.set_current_project("/test/project")
    
    local success, entry = history.record_jump(
        { file_path = "/test/a.lua", position = { line = 1, column = 1 } },
        { file_path = "/test/b.lua", position = { line = 10, column = 5 } },
        "manual"
    )
    
    expect.no_error(function()
        assert(success == true)
        assert(entry ~= nil)
    end)
end
```

**Test Patterns from v1:**
- Use `MiniTest.new_child_neovim()` for integration tests
- Use `child.lua()` and `child.lua_get()` for executing Lua in child Neovim
- Use `expect.no_error()` for error checking
- Use `MiniTest.expect.equality()` for value comparisons

### Test Categories

- **History Tests** (`history_spec.lua`) - History manager functionality
- **UI Tests** (`ui_spec.lua`) - UI component tests
- **Navigation Tests** (`navigation_spec.lua`) - Navigation command tests
- **Integration Tests** (`integration_spec.lua`) - End-to-end tests
- **LSP Tests** (`lsp_spec.lua`) - LSP integration tests

## Code Organization

### Architecture Patterns

**Module Pattern:**
- Each module returns a table with public functions
- Private functions are local
- State is managed in module-local tables

**Example:**
```lua
local M = {}

local state = {
    initialized = false,
    config = nil,
}

function M.setup(config)
    state.config = config
    state.initialized = true
end

function M.get_config()
    return state.config
end

return M
```

**Configuration Pattern:**
- Default config in `config.lua`
- User config merged with defaults
- Validation before use

**Error Handling:**
- Use `pcall()` for risky operations
- Return `success, result` tuples
- Log errors via debug utilities

### Code Style

**Formatting:**
- Use `stylua` for formatting
- Run `mise run format` before committing
- Follow Neovim Lua style conventions

**Linting:**
- Use `selene` for linting
- Run `mise run typecheck` before committing
- Fix all warnings

**Naming:**
- Use `snake_case` for functions and variables
- Use `PascalCase` for types/classes (in comments)
- Use descriptive names

**Comments:**
- Use `---` for function documentation
- Use `--` for inline comments
- Document public APIs

## Development Workflow

### Making Changes

1. **Create a branch**
   ```bash
   git checkout -b feature/my-feature
   ```

2. **Make changes**
   - Follow code organization patterns
   - Write tests for new features
   - Update documentation if needed

3. **Run quality checks**
   ```bash
   mise run format    # Format code
   mise run typecheck # Check for errors
   mise run test      # Run tests
   ```

4. **Commit changes**
   ```bash
   git add .
   git commit -m "feat: add feature description"
   ```

### Code Quality Commands

**Formatting:**
```bash
mise run format  # Auto-fix formatting
mise run lint    # Check formatting (no fix)
```

**Type Checking:**
```bash
mise run typecheck  # Run selene linter
```

**Testing:**
```bash
mise run test                    # Run all tests
mise run test-file --file=...   # Run specific test
```

### Pre-commit Checklist

- [ ] Code is formatted (`mise run format`)
- [ ] No linting errors (`mise run typecheck`)
- [ ] Tests pass (`mise run test`)
- [ ] Documentation updated (if needed)
- [ ] Commit message follows conventions

## Contributing

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Add tests** for new functionality
5. **Run quality checks** (format, lint, test)
6. **Submit a pull request**

### Pull Request Guidelines

- **Clear description** of changes
- **Reference tickets** if applicable
- **Include tests** for new features
- **Update documentation** if needed
- **Ensure all checks pass**

### Code Review Process

- All PRs require review
- Address review comments
- Keep PRs focused and small
- Rebase on main before merging

### Issue Reporting

When reporting issues:
- **Describe the problem** clearly
- **Include steps to reproduce**
- **Provide environment details** (Neovim version, OS, etc.)
- **Include error messages** if any
- **Check existing issues** first

## Troubleshooting

### Common Issues

**Tests fail to run:**
- Ensure `mise run deps-mini-nvim` has been run
- Check that `deps/mini.nvim/` exists
- Verify Neovim version is 0.8+

**Formatting issues:**
- Run `mise run format` to auto-fix
- Check `stylua` is installed via mise

**Type checking errors:**
- Review selene warnings
- Fix type annotations if needed
- Check for common Lua pitfalls

**Plugin doesn't load:**
- Check `plugin/spaghetti-comb.lua` exists
- Verify runtime path includes plugin directory
- Check Neovim version compatibility

### Debug Tips

**Enable debug logging:**
```lua
require('spaghetti-comb').setup({
    debug = {
        enabled = true,
        log_level = "debug",
    }
})
```

**Inspect plugin state:**
```lua
local config = require('spaghetti-comb').get_config()
-- Inspect config
```

**Test in isolation:**
```bash
nvim --headless -u scripts/minimal_init.lua
```

### Getting Help

- Check [AGENTS.md](AGENTS.md) for quick reference
- Review [SPEC.md](SPEC.md) for feature specifications
- Check existing issues on GitHub
- Review test files for usage examples

## Additional Resources

- **mini.test documentation**: `deps/mini-test.md`
- **Neovim Lua guide**: `:help lua-guide`
- **Plugin development**: `:help develop-plugin`

