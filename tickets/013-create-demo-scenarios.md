# Ticket 013: Create Demo Scenarios

## Status: 📝 DOCUMENTED

Demo scenarios documented. Implementation needed as features are completed.

## Demo Scenarios

### 1. Basic History Tracking

**Prerequisites:**
- v2 plugin installed
- History manager initialized

**Steps:**
1. Open file A in Neovim
2. Navigate to file B (manual or LSP)
3. Navigate to file C
4. Verify history trail has 3 entries
5. Use navigation command to go back
6. Verify at file B
7. Use navigation command to go forward
8. Verify at file C

**Expected Result:**
- History tracks all jumps
- Navigation commands work
- Trail state is correct

### 2. Project Switching

**Prerequisites:**
- Multiple projects available
- v2 plugin installed

**Steps:**
1. Open file from project A
2. Navigate within project A
3. Open file from project B
4. Navigate within project B
5. Switch back to project A
6. Verify separate history trails

**Expected Result:**
- Separate trails per project
- Auto-switching works
- Trails preserved when switching

### 3. Navigation Commands

**Prerequisites:**
- History with multiple entries
- Navigation commands implemented

**Steps:**
1. Record several navigation jumps
2. Use go_back() command
3. Verify position in trail
4. Use go_forward() command
5. Verify position in trail
6. Test edge cases (beginning/end)

**Expected Result:**
- Commands work correctly
- Edge cases handled
- Trail state updated

### 4. LSP Integration (When Implemented)

**Prerequisites:**
- LSP server configured
- LSP integration implemented

**Steps:**
1. Position cursor on symbol
2. Use go-to-definition (LSP)
3. Verify jump recorded in history
4. Use find-references (LSP)
5. Verify references tracked
6. Navigate through history

**Expected Result:**
- LSP jumps tracked
- History preserved
- Navigation works

### 5. UI Components (When Implemented)

**Breadcrumbs:**
1. Record navigation jumps
2. Trigger breadcrumb display
3. Verify breadcrumb trail shown
4. Navigate breadcrumbs
5. Verify navigation works

**Floating Tree:**
1. Record branching navigation
2. Open floating tree
3. Verify tree visualization
4. Select branch node
5. Verify preview shown

**Picker:**
1. Record navigation history
2. Open picker (navigation mode)
3. Filter and select entry
4. Verify jump to location
5. Switch to bookmark mode
6. Manage bookmarks

## Demo Checklist

- [ ] Basic history tracking works
- [ ] Project switching works
- [ ] Navigation commands work
- [ ] LSP integration works (when implemented)
- [ ] UI components work (when implemented)
- [ ] All demos are reproducible
- [ ] Demos are documented

## Prerequisites

**Required:**
- Neovim 0.8+
- v2 plugin installed
- History manager working

**Optional:**
- LSP server (for LSP demos)
- mini.pick (for picker demos)
- Multiple projects (for project switching)

## Documentation

Add demos to:
- README.md (quick start)
- DEVELOPER.md (development examples)
- Or create separate DEMOS.md

## Verification

```bash
# Verify demo scenarios are documented
grep -i "demo\|scenario" tickets/013-create-demo-scenarios.md
# Should find demo scenarios

# Test basic demo
nvim test_file.lua
# Follow demo steps
# Verify they work
```
