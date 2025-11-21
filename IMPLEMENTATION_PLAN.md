# Spaghetti Comb v2 - Neovim Plugin Implementation Plan

## Overview

**Spaghetti Comb v2** is a Neovim plugin designed to help developers untangle complex codebases by visualizing code relationships and dependencies. The name is a playful reference to "spaghetti code" - this plugin serves as a "comb" to help untangle and understand intricate code relationships.

### User Story

> When exploring a code base that I am unfamiliar with, I want to be able to see contextual information on demand. This information should include where and how the current function is used, where and how the code under the cursor is defined, and allow navigating further to the right or to the left as the stack is explored.

### Target Languages (Priority Order)

1. TypeScript
1. JavaScript
1. Python
1. Rust
1. GoLang

## Core Architecture

### Plugin Structure

```
lua/
├── spaghetti-comb-v2/
│   ├── init.lua              -- Main plugin interface and setup
│   ├── analyzer.lua          -- LSP-based code analysis and symbol extraction
│   ├── navigation.lua        -- Navigation stack management and history
│   ├── ui/
│   │   ├── relations.lua     -- Split window management for Relations panel
│   │   ├── highlights.lua    -- Syntax highlighting and visual styling
│   │   └── preview.lua       -- Code preview expansion functionality
│   ├── coupling/
│   │   ├── metrics.lua       -- Coupling analysis and numerical evaluation
│   │   └── graph.lua         -- Graph visualization with coupling data
│   ├── persistence/
│   │   ├── storage.lua       -- Save/load selected items and sessions
│   │   └── bookmarks.lua     -- Bookmark frequently accessed symbols
│   └── utils.lua             -- Shared utilities and helper functions
```

### Global Plugin Object

```lua
local SpaghettiCombv2 = {
  config = {},
  state = {
    navigation_stack = {},
    relations_window = nil,
    active_session = nil
  }
}
```

## User Interface Design

### Primary Commands

- `:SpaghettiCombv2Show` - Show Relations panel for symbol under cursor
- `:SpaghettiCombv2References` - Show where current function is used
- `:SpaghettiCombv2Definition` - Show where symbol is defined
- `:SpaghettiCombv2Next` - Navigate forward in exploration stack
- `:SpaghettiCombv2Prev` - Navigate backward in exploration stack
- `:SpaghettiCombv2Toggle` - Toggle Relations panel visibility
- `:SpaghettiCombv2Save` - Save current exploration session
- `:SpaghettiCombv2Load` - Load saved exploration session

### Key Mappings (Default)

- `<leader>sr` - Show Relations panel
- `<leader>sf` - Show references (find usages)
- `<leader>sd` - Go to definition
- `<leader>sn` - Navigate forward in stack
- `<leader>sp` - Navigate backward in stack
- `<leader>ss` - Save current session
- `<leader>sl` - Load session

**Within Relations Panel:**

- `<CR>` - Navigate to selected item
- `<C-]>` - Navigate deeper (explore selected symbol)
- `<C-o>` - Navigate back in stack
- `<Tab>` - Toggle focus mode (expand window + side preview)
- `m` - Toggle bookmark for selected item
- `c` - Show coupling metrics for selected item
- `q` - Close Relations panel

### UI Layout

**Normal Mode** (horizontal split):

```
┌─ Main Buffer ──────────────────────────────────────┐
│ function calculateTotal() {                        │
│   const tax = getTax();                            │
│   const discount = getDiscount();                  │
│   return base + tax - discount;                    │
│ }  <-- cursor                                      │
│                                                    │
│                                                    │
├─ Relations Panel ──────────────────────────────────┤
│ Relations for 'calculateTotal':                    │
│                                                    │
│ References (3):                                    │
│ ├─ 📄 checkout.ts:42 [C:0.7]                     │
│ ├─ 📄 invoice.ts:18 [C:0.4]                      │
│ └─ 📄 report.ts:95 [C:0.2]                       │
│                                                    │
│ Definitions (1):                                   │
│ └─ 📄 utils/calc.ts:25                            │
│                                                    │
│ Outgoing Calls (2):                               │
│ ├─ getTax() [C:0.8]                               │
│ └─ getDiscount() [C:0.3]          <Tab> = Focus   │
└────────────────────────────────────────────────────┘
```

**Focus Mode** (expanded with side preview):

