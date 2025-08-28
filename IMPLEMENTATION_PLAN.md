# Spaghetti Comb - Neovim Plugin Implementation Plan

## Overview

**Spaghetti Comb** is a Neovim plugin designed to help developers untangle complex codebases by visualizing code relationships and dependencies. The name is a playful reference to "spaghetti code" - this plugin serves as a "comb" to help untangle and understand intricate code relationships.

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
├── spaghetti-comb/
│   ├── init.lua              -- Main plugin interface and setup
│   ├── analyzer.lua          -- LSP-based code analysis and symbol extraction
│   ├── navigation.lua        -- Navigation stack management and history
│   ├── ui/
│   │   ├── floating.lua      -- Floating window management for Relations panel
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
local SpaghettiComb = {
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

- `:SpaghettiCombShow` - Show Relations panel for symbol under cursor
- `:SpaghettiCombReferences` - Show where current function is used
- `:SpaghettiCombDefinition` - Show where symbol is defined
- `:SpaghettiCombNext` - Navigate forward in exploration stack
- `:SpaghettiCombPrev` - Navigate backward in exploration stack
- `:SpaghettiCombToggle` - Toggle Relations panel visibility
- `:SpaghettiCombSave` - Save current exploration session
- `:SpaghettiCombLoad` - Load saved exploration session

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
- `<Tab>` - Expand/collapse code preview
- `m` - Toggle bookmark for selected item
- `c` - Show coupling metrics for selected item
- `q` - Close Relations panel

### UI Layout

```
┌─ Main Buffer ──────────────────┐  ┌─ Relations Panel ──────────────────┐
│ function calculateTotal() {     │  │ Relations for 'calculateTotal':    │
│   const tax = getTax();         │  │                                    │
│   const discount = getDiscount();│  │ References (3):                   │
│   return base + tax - discount; │  │ ├─ 📄 checkout.ts:42 [C:0.7]     │
│ }  <-- cursor                   │  │ ├─ 📄 invoice.ts:18 [C:0.4]      │
│                                 │  │ └─ 📄 report.ts:95 [C:0.2]       │
│                                 │  │                                    │
│                                 │  │ Definitions (1):                   │
│                                 │  │ └─ 📄 utils/calc.ts:25            │
│                                 │  │                                    │
│                                 │  │ Outgoing Calls (2):               │
│                                 │  │ ├─ getTax() [C:0.8]               │
│                                 │  │ └─ getDiscount() [C:0.3]          │
│                                 │  │                                    │
│                                 │  │ [Preview: getTax() expanded]       │
│                                 │  │ function getTax(amount: number) {  │
│                                 │  │   return amount * TAX_RATE;       │
│                                 │  │ }                                  │
└─────────────────────────────────┘  └────────────────────────────────────┘
```

**Legend:**

- `[C:0.7]` - Coupling metric (0.0 = loose, 1.0 = tight)
- 📄 - File icon
- Expandable previews show code context

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

### Phase 1: Core Infrastructure (Week 1)

**Implementation Goals:**

- Set up plugin structure and initialization system
- Implement basic LSP client integration for TypeScript/JavaScript
- Create floating window management system for Relations panel
- Add fundamental navigation stack operations (push/pop/peek)

**Testing Goals:**

- Set up mini.test framework with child Neovim processes
- Create basic LSP mock responses for testing
- Test floating window creation and destruction
- Verify navigation stack operations

**Deliverables:**

- Working plugin structure with proper Neovim integration
- Basic floating window that can display text
- Navigation stack with history preservation
- Test suite covering core functionality

### Phase 2: Basic Symbol Analysis (Week 2)

**Implementation Goals:**

- Implement symbol analysis and extraction for target languages
- Add references and definitions lookup with LSP integration
- Create basic Relations panel UI for displaying results
- Implement cursor-based symbol detection and context awareness

**Testing Goals:**

- Add comprehensive LSP integration tests
- Create symbol extraction test cases for each target language
- Test Relations panel rendering with various data sets
- Verify cursor position tracking and symbol detection

**Deliverables:**

- Working symbol analysis for TypeScript, JavaScript, Python
- Relations panel displaying references and definitions
- Cursor-based symbol detection
- Expanded test suite with language-specific test cases

### Phase 3: Advanced Navigation Features (Week 3)

**Implementation Goals:**

- Add call hierarchy support (incoming/outgoing calls)
- Implement full navigation stack with bidirectional history
- Add context preservation and restoration between sessions
- Create configurable key mappings and user commands

**Testing Goals:**

- Test call hierarchy integration with LSP servers
- Verify navigation stack persistence across plugin restarts
- Test key mapping registration and command execution
- Create integration tests for multi-step navigation workflows

**Deliverables:**

- Complete call hierarchy visualization
- Bidirectional navigation with stack history
- Configurable key mappings
- Session persistence functionality

### Phase 4: Code Previews and Polish (Week 4)

**Implementation Goals:**

- Add expandable code preview functionality within Relations panel
- Implement comprehensive error handling and graceful degradation
- Create fallback mechanisms (treesitter, grep) for non-LSP scenarios
- Add syntax highlighting for Relations panel content

**Testing Goals:**

- Test code preview expansion and syntax highlighting
- Create error handling test scenarios (LSP unavailable, malformed responses)
- Test fallback mechanisms with various file types
- Add performance tests for large codebases

**Deliverables:**

- Expandable code previews with syntax highlighting
- Robust error handling and fallback systems
- Performance optimizations for large projects
- Comprehensive test coverage

### Phase 5: Coupling Analysis and Persistence (Week 5)

**Implementation Goals:**

- Implement coupling metrics calculation and display
- Add numerical evaluation of code relationships ([C:0.7] indicators)
- Create persistence system for bookmarked items and sessions
- Add filtering and search capabilities within Relations panel

**Testing Goals:**

- Test coupling metrics accuracy across different code patterns
- Verify persistence system with save/load operations
- Test filtering and search functionality with large datasets
- Create performance benchmarks for coupling analysis

**Deliverables:**

- Coupling metrics integration with visual indicators
- Persistent bookmarks and session management
- Advanced filtering and search capabilities
- Complete test suite with performance validation

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
require('spaghetti-comb').setup({
  -- Relations panel configuration
  relations = {
    width = 50,
    height = 20,
    position = 'right',
    auto_preview = true,
    show_coupling = true
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
    toggle_preview = '<Tab>',
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

This implementation plan provides a comprehensive roadmap for building Spaghetti Comb into a powerful code exploration tool that helps developers untangle complex codebases through intelligent relationship visualization and navigation.

