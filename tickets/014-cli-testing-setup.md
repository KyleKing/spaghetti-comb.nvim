# Ticket 014: CLI Testing Setup

## Status: ✅ VERIFIED

CLI test execution verified. Test commands documented.

## Test Commands

**Run All Tests:**
```bash
mise run test
```
- Executes: `nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua require('spaghetti-comb.tests.init').run_all()"`
- Runs all test suites
- Headless execution (no GUI)

**Run Specific Test File:**
```bash
mise run test-file --file=lua/spaghetti-comb/tests/history_spec.lua
```
- Executes specific test file
- Uses mini.test framework

**Manual Execution:**
```bash
nvim --headless --noplugin -u ./scripts/minimal_init.lua \
  -c "lua require('spaghetti-comb.tests.init').run_all()" \
  -c "qa"
```

## Test Framework

**mini.test:**
- Uses child Neovim processes
- Isolated test execution
- Headless by default
- Clear output

**Test Structure:**
- Tests in `lua/spaghetti-comb/tests/`
- Test runner in `tests/init.lua`
- Each test file returns test set

## Verification

**CLI Execution:**
```bash
# Verify test command works
mise run test
# Should execute without errors (tests may fail until implemented)

# Verify headless execution
nvim --headless --noplugin -u scripts/minimal_init.lua \
  -c "lua require('spaghetti-comb.tests.init').run_all()" \
  -c "qa"
# Should work without GUI
```

**Test Structure:**
```bash
# Verify test files exist
ls lua/spaghetti-comb/tests/
# Should list test files

# Verify test framework usage
grep -r "MiniTest\|new_set" lua/spaghetti-comb/tests/
# Should find test framework usage
```

## Test Examples

**Basic Test Pattern:**
```lua
local MiniTest = require("mini.test")
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set({
    hooks = {
        pre_case = function()
            -- Setup
        end,
    },
})

T["feature"]["test case"] = function()
    expect.no_error(function()
        -- Test implementation
    end)
end

return T
```

## Documentation

Test commands documented in:
- **AGENTS.md** - Quick reference
- **DEVELOPER.md** - Comprehensive guide
- **mise.toml** - Command definitions

## Both Test Suites

** Tests:**
- `lua/spaghetti-comb/tests/` - Current focus
- Uses mini.test
- CLI execution verified

**v1 Tests:**
- `tests-v1/` - For reference
- Uses mini.test
- Can be run manually (not automated)

## Next Steps

1. Implement actual test cases (see ticket 010)
2. Ensure all tests pass
3. Add test examples to DEVELOPER.md
4. Document test patterns

## Status

✅ CLI test execution works
✅ Test commands documented
✅ Headless execution verified
✅ Test structure in place
🚧 Test implementation needed (ticket 010)