```
┌─ Main Buffer ──────────────────────────────────────┐
│ function calculateTotal() {                        │
│   const tax = getTax();                            │
│   return base + tax - discount;                    │
│ }  <-- cursor                                      │
├─ Relations Panel ───────────────┬─ Preview ────────┤
│ Relations for 'calculateTotal': │ [Preview: getTax │
│                                 │  function getTax │
│ References (3):                 │  1 │ function get│
│ ├─ 📄 checkout.ts:42 [C:0.7]   │  2 │   return amo│
│ ├─ 📄 invoice.ts:18 [C:0.4]    │  3 │ }           │
│ └─ 📄 report.ts:95 [C:0.2]     │                  │
│                                 │ Use j/k to navig│
│ Definitions (1):                │ in relations pan│
│ └─ 📄 utils/calc.ts:25          │ to update previe│
│                                 │                  │
│ Outgoing Calls (2):             │ <Tab> = Exit Foc│
│ ├─ getTax() [C:0.8]       <--   │                  │
│ └─ getDiscount() [C:0.3]        │                  │
│                                 │                  │
│ <Tab> = Exit Focus              │                  │
└─────────────────────────────────┴──────────────────┘
```

**Legend:**

- `[C:0.7]` - Coupling metric (0.0 = loose, 1.0 = tight)
- 📄 - File icon
- Use vim motions (j/k, arrow keys) to navigate in relations panel
- Focus mode provides expanded view with automatic preview updates
- Split window behavior similar to vim's `:help` command

## LSP Integration Strategy

### Core LSP Methods

- `textDocument/references` - Find all references to symbol
- `textDocument/definition` - Jump to symbol definition
- `textDocument/declaration` - Jump to symbol declaration
- `textDocument/typeDefinition` - Find type definitions
- `textDocument/implementation` - Find implementations
- `callHierarchy/incomingCalls` - Who calls this function
- `callHierarchy/outgoingCalls` - What this function calls

### Language-Specific Considerations

**TypeScript/JavaScript:**

- Handle module imports/exports
- Distinguish between type and value references
- Support JSX component relationships

**Python:**

- Handle import statements and module structure
- Support class inheritance relationships
- Manage virtual environment contexts

**Rust:**

- Handle trait implementations and bounds
- Support macro expansions
- Manage crate dependencies

**GoLang:**

- Handle package relationships
- Support interface implementations
- Manage module dependencies

### Fallback Mechanisms

1. **Primary**: Use active LSP client for current buffer
1. **Secondary**: Query multiple LSP clients if available
1. **Tertiary**: Use treesitter for basic symbol extraction
1. **Fallback**: Grep-based search for symbol names

### Data Processing Pipeline

```lua
local function process_lsp_response(method, response)
  return {
    symbol = extract_symbol_info(response),
    locations = normalize_locations(response),
    context = extract_surrounding_context(response),
    coupling_data = calculate_coupling_metrics(response)
  }
end
```

## Navigation Stack System

### Stack Structure

```lua
local navigation_stack = {
  current_index = 1,
  entries = {
    {
      symbol = "calculateTotal",
      file = "/path/to/utils/calc.ts",
      line = 25,
      col = 9,
      type = "function",
      language = "typescript",
      references = {...},
      definitions = {...},
      coupling_score = 0.65,
      timestamp = os.time(),
      bookmarked = false
    }
  }
}
```

### Navigation Operations

- **Push**: Add new exploration context to stack
- **Pop**: Return to previous context
- **Peek**: View current context without changing position
- **Navigate Left**: Go to references/callers (who uses this)
- **Navigate Right**: Go to definitions/callees (what this uses)
- **Jump**: Direct navigation to specific location

### Context Preservation

- Save cursor position for each stack entry
- Preserve window layout and splits
- Maintain search highlighting state
- Cache LSP responses to avoid redundant queries
- Store expanded preview states

## Implementation Phases

### Phase 1: Core Infrastructure ✅ COMPLETED

**Delivered:**
- Plugin structure with proper Neovim integration and configuration system
- Split window management for Relations panel with focus mode
- Navigation stack with bidirectional history (push/pop/peek/jump operations)
- Mini.test framework setup with comprehensive test suite (51 tests passing)

### Phase 2: Symbol Analysis & LSP Integration ✅ COMPLETED  

