# Ticket 008: Consolidate Plugin Loading - DOCUMENTED

## Status: 📝 DOCUMENTED

Plugin loading strategy documented. Implementation deferred until v2 is more complete.

## Current State

**plugin/spaghetti-comb-v1.lua:**
- Loads v1 plugin
- Initializes highlights
- Prevents double loading

**plugin/spaghetti-comb-v2.lua:**
- Loads v2 plugin
- Calls `require('spaghetti-comb-v2').setup()`
- Prevents double loading

## Planned Strategy

**Single Plugin Loading (v2 only):**
- Remove `plugin/spaghetti-comb-v1.lua` after migration
- Keep `plugin/spaghetti-comb-v2.lua` as primary loader
- Update to load v2 only

**Migration Path:**
- Document breaking changes in MIGRATION.md (already done)
- Provide migration guide for v1 users
- Remove v1 loading after v2 is stable

## Breaking Changes

**API:**
- v1: `require('spaghetti-comb-v1').setup()`
- v2: `require('spaghetti-comb-v2').setup()`

**Commands:**
- v1: `:SpaghettiCombv2Show`, etc.
- v2: New command set (TBD)

**Keymaps:**
- v1: `<leader>sr`, `<leader>sf`, etc.
- v2: New keymap set (TBD)

## Implementation Notes

**When to implement:**
- After v2 core features are complete
- After migration guide is tested
- Before removing v1 code

**What to do:**
1. Update `plugin/spaghetti-comb-v2.lua` if needed
2. Remove `plugin/spaghetti-comb-v1.lua`
3. Update README.md installation instructions
4. Update MIGRATION.md with final steps

## Verification

```bash
# Verify plugin files exist
test -f plugin/spaghetti-comb-v2.lua && echo "v2 plugin exists"
test -f plugin/spaghetti-comb-v1.lua && echo "v1 plugin exists (to be removed)"

# Verify v2 loads
nvim --headless -c "lua require('spaghetti-comb-v2').setup()" -c "qa"
# Should not error
```
