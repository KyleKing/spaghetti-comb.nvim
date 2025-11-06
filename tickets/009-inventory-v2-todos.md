# Ticket 009: Inventory v2 TODOs

## Status: 📊 INVENTORY COMPLETE

TODO inventory created. 94 TODO items found across v2 codebase.

## TODO Count

**Total**: 94 TODO items

## Categorization by Module

**history/** (4 TODOs):
- `history/manager.lua`: 1 TODO (prune_old_entries - already implemented via prune_with_recovery)
- `history/storage.lua`: 3 TODOs (persistence functionality)

**ui/** (30 TODOs):
- `ui/breadcrumbs.lua`: 7 TODOs (breadcrumb rendering)
- `ui/floating_tree.lua`: 8 TODOs (floating tree window)
- `ui/preview.lua`: 4 TODOs (code preview)
- `ui/picker.lua`: 11 TODOs (picker integration)

**navigation/** (10 TODOs):
- `navigation/commands.lua`: 6 TODOs (navigation commands)
- `navigation/events.lua`: 4 TODOs (event handling)

**tests/** (36 TODOs):
- `tests/history_spec.lua`: 4 TODOs
- `tests/ui_spec.lua`: 7 TODOs
- `tests/navigation_spec.lua`: 4 TODOs
- `tests/integration_spec.lua`: 7 TODOs
- `tests/lsp_spec.lua`: 14 TODOs (not in original count, but exists)

**utils/** (2 TODOs):
- `utils/debug.lua`: 2 TODOs (debug logging)

**Other**: 12 TODOs in various files

## Priority Order

1. **Core Functionality** (history, navigation commands)
2. **LSP Integration** (navigation/lsp.lua)
3. **UI Components** (breadcrumbs, preview)
4. **Advanced Features** (picker, floating tree, statusline)
5. **Persistence** (storage, bookmarks)

## v1 Porting Opportunities

**Can be ported from v1:**
- LSP integration → `navigation/lsp.lua` (from v1 `analyzer.lua`)
- Storage patterns → `history/storage.lua` (from v1 `persistence/storage.lua`)
- Bookmark management → `history/bookmarks.lua` (from v1 `persistence/bookmarks.lua`)
- Code preview → `ui/preview.lua` (from v1 `ui/preview.lua`)

**Dependency Graph:**
- History manager (✅ done) → Navigation commands → LSP integration
- History manager → Storage → Persistence
- History manager → Bookmarks → Picker
- UI components depend on history manager

## Next Steps

1. Implement navigation commands (depends on history manager - ✅ ready)
2. Implement LSP integration (port from v1)
3. Implement UI components (breadcrumbs, preview)
4. Implement advanced features (picker, floating tree)

See individual TODO comments in code for specific implementation tasks.