**Delivered:**
- LSP integration for references, definitions, and call hierarchy
- Symbol analysis with cursor-based detection
- Relations panel UI with filtering, sorting, and search capabilities
- Multi-language support (TypeScript, JavaScript, Python, Rust, Go, Lua)

### Phase 3: Advanced Features & Polish ✅ COMPLETED

**Delivered:**
- Focus mode with side-by-side preview functionality
- Expandable code previews with syntax highlighting
- Comprehensive error handling and fallback mechanisms (treesitter, grep)
- Bookmark system with collections and persistence
- Session management with save/load functionality

### Phase 4: Coupling Analysis ✅ COMPLETED

**Delivered:**
- Coupling metrics calculation and visual indicators ([C:0.7] format)
- Color-coded coupling strength visualization
- Advanced filtering by coupling levels (high/medium/low)
- Performance optimizations for large codebases

### Phase 5: User Experience Refinements ✅ COMPLETED

**Delivered:**
- Configurable logging system with silent mode (non-obtrusive)
- Vim motion navigation within Relations panel
- Interactive keybindings and user commands
- Comprehensive documentation and usage examples

### Phase 6: Breadcrumb Navigation System 🚧 PLANNED

**Implementation Goals:**

- **Visual Context Tracking**: Implement breadcrumb trail showing exploration path
- **Statusline Integration**: Primary display via vim statusline with adaptive formatting  
- **Smart Navigation**: Click/keyboard shortcuts to jump to any breadcrumb level
- **Coupling Visualization**: Color-coded breadcrumbs based on coupling scores

**Core Components:**

```lua
-- New module structure
lua/spaghetti-comb-v2/ui/
├── breadcrumbs.lua          -- Core breadcrumb logic and display
├── breadcrumb_menu.lua      -- Interactive navigation menu
└── statusline.lua           -- Statusline integration helpers
```

**Data Structure:**
```lua
breadcrumb_trail = {
  entries = {
    {symbol = "UserService", file = "main.ts", type = "class", coupling = 0.5},
    {symbol = "authenticate", file = "main.ts", type = "method", coupling = 0.6}, 
    {symbol = "validateToken", file = "auth.ts", type = "function", coupling = 0.8},
    {symbol = "jwt.decode", file = "auth.ts", type = "call", coupling = 0.9}, -- current
  },
  current_depth = 4,
  display_cache = "main.ts › UserService › authenticate › validateToken [4/7]"
}
```

**User Interface:**

*Statusline Display (Primary):*
```
main.ts › UserService › authenticate › validateToken ← 4/7 📄 [C:0.8]
```

*Relations Panel Header (Alternative):*
```
├─ Relations Panel ───────────────────────────────────────────────────────┤
│ 🍞 main.ts › UserService › authenticate › validateToken [4/7]          │ 
│ Relations for 'jwt.decode':                                             │
│ References (12):                                                        │
```

**Configuration Options:**
```lua
breadcrumbs = {
  enabled = true,
  location = "statusline",        -- "statusline", "relations_header"
  max_length = 60,               -- Display truncation limit
  max_items = 5,                 -- Maximum breadcrumb segments
  separator = " › ",             -- Symbol separator  
  show_position = true,          -- Show [4/7] position indicator
  show_coupling = true,          -- Show coupling scores with colors
  
  keymaps = {
    show_menu = "gb",            -- Show navigation menu
    toggle_visibility = "<C-b>", -- Toggle breadcrumb display
    jump_to_level = {"g1", "g2", "g3", "g4", "g5"}, -- Direct level access
  }
}
```

**Technical Implementation:**

- **Event Integration**: Hook into navigation.push/pop/jump events
- **Performance**: Cached display strings with lazy updates  
- **LSP Enhancement**: Use document symbols for hierarchical context
- **Statusline Compatibility**: Integration with lualine, staline, etc.
- **Smart Truncation**: Preserve current + root symbols, truncate middle

**Testing Goals:**

- Test breadcrumb updates on navigation events
- Verify statusline integration across different setups
- Test truncation logic with various path lengths
- Validate coupling score display and color coding
- Test interactive navigation menu functionality

**Deliverables:**

- Breadcrumb trail visualization in statusline
- Interactive navigation menu with keyboard shortcuts
- Configurable display options and theming
- Integration with existing navigation stack
- Comprehensive test coverage for breadcrumb functionality

**User Experience Benefits:**

