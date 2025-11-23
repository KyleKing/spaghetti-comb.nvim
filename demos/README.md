# Spaghetti Comb Demo Scenarios

This directory contains comprehensive demo scenarios showcasing all features of Spaghetti Comb.

## Demo Files

### 1. `basic_usage.lua` - Basic Navigation
Demonstrates core functionality:
- Recording and navigating jumps
- Creating branching paths
- Bookmark management
- UI components overview
- Persistence features

**Run:**
```vim
:lua require('demos.basic_usage').run_all()
```

### 2. `lsp_integration.lua` - LSP Integration
Shows how Spaghetti Comb enhances LSP navigation:
- Definition tracking
- Reference finding
- Call hierarchy navigation
- Workspace symbol search
- Exploration state tracking

**Run:**
```vim
:lua require('demos.lsp_integration').run_all()
```

### 3. `advanced_features.lua` - Advanced Features
Demonstrates intelligent features:
- Inconsequential jump pruning
- Automatic frequent location detection
- Multi-project workflows
- Location recovery after code changes
- Branch visualization
- Performance metrics

**Run:**
```vim
:lua require('demos.advanced_features').run_all()
```

### 4. `run_all.lua` - Complete Demo Suite
Runs all demos sequentially with interactive pauses.

**Run:**
```vim
:lua require('demos.run_all').execute()
```

## Quick Start

### Option 1: Run All Demos
```vim
:lua require('demos.run_all').execute()
```

### Option 2: Run Individual Demo
```vim
:lua require('demos.basic_usage').run_all()
:lua require('demos.lsp_integration').run_all()
:lua require('demos.advanced_features').run_all()
```

### Option 3: Run Specific Demo Section
```lua
local demo = require('demos.basic_usage')
demo.setup()
demo.navigate_between_files()
demo.bookmark_management()
```

## Interactive UI Demos

Some features require an active Neovim session to see the UI:

1. **Breadcrumbs** - `:SpaghettiCombBreadcrumbs`
   - Shows navigation trail in floating window
   - Use `j/k` to navigate, `Enter` to jump
   - Press `q` to close

2. **Navigation Tree** - `:SpaghettiCombTree`
   - Unicode tree visualization with preview
   - Split-screen layout
   - Vim motions for navigation

3. **Bookmark Picker** - `:SpaghettiCombBookmarks`
   - Shows all bookmarks
   - Integrates with mini.pick if available
   - Quick navigation to bookmarked locations

4. **History Picker** - `:SpaghettiCombHistory`
   - Browse navigation history
   - Filter by jump type
   - Quick access to recent locations

## Demo Workflow

For the best experience, follow this workflow:

1. **Start Fresh:**
   ```vim
   :lua require('spaghetti-comb').setup({})
   ```

2. **Run Basic Demo:**
   ```vim
   :lua require('demos.basic_usage').run_all()
   ```

3. **Try UI Commands:**
   ```vim
   :SpaghettiCombBreadcrumbs
   :SpaghettiCombTree
   :SpaghettiCombBookmarks
   ```

4. **Explore LSP Integration:**
   - Navigate your actual codebase
   - Use LSP commands (gd, gr, etc.)
   - See automatic tracking in `:SpaghettiCombHistory`

5. **Test Persistence:**
   ```vim
   :SpaghettiCombSaveHistory
   :SpaghettiCombSaveBookmarks
   :SpaghettiCombStorageStats
   ```

## Expected Output

Each demo produces console output showing:
- ✓ Successful operations
- ✗ Failed operations (rare in demos)
- 📊 Statistics and metrics
- 🔍 Current state information
- 💡 Tips and recommendations

## Customizing Demos

You can modify any demo file to test different scenarios:

```lua
local demo = require('demos.basic_usage')

-- Custom configuration
demo.setup()  -- Or pass custom config

-- Run specific tests
demo.navigate_between_files()
demo.bookmark_management()

-- Your custom test
local history_manager = require('spaghetti-comb.history.manager')
-- ... your code here
```

## Demo Coverage

These demos cover:

### Core Features (✓)
- [x] Navigation history recording
- [x] Branching path creation
- [x] Forward/backward navigation
- [x] History statistics

### Bookmarks (✓)
- [x] Manual bookmarks
- [x] Automatic frequent locations
- [x] Bookmark toggle
- [x] Bookmark persistence

### LSP Integration (✓)
- [x] Definition tracking
- [x] Reference tracking
- [x] Call hierarchy
- [x] Workspace symbols
- [x] Jump type classification

### Intelligent Features (✓)
- [x] Inconsequential jump pruning
- [x] Location recovery
- [x] Exploration state detection
- [x] Multi-project separation

### UI Components (✓)
- [x] Breadcrumbs display
- [x] Tree visualization
- [x] Picker integration
- [x] Statusline integration

### Persistence (✓)
- [x] History save/load
- [x] Bookmark save/load
- [x] Storage statistics
- [x] Cleanup operations

### Performance (✓)
- [x] Large history handling
- [x] Navigation performance
- [x] Memory usage
- [x] Pruning efficiency

## Troubleshooting

**Demo doesn't run:**
- Ensure plugin is installed: `:lua require('spaghetti-comb')`
- Check for errors: `:messages`

**UI components not showing:**
- Requires active buffers for full demo
- Some features need LSP attached

**No output visible:**
- Check `:messages` for demo output
- Some output may be in statusline

## Contributing Demos

To add a new demo:

1. Create `demos/your_demo.lua`
2. Follow the existing structure:
   ```lua
   local demo = {}

   function demo.setup()
       -- Setup code
   end

   function demo.your_feature()
       -- Demo code with print statements
   end

   function demo.run_all()
       -- Run all demos
   end

   return demo
   ```
3. Add to `demos/run_all.lua`
4. Update this README

## Next Steps

After exploring the demos:
- Read [SPEC.md](../SPEC.md) for detailed specifications
- Check [DEVELOPER.md](../DEVELOPER.md) for development guide
- Review [README.md](../README.md) for usage documentation
- Explore the test suite in `lua/spaghetti-comb/tests/`

Happy exploring! 🍝🧐
