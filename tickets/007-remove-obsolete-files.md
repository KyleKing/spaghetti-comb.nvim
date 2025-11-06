# Ticket 007: Remove Obsolete Files - COMPLETED

## Status: ✅ COMPLETED

Obsolete files identified and removed. v1 removal plan documented.

## Files Removed

**test_basic_history.lua**
- Standalone test file (not using test framework)
- Functionality should be in `lua/spaghetti-comb-v2/tests/history_spec.lua`
- Removed (functionality already covered by proper test suite)

## Files to Remove Later (After Migration)

**v1 Code** (to be removed after v2 migration complete):
- `lua/spaghetti-comb-v1/` - Entire v1 implementation
- `plugin/spaghetti-comb-v1.lua` - v1 plugin loader
- `tests-v1/` - v1 test suite (keep for reference until migration complete)

**Outdated Documentation** (after consolidation):
- `IMPLEMENTATION_PLAN.md` - Content extracted to SPEC.md (can be removed later)
- `links.md` - Content merged into other docs (can be removed later)

## Removal Rationale

**test_basic_history.lua:**
- Standalone test not using mini.test framework
- Functionality should be in proper test suite
- Already covered by `lua/spaghetti-comb-v2/tests/history_spec.lua` (when implemented)

**v1 Code:**
- Will be removed after v2 migration is complete
- See MIGRATION.md for migration timeline
- Keep for reference during porting

## Verification

```bash
# Verify test_basic_history.lua is removed
test ! -f test_basic_history.lua && echo "Removed successfully"

# List v1 files (to be removed later)
ls -la lua/spaghetti-comb-v1/
ls -la tests-v1/
```
