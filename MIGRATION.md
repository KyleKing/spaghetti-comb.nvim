# Migration Guide: v1 to 

## Overview

Spaghetti Comb is a clean break from v1 - no backward compatibility is maintained. This document explains the differences, migration path, and what can be reused from v1.

## Why v2?

### v1 Approach (Relations Panel)
- **UI**: Split window relations panel (persistent)
- **Focus**: Custom UI with coupling analysis
- **Integration**: Standalone plugin with custom commands
- **Features**: Relations panel, focus mode, coupling metrics, session management

### Approach (Breadcrumb Navigation)
- **UI**: Hotkey-triggered breadcrumbs (minimal footprint)
- **Focus**: Extends built-in Neovim functionality
- **Integration**: Enhances jumplist and LSP (doesn't replace)
- **Features**: Project-aware history, intelligent pruning, breadcrumb navigation

### Rationale for 

1. **Less Intrusive**: Hotkey-triggered vs persistent panel
2. **Better Integration**: Extends Neovim built-ins rather than replacing
3. **More Efficient**: Intelligent pruning, lazy loading, project-aware
4. **Cleaner Architecture**: Focused on core navigation history

## What Can Be Reused from v1?

### ✅ Ready to Port

**LSP Integration Patterns** (`lua/spaghetti-comb-v1/analyzer.lua`)
- LSP client detection
- Symbol extraction
- Reference/definition finding
- Call hierarchy queries
- **Port to**: `lua/spaghetti-comb/navigation/lsp.lua`

**Coupling Analysis** (`lua/spaghetti-comb-v1/coupling/`)
- `metrics.lua` - Coupling calculation algorithms
- `graph.lua` - Graph visualization concepts
- **Port to**: New `lua/spaghetti-comb/coupling/` module (if needed)

**Navigation Stack Concepts** (`lua/spaghetti-comb-v1/navigation.lua`)
- Stack management patterns
- Bidirectional navigation
- Context preservation
- **Adapt for**: `lua/spaghetti-comb/history/manager.lua` (already has similar concepts)

**Storage Patterns** (`lua/spaghetti-comb-v1/persistence/storage.lua`)
- Session save/load
- File-based persistence
- **Port to**: `lua/spaghetti-comb/history/storage.lua`

**Bookmark Management** (`lua/spaghetti-comb-v1/persistence/bookmarks.lua`)
- Bookmark creation/removal
- Bookmark collections
- **Port to**: `lua/spaghetti-comb/history/bookmarks.lua`

**Code Preview** (`lua/spaghetti-comb-v1/ui/preview.lua`)
- Code context extraction
- Preview window management
- Syntax highlighting
- **Port to**: `lua/spaghetti-comb/ui/preview.lua`

**Utilities** (`lua/spaghetti-comb-v1/utils.lua`)
- Helper functions
- Common patterns
- **Review and port**: Useful utilities to `lua/spaghetti-comb/utils/`

### ❌ Not Needed in 

**Relations Panel UI** (`lua/spaghetti-comb-v1/ui/relations.lua`)
- uses breadcrumb approach, not split window panel
- Concepts may be useful for floating tree, but different implementation

**Highlights** (`lua/spaghetti-comb-v1/ui/highlights.lua`)
- will have different highlighting needs
- Review for useful patterns

**Error Handling** (`lua/spaghetti-comb-v1/error_handling.lua`)
- Review for patterns, but has different error handling strategy

## Migration Path

### Phase 1: Port Core Functionality
1. ✅ History manager (already implemented in v2)
2. 🚧 LSP integration (port from v1 analyzer.lua)
3. 🚧 Storage patterns (port from v1 persistence/storage.lua)
4. 🚧 Bookmark management (port from v1 persistence/bookmarks.lua)

### Phase 2: Port UI Components
1. 🚧 Code preview (port from v1 ui/preview.lua)
2. 🚧 Breadcrumb rendering (new, but may use v1 UI patterns)
3. 🚧 Floating tree (new, but may use v1 relations panel concepts)

### Phase 3: Port Advanced Features
1. 🚧 Coupling analysis (port from v1 coupling/ if needed)
2. 🚧 Session management (port from v1 persistence/storage.lua)

### Phase 4: Remove v1 Code
1. Remove `lua/spaghetti-comb-v1/` directory
2. Remove `plugin/spaghetti-comb-v1.lua`
3. Remove `tests-v1/` directory
4. Update documentation

## Porting Checklist

### LSP Integration
- [ ] Port LSP client detection from `analyzer.lua`
- [ ] Port symbol extraction logic
- [ ] Port reference/definition finding
- [ ] Adapt for architecture (extend, don't replace)
- [ ] Add to `lua/spaghetti-comb/navigation/lsp.lua`

### Storage Patterns
- [ ] Port session save/load from `persistence/storage.lua`
- [ ] Adapt for data models (NavigationTrail)
- [ ] Add optional persistence to `lua/spaghetti-comb/history/storage.lua`

### Bookmark Management
- [ ] Port bookmark creation/removal from `persistence/bookmarks.lua`
- [ ] Adapt for data models (BookmarkEntry)
- [ ] Add to `lua/spaghetti-comb/history/bookmarks.lua`

### Code Preview
- [ ] Port preview functionality from `ui/preview.lua`
- [ ] Adapt for UI components (floating tree, picker)
- [ ] Add to `lua/spaghetti-comb/ui/preview.lua`

### Coupling Analysis (Optional)
- [ ] Review coupling metrics from `coupling/metrics.lua`
- [ ] Determine if needed in (may not be)
- [ ] Port if needed

## Breaking Changes

### API Changes
- v1: `require('spaghetti-comb-v1').setup()`
- : `require('spaghetti-comb').setup()`

### Configuration Changes
- v1: `relations`, `coupling`, `languages` config sections
- : `display`, `history`, `integration`, `visual`, `bookmarks`, `debug` config sections
- No direct mapping - new configuration schema

### Command Changes
- v1: `:SpaghettiCombv2Show`, `:SpaghettiCombv2References`, etc.
- : New command set (TBD, but will be different)

### Keymap Changes
- v1: `<leader>sr`, `<leader>sf`, etc.
- : New keymap set (TBD, but will be different)

### Feature Removals
- Relations panel (replaced by breadcrumbs)
- Focus mode (replaced by floating tree)
- Coupling analysis UI (may be ported later)

## Migration Steps for Users

1. **Backup v1 configuration** (if using v1)
2. **Remove v1 plugin** from Neovim config
3. **Install plugin**
4. **Update configuration** to schema
5. **Update keymaps** to keymaps
6. **Learn new workflow** (breadcrumbs vs relations panel)

## Timeline

- **Current**: in active development
- **v1 Removal**: After core features are complete and ported
- **Migration Support**: Documentation only (no automated migration)

## Questions?

See [DEVELOPER.md](DEVELOPER.md) for development details or [SPEC.md](SPEC.md) for feature specifications.

