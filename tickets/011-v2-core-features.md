# Ticket 011: v2 Core Features

## Status: 📝 PLANNED

Core features identified. Implementation needed.

## Core Features to Implement

**Priority 1 (Foundation):**
1. ✅ History manager (DONE)
2. 🚧 Navigation commands (structure exists, needs implementation)
3. 🚧 LSP integration (port from v1)

**Priority 2 (User-Facing):**
4. 🚧 Breadcrumb display (when UI ready)
5. 🚧 Code preview (port from v1)
6. 🚧 Basic navigation (back/forward)

**Priority 3 (Advanced):**
7. 🚧 Picker integration
8. 🚧 Floating tree
9. 🚧 Statusline integration

## Demo Scenarios

**1. Basic History Tracking:**
- Open file A
- Navigate to file B (LSP or manual)
- Navigate to file C
- Verify history trail has 3 entries
- Use go_back() - verify at file B
- Use go_forward() - verify at file C

**2. Project Switching:**
- Open file from project A
- Open file from project B
- Verify separate history trails
- Switch back to project A
- Verify trail preserved

**3. Navigation Commands:**
- Record several jumps
- Use navigation commands
- Verify navigation works
- Test edge cases (beginning/end of trail)

## Porting from v1

**LSP Integration:**
- Port `analyzer.lua` LSP patterns
- Adapt for v2 architecture
- Extend rather than replace

**Code Preview:**
- Port `ui/preview.lua` functionality
- Adapt for v2 UI components
- Ensure fast loading

**Storage:**
- Port `persistence/storage.lua` patterns
- Adapt for v2 data models
- Make optional

## Implementation Order

1. Navigation commands (depends on history - ✅ ready)
2. LSP integration (port from v1)
3. Code preview (port from v1)
4. Breadcrumb display (new implementation)
5. Advanced features (picker, tree, statusline)

## Verification

```bash
# Verify features are implemented
grep -r "TODO" lua/spaghetti-comb-v2/navigation/commands.lua
# Should show fewer TODOs as features are implemented

# Test in nvim
nvim test_file.lua
# Use plugin features
# Verify they work
```
