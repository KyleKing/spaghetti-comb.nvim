# CI/CD Workflows

This directory contains GitHub Actions workflows for continuous integration and testing.

## Workflows

### CI (`ci.yml`)

Runs on every push and pull request to ensure code quality and functionality.

**Jobs:**

1. **Test** - Runs the test suite on multiple Neovim versions
   - Tests on both `stable` and `nightly` Neovim versions
   - Downloads mini.nvim test framework dependency
   - Executes all tests using `mini.test`

2. **Lint** - Checks code quality with static analysis tools
   - **stylua**: Lua code formatter (check mode)
   - **selene**: Lua linter for detecting common issues

3. **Format Check** - Ensures code is properly formatted
   - Validates that all Lua code follows stylua formatting rules

## Running Checks Locally

Before pushing, you can run the same checks locally:

### Tests
```bash
# If you have mise installed
mise run test

# Without mise
nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua require('spaghetti-comb.tests.init').run_all()"
```

### Formatting
```bash
# Check formatting
mise run lint
# Or directly:
stylua --check lua/ plugin/ scripts/

# Auto-fix formatting
mise run format
# Or directly:
stylua lua/ plugin/ scripts/
```

### Type Checking
```bash
# Run selene linter
mise run typecheck
# Or directly:
selene lua/ plugin/ scripts/
```

## CI Status

All pull requests must pass CI checks before merging. The CI status is displayed on each PR.

## Adding New Tests

Tests are located in `lua/spaghetti-comb/tests/` and use the mini.test framework:

1. Create a new `*_spec.lua` file in the tests directory
2. Add it to the test suite in `lua/spaghetti-comb/tests/init.lua`
3. Tests will automatically run in CI on the next push

See [DEVELOPER.md](../../DEVELOPER.md) for detailed testing guidelines.
