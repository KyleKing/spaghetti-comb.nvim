# Ticket 008: Consolidate Plugin Loading - DOCUMENTED

## Status: 📝 DOCUMENTED

Plugin loading strategy documented. Implementation deferred until is more complete.

## Current State

**plugin/spaghetti-comb-v1.lua:**
- Loads v1 plugin
- Initializes highlights
- Prevents double loading

**plugin/spaghetti-comb.lua:**
- Loads plugin
- Calls `require('spaghetti-comb').setup()`
- Prevents double loading

## Planned Strategy

**Single Plugin Loading (current only):**
- Remove `plugin/spaghetti-comb-v1.lua` after migration
- Keep `plugin/spaghetti-comb.lua` as primary loader
- Update to load only

**Migration Path:**
- Document breaking changes in MIGRATION.md (already done)
- Provide migration guide for v1 users
- Remove v1 loading after is stable

## Breaking Changes

**API:**
- v1: `require('spaghetti-comb-v1').setup()`
- : `require('spaghetti-comb').setup()`

**Commands:**
- v1: `:SpaghettiCombv2Show`, etc.
- : New command set (TBD)

**Keymaps:**
- v1: `<leader>sr`, `<leader>sf`, etc.
- : New keymap set (TBD)

## Implementation Notes

**When to implement:**
- After core features are complete
- After migration guide is tested
- Before removing v1 code

**What to do:**
1. Update `plugin/spaghetti-comb.lua` if needed
2. Remove `plugin/spaghetti-comb-v1.lua`
3. Update README.md installation instructions
4. Update MIGRATION.md with final steps

## Verification

```bash
# Verify plugin files exist
test -f plugin/spaghetti-comb.lua && echo "v2 plugin exists"
test -f plugin/spaghetti-comb-v1.lua && echo "v1 plugin exists (to be removed)"

# Verify loads
nvim --headless -c "lua require('spaghetti-comb').setup()" -c "qa"
# Should not error
```
