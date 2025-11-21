# Ticket 012: Validate v1 Functionality

## Status: 📝 DOCUMENTED

v1 validation strategy documented. Execution deferred (v1 tests exist but not run in this session).

## Current State

**v1 Test Suite:**
- `tests-v1/test_init.lua` - Setup tests
- `tests-v1/test_analyzer.lua` - LSP integration tests
- `tests-v1/test_navigation.lua` - Navigation tests
- `tests-v1/test_relations_ui.lua` - UI tests
- `tests-v1/test_symbol_extraction.lua` - Symbol extraction tests
- `tests-v1/test_utils.lua` - Utility tests

**Test Framework:**
- Uses mini.test
- Child Neovim processes
- Comprehensive test coverage

## Validation Strategy

**Run v1 Tests:**
```bash
# Manual execution (not automated in this session)
nvim --headless --noplugin -u ./scripts/minimal_init.lua \
  -c "lua require('tests-v1.test_init')" \
  -c "qa"
```

**Document Results:**
- Which tests pass
- Which tests fail
- What features work
- What's broken

**Porting Value:**
- Identify stable, well-tested components
- Note what needs fixes before porting
- Prioritize porting based on test coverage

## What's Worth Porting

**Well-Tested (High Priority):**
- LSP integration (`analyzer.lua`) - Comprehensive tests
- Navigation stack (`navigation.lua`) - Tested
- Storage patterns (`persistence/storage.lua`) - Tested

**Needs Review:**
- UI components - May need adaptation for v2
- Coupling analysis - May not be needed in v2

## Test Report Template

**When executed, document:**
- Test execution command
- Pass/fail counts
- Feature status (working/broken)
- Porting recommendations
- Priority order

## Next Steps

1. Run v1 tests (manual execution)
2. Document results
3. Create porting priority list
4. Begin porting well-tested components

## Verification

```bash
# Verify test files exist
ls tests-v1/
# Should list all test files

# Verify test structure
head tests-v1/test_init.lua
# Should show mini.test usage
```
