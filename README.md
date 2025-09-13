# nvim-navigation-breadcrumbs

A Neovim plugin that extends built-in navigation capabilities with a visual, non-obtrusive breadcrumb system for efficient codebase exploration.

## Project Structure

```
lua/nvim-navigation-breadcrumbs/
├── init.lua              -- Main plugin entry point
├── config.lua            -- Configuration management with validation
├── types.lua             -- Core data model interfaces and types
├── history/              -- Navigation history management
│   ├── manager.lua       -- Core history tracking logic
│   ├── storage.lua       -- Persistence and pruning
│   ├── events.lua        -- Navigation event handling
│   └── bookmarks.lua     -- Sticky bookmarks and frequent locations
├── ui/                   -- User interface components
│   ├── breadcrumbs.lua   -- Visual breadcrumb rendering with collapse/expand
│   ├── floating_tree.lua -- Branch history floating window with unicode tree
│   ├── preview.lua       -- Code preview functionality
│   ├── picker.lua        -- Integration with mini.pick (dual modes)
│   └── statusline.lua    -- Branch status display in statusline
├── navigation/           -- Enhanced navigation commands
│   ├── commands.lua      -- Enhanced navigation commands
│   ├── lsp.lua           -- LSP integration hooks
│   └── jumplist.lua      -- Jumplist enhancement
├── utils/                -- Utility modules
│   ├── project.lua       -- Project detection and management
│   └── debug.lua         -- Debug logging utilities
└── tests/                -- Test suite using mini.test
    ├── init.lua          -- Test runner
    ├── history_spec.lua  -- History manager tests
    ├── ui_spec.lua       -- UI component tests
    ├── navigation_spec.lua -- Navigation command tests
    └── integration_spec.lua -- Integration tests
```

## Core Data Models

### NavigationEntry
- Tracks individual navigation jumps with position recovery fields
- Includes original and current positions for line shift handling
- Supports visit counting for frequency detection
- Contains context information for previews

### NavigationTrail
- Manages sequences of navigation entries
- Supports branching navigation paths
- Project-aware with separate contexts per project

### BookmarkEntry
- Handles both manual and automatic bookmarks
- Tracks visit frequency for automatic promotion
- Includes code context for quick previews

## Configuration

The plugin uses a comprehensive configuration schema with sensible defaults:

- **Display**: Hotkey-only breadcrumbs with collapsible interface
- **History**: Intelligent pruning with 2-minute debounce and location recovery
- **Integration**: Extends built-in Neovim functionality (LSP, jumplist)
- **Visual**: Unicode tree rendering with subtle color schemes
- **Bookmarks**: Automatic frequent location detection
- **Debug**: Configurable logging following Neovim standards

## Development Status

This is the foundational setup for the plugin. All modules contain placeholder functions with TODO comments indicating which task will implement each feature. The structure follows the implementation plan defined in the spec.

## Testing

Tests are organized using mini.test framework with focus on high-signal integration tests:

```lua
-- Run all tests
require('nvim-navigation-breadcrumbs.tests').run_all()

-- Run specific test categories
require('nvim-navigation-breadcrumbs.tests').run_history()
require('nvim-navigation-breadcrumbs.tests').run_ui()
require('nvim-navigation-breadcrumbs.tests').run_navigation()
require('nvim-navigation-breadcrumbs.tests').run_integration()
```

## Next Steps

The project structure is now ready for implementation. Each module contains clear interfaces and placeholder functions that reference the specific tasks where they will be implemented. The next task in the implementation plan is "2.1 Create basic history tracking functionality".