# Ticket 010: Test Implementation

## Status: 📝 DOCUMENTED

Test implementation strategy documented. Tests are placeholder structure - implementation needed.

## Current State

**Test Files:**
- `lua/spaghetti-comb/tests/init.lua` - Test runner (✅ implemented)
- `lua/spaghetti-comb/tests/history_spec.lua` - Placeholder tests
- `lua/spaghetti-comb/tests/ui_spec.lua` - Placeholder tests
- `lua/spaghetti-comb/tests/navigation_spec.lua` - Placeholder tests
- `lua/spaghetti-comb/tests/integration_spec.lua` - Placeholder tests
- `lua/spaghetti-comb/tests/lsp_spec.lua` - Placeholder tests

**Test Framework:**
- Uses mini.test (✅ set up)
- Child Neovim processes for isolation
- Test runner implemented

## Implementation Needed

**Basic Test Structure:**
- Test suites are created but empty
- Need to implement actual test cases
- Follow patterns from v1 tests

**Testable Demo Scenarios:**
1. History tracking - record jumps, verify trail
2. Navigation - go back/forward, verify index
3. Project switching - switch projects, verify separate trails
4. Pruning - trigger pruning, verify entries removed
5. Location recovery - modify file, verify recovery

**CLI Execution:**
- `mise run test` - Should work (tested)
- Tests run headless via `nvim --headless`
- Output should be clear

## Test Patterns from v1

**From tests-v1/test_init.lua:**
- Use `MiniTest.new_child_neovim()` for isolation
- Use `child.lua()` and `child.lua_get()` for execution
- Use `expect.no_error()` for assertions
- Use hooks for setup/teardown

**Example Pattern:**
```lua
local T = new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            -- Setup
        end,
    },
})
```

## Next Steps

1. Implement history_spec.lua tests (history manager is ready)
2. Implement basic navigation tests
3. Implement integration tests
4. Port useful patterns from v1

## Verification

```bash
# Verify test structure
grep -r "MiniTest\|new_set" lua/spaghetti-comb/tests/
# Should find test framework usage

# Run tests
mise run test
# Should execute (may have failures until implemented)
```