- **Never lose context** during deep code exploration
- **Visual hierarchy** showing relationship between exploration levels  
- **Efficient navigation** with one-click access to any previous level
- **Coupling awareness** through color-coded path visualization

## Future Planned Features

### Coupling Analysis Engine

- **Numerical Coupling Evaluation**: Calculate coupling strength between symbols
    - Structural coupling (direct dependencies)
    - Data coupling (shared data structures)
    - Control coupling (control flow dependencies)
    - Content coupling (internal data access)
- **Coupling Visualization**:
    - Color-coded coupling strength indicators
    - Coupling trend analysis over time
    - Hotspot identification for refactoring candidates
- **Metrics Dashboard**: Summary view of project coupling health

### Enhanced Code Previews

- **Multi-level Preview Expansion**: Expand nested function calls
- **Interactive Preview Navigation**: Click-to-navigate within previews
- **Preview Diff Mode**: Compare different implementations
- **Context-Aware Previews**: Show relevant surrounding code based on usage

### Advanced Persistence Features

- **Session Management**: Save and restore complete exploration sessions
- **Bookmark Collections**: Organize bookmarks into named collections
- **Export Capabilities**: Export relationship graphs to external formats
- **Team Sharing**: Share exploration sessions and bookmarks with team members

### Intelligence Features

- **Smart Suggestions**: Recommend related symbols to explore
- **Usage Patterns**: Identify common usage patterns and anti-patterns
- **Refactoring Hints**: Suggest refactoring opportunities based on coupling analysis
- **Code Impact Analysis**: Visualize potential impact of changes

## Technical Considerations

### Performance Optimizations

- **Lazy Loading**: Load LSP responses on-demand to avoid blocking UI
- **Response Caching**: Cache frequently accessed symbol information
- **Debounced Updates**: Use debouncing for rapid cursor movements
- **Virtual Text Rendering**: Handle large result sets efficiently
- **Background Processing**: Perform coupling analysis asynchronously

### Compatibility Requirements

- **Multi-LSP Support**: Work with multiple LSP clients simultaneously
- **Graceful Degradation**: Function when LSP is unavailable
- **Cross-Language Support**: Handle polyglot projects seamlessly
- **Neovim Integration**: Work with existing navigation (tags, quickfix, telescope)

### User Experience Goals

- **Contextual Information**: Display relevant information based on cursor position
- **Smooth Transitions**: Provide fluid navigation between exploration levels
- **Visual Feedback**: Clear indicators for navigation state and coupling strength
- **Customizable Interface**: Configurable display preferences and key mappings

## Configuration Example

```lua
require('spaghetti-comb-v2').setup({
  -- Relations panel configuration
  relations = {
    height = 15,              -- Normal split height
    focus_height = 30,        -- Expanded height in focus mode
    position = 'bottom',      -- Split position
    auto_preview = true,      -- Auto-update preview in focus mode
    show_coupling = true      -- Show coupling metrics
  },

  -- Language-specific settings
  languages = {
    typescript = { enabled = true, coupling_analysis = true },
    javascript = { enabled = true, coupling_analysis = true },
    python = { enabled = true, coupling_analysis = true },
    rust = { enabled = true, coupling_analysis = false },
    go = { enabled = true, coupling_analysis = false }
  },

  -- Key mappings
  keymaps = {
    show_relations = '<leader>sr',
    toggle_focus_mode = '<Tab>',
    bookmark_item = 'm',
    save_session = '<leader>ss'
  },

  -- Coupling analysis settings
  coupling = {
    enabled = true,
    threshold_high = 0.7,
    threshold_medium = 0.4,
    show_metrics = true
  }
})
```

## Testing Strategy

### Test Organization

- **Unit Tests**: Individual component testing (analyzer, navigation, UI)
- **Integration Tests**: LSP integration and cross-component communication
- **Language Tests**: Language-specific functionality verification
- **Performance Tests**: Large codebase and response time validation
- **User Workflow Tests**: End-to-end user interaction scenarios

### Test Infrastructure

- Use `mini.test` framework with child Neovim processes
- Mock LSP servers for consistent test environments
- Screenshot testing for UI validation
- Performance benchmarking for optimization validation

This implementation plan provides a comprehensive roadmap for building Spaghetti Comb v2 into a powerful code exploration tool that helps developers untangle complex codebases through intelligent relationship visualization and navigation.
