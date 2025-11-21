# SPEC.md - Specification

Complete specification for Spaghetti Comb v2, including use cases, feature specifications, error handling strategies, limitations, and architecture decisions.

## Table of Contents

1. [Use Cases](#use-cases)
2. [Feature Specifications](#feature-specifications)
3. [Data Models](#data-models)
4. [Error Handling](#error-handling)
5. [Performance Requirements](#performance-requirements)
6. [Limitations](#limitations)
7. [Architecture Decisions](#architecture-decisions)

## Use Cases

### Primary Use Case

> When exploring a codebase that I am unfamiliar with, I want to be able to see contextual information on demand. This information should include where and how the current function is used, where and how the code under the cursor is defined, and allow navigating further to the right or to the left as the stack is explored.

### User Stories

**Requirement 1: Visual Navigation History**
- As a developer working in a large codebase, I want to see a visual trail of my navigation history, so that I can understand how I arrived at my current location and easily jump around my exploration path.

**Requirement 2: Code Relationship Exploration**
- As a developer exploring code relationships, I want to quickly jump to function definitions, implementations, and usage sites, so that I can understand code flow without losing track of where I started.

**Requirement 3: Efficient Backtracking**
- As a developer who frequently backtracks during code exploration, I want intuitive controls to navigate backward and forward through my history, so that I can efficiently retrace my steps without manual file switching.

**Requirement 4: Non-Intrusive UI**
- As a developer who values screen real estate, I want the navigation breadcrumbs to be visually subtle and non-intrusive, so that they enhance my workflow without cluttering my editing environment.

**Requirement 5: Performance**
- As a developer working with large codebases, I want the navigation system to be fast and responsive, so that it doesn't slow down my development workflow or consume excessive system resources.

**Requirement 6: Neovim Integration**
- As a developer who relies on Neovim's existing functionality, I want the navigation extension to integrate seamlessly with built-in features, so that I can leverage familiar workflows without learning entirely new paradigms.

**Requirement 7: Project Awareness**
- As a developer who works across different projects, I want the navigation history to be project-aware, so that navigation trails from different codebases don't interfere with each other.

**Requirement 8: Testability**
- As a developer who prioritizes maintainability, I want the plugin to have comprehensive test coverage, so that I can trust the functionality and contribute to the project with confidence.

**Requirement 9: Code Previews**
- As a developer who benefits from visual context, I want to see previews of code at different navigation points, so that I can quickly assess whether a location is relevant before jumping to it.

**Requirement 10: Bookmark System**
- As a developer, I want to be able to have a "sticky note" or to "highlight" important jump locations, either automatically detected based on frequency or manually, so that I can quickly access frequently visited or important code locations.

**Requirement 11: Debugging**
- As a developer who wants to debug issues, I want to optionally be able to turn on a debug log following standard practices and inspect all plugin operations to ensure correct behavior, so that I can troubleshoot problems and contribute to plugin development.

**Requirement 12: Statusline Integration**
- As a developer who wants contextual awareness of my exploration state, I want to see minimal branch information in my statusline, so that I can understand my current navigation context without opening additional windows.

## Feature Specifications

### Core Features

#### Navigation History Tracking

**Status**: ✅ Implemented

**Specification**:
- Automatically records navigation jumps (file changes, LSP jumps, manual navigation)
- Maintains separate history trails per project
- Supports branching navigation paths
- Tracks jump type (manual, lsp_definition, lsp_reference, etc.)
- Records context information (surrounding code, function name)

**Acceptance Criteria**:
- Records jumps between files and functions
- Maintains separate trails per project
- Supports branching paths
- Tracks jump metadata (type, timestamp, context)

#### Intelligent Pruning

**Status**: ✅ Implemented

**Specification**:
- Time-based pruning (default: 30 minutes)
- Inconsequential jump removal (small movements within same file)
- Location recovery for shifted line numbers
- Debounced pruning (2-minute delay)
- Marks unrecoverable locations as inactive

**Acceptance Criteria**:
- Prunes entries older than configurable limit
- Removes inconsequential jumps within same file
- Attempts to recover locations after line shifts
- Debounces pruning operations
- Preserves original line numbers for reference

#### Project-Aware History

**Status**: ✅ Implemented

**Specification**:
- Detects project root (git, workspace markers)
- Maintains separate history per project
- Auto-switches project context
- Clears history per project or globally

**Acceptance Criteria**:
- Detects project boundaries
- Maintains separate histories
- Auto-switches on project change
- Provides clear commands

### UI Features

#### Breadcrumb Navigation

**Status**: 🚧 Planned

**Specification**:
- Hotkey-triggered display (not persistent)
- Collapsible interface (mini.files-like)
- Visual distinction for entry types
- Unicode tree visualization
- Statusline integration

**Acceptance Criteria**:
- Shows only on hotkey press
- Collapses unfocused items
- Expands focused item and neighbors
- Visual indicators for bookmarks/frequent locations
- Minimal screen footprint

#### Floating Tree Window

**Status**: 🚧 Planned

**Specification**:
- Unicode box-drawing tree visualization
- Left panel: branch history tree
- Right panel: code preview
- Vim motion navigation
- Sorted by recency

**Acceptance Criteria**:
- Displays branch history visually
- Shows code preview for selected node
- Supports vim motions
- Sorted by most to least recent
- Visual markers for important nodes

#### Code Previews

**Status**: 🚧 Planned

**Specification**:
- Context-aware code snippets
- Syntax highlighting
- Fast loading (<5ms)
- Preview in picker and tree views

**Acceptance Criteria**:
- Shows relevant context around location
- Syntax highlighted
- Fast to load
- Available in picker and tree

#### Picker Integration

**Status**: 🚧 Planned

**Specification**:
- Dual-mode picker (bookmark/navigation)
- Fuzzy filtering (filename and code content)
- Frecency-based sorting (bookmarks)
- Recency-based sorting (navigation)
- Graceful fallback when mini.pick unavailable

**Acceptance Criteria**:
- Two modes: bookmark management and navigation
- Fuzzy search by filename or code
- Appropriate sorting per mode
- Works without mini.pick (fallback)

#### Statusline Integration

**Status**: 🚧 Planned

**Specification**:
- Minimal branch status display
- Active exploration indicator
- Idle state indicator
- Time-based exploration detection

**Acceptance Criteria**:
- Shows branch ID and depth when exploring
- Shows idle indicator when not exploring
- Minimal display (doesn't interfere)
- Updates based on navigation activity

### Integration Features

#### LSP Integration

**Status**: 🚧 Planned

**Specification**:
- Extends built-in LSP commands (doesn't replace)
- Records jumps from go-to-definition
- Records jumps from find-references
- Records jumps from go-to-implementation
- Graceful fallback when LSP unavailable

**Acceptance Criteria**:
- Extends rather than replaces built-in LSP
- Records all LSP-based jumps
- Works when LSP unavailable
- No conflicts with existing LSP usage

#### Jumplist Enhancement

**Status**: 🚧 Planned

**Specification**:
- Enhances Ctrl-O and Ctrl-I
- Integrates with built-in jumplist
- Maintains compatibility
- Adds history tracking

**Acceptance Criteria**:
- Works with Ctrl-O/Ctrl-I
- Doesn't break existing jumplist
- Adds value without conflicts
- Maintains backward compatibility

### Bookmark System

**Status**: 🚧 Planned

**Specification**:
- Manual bookmarks (user-created)
- Automatic frequent location detection
- Visit count tracking
- Bookmark persistence (optional)
- Visual distinction in UI

**Acceptance Criteria**:
- Manual bookmark creation/removal
- Automatic frequent location marking
- Tracks visit counts
- Persists bookmarks (optional)
- Visual indicators in UI

## Data Models

### NavigationEntry

```lua
NavigationEntry = {
  id = string,              -- Unique identifier
  file_path = string,       -- Absolute file path
  position = {              -- Current cursor position
    line = number,
    column = number
  },
  original_position = {     -- Original position before line shifts
    line = number,
    column = number
  },
  timestamp = number,       -- Unix timestamp
  jump_type = string,       -- "manual", "lsp_definition", "lsp_reference", etc.
  context = {               -- Surrounding code context
    before_lines = table,   -- Lines before cursor
    after_lines = table,    -- Lines after cursor
    function_name = string, -- Current function (if available)
  },
  project_root = string,    -- Project root directory
  branch_id = string,       -- Branch identifier for navigation paths
  visit_count = number,     -- Number of times visited (for frequency tracking)
  is_bookmarked = boolean,  -- Manual bookmark flag
  is_frequent = boolean,    -- Auto-detected frequent location
  is_active = boolean,      -- False if location is unrecoverable after pruning
  line_shifted = boolean,  -- True if position was recovered after line shift
  last_pruned = number,     -- Timestamp of last pruning attempt
}
```

### NavigationTrail

```lua
NavigationTrail = {
  entries = table,          -- Array of NavigationEntry
  current_index = number,   -- Current position in trail
  branches = table,         -- Map of branch_id to branch metadata
  project_root = string,    -- Associated project root
  created_at = number,      -- Trail creation timestamp
  last_accessed = number,   -- Last access timestamp
}
```

### BookmarkEntry

```lua
BookmarkEntry = {
  id = string,              -- Unique identifier
  file_path = string,       -- Absolute file path
  position = {              -- Cursor position
    line = number,
    column = number
  },
  timestamp = number,       -- Creation timestamp
  is_manual = boolean,      -- Manual vs automatic bookmark
  visit_count = number,    -- Number of visits
  context = {               -- Code context for preview
    before_lines = table,
    after_lines = table,
    function_name = string,
  },
  project_root = string,    -- Associated project
}
```

## Error Handling

### Error Categories

1. **File System Errors**
   - Files moved, deleted, or inaccessible
   - **Strategy**: Mark entries as inactive, attempt recovery, remove if unrecoverable

2. **LSP Errors**
   - LSP unavailable or returns errors
   - **Strategy**: Graceful degradation, fallback to basic navigation, log warnings

3. **Performance Errors**
   - Memory pressure, excessive history growth
   - **Strategy**: Aggressive pruning, memory limits, performance monitoring

4. **Configuration Errors**
   - Invalid configuration values
   - **Strategy**: Validate and provide defaults, log warnings

### Error Handling Patterns

**Graceful Degradation:**
```lua
local function safe_operation(operation, fallback)
  local success, result = pcall(operation)
  if success then
    return result
  else
    debug.error("Operation failed", { error = tostring(result) })
    vim.notify("Navigation breadcrumbs: " .. tostring(result), vim.log.levels.WARN)
    return fallback and fallback() or nil
  end
end
```

**File Accessibility:**
```lua
local function validate_file_access(file_path)
  if not vim.fn.filereadable(file_path) then
    debug.warn("File no longer accessible", { file = file_path })
    return false
  end
  return true
end
```

**LSP Availability:**
```lua
local function ensure_lsp_available()
  if not vim.lsp.get_active_clients() or #vim.lsp.get_active_clients() == 0 then
    debug.info("LSP not available, using fallback navigation")
    return false
  end
  return true
end
```

**Feature Detection:**
```lua
local function check_mini_pick_available()
  local has_mini_pick = pcall(require, 'mini.pick')
  if not has_mini_pick then
    debug.info("mini.pick not available, picker features disabled")
  end
  return has_mini_pick
end
```

## Performance Requirements

### Response Time Targets

- **Navigation operations**: < 50ms
- **File loading impact**: < 5ms additional delay
- **History pruning**: < 100ms
- **Preview loading**: < 5ms

### Memory Targets

- **Typical usage (1000 entries)**: < 10MB
- **Memory leaks**: None
- **Efficient data structures**: Required

### Optimization Strategies

- Lazy loading for preview content
- Cached display strings
- Debounced operations
- Efficient data structures
- Background processing where possible

## Limitations

### Current Limitations

1. **UI Components Not Implemented**
   - Breadcrumbs, floating tree, picker, statusline integration are planned but not yet implemented

2. **LSP Integration Incomplete**
   - LSP hooks are planned but not yet implemented
   - Currently only history tracking works

3. **Bookmark System Not Implemented**
   - Manual and automatic bookmarks are planned but not yet implemented

4. **Persistence Optional**
   - History persistence is planned but optional
   - No automatic save/restore yet

5. **v1 Features Not Ported**
   - Coupling analysis not yet ported
   - Session management not yet ported
   - Relations panel approach not used in v2

### Platform Constraints

- **Neovim 0.8+** required
- **Lua 5.4** required
- **LSP server** required for full functionality
- **mini.pick** optional (for picker features)

### Known Issues

- None documented yet (plugin in early development)

## Architecture Decisions

### Why v2?

**v1 Approach:**
- Relations panel with split window UI
- Custom UI components
- Coupling analysis with visual indicators
- Session management

**v2 Approach:**
- Breadcrumb-based navigation
- Extends built-in Neovim functionality
- Minimal UI footprint
- Project-aware history

**Rationale:**
- Less intrusive (hotkey-triggered vs persistent panel)
- Better integration with Neovim (extends jumplist/LSP)
- More efficient (lazy loading, intelligent pruning)
- Project-aware (separate histories per project)

### Design Principles

1. **Extend, Don't Replace**
   - Enhance built-in Neovim functionality
   - Don't conflict with existing workflows
   - Maintain compatibility

2. **Graceful Degradation**
   - Work without LSP
   - Work without mini.pick
   - Never break user workflow

3. **Performance First**
   - Fast operations (< 50ms)
   - Low memory footprint
   - Efficient data structures

4. **Minimal UI**
   - Hotkey-triggered (not persistent)
   - Collapsible interfaces
   - Subtle visual styling

5. **Project Awareness**
   - Separate histories per project
   - Auto-detect project boundaries
   - Clear project context

### Integration Strategy

**LSP Integration:**
- Hook into LSP events
- Extend built-in commands
- Don't replace existing functionality
- Graceful fallback when unavailable

**Jumplist Integration:**
- Enhance Ctrl-O/Ctrl-I
- Integrate with built-in jumplist
- Maintain compatibility
- Add value without conflicts

**Picker Integration:**
- Use mini.pick if available
- Graceful fallback if not
- Dual-mode (bookmark/navigation)
- Extensible for other pickers

### Testing Strategy

**Framework**: mini.test with child Neovim processes

**Focus**: High-signal integration tests (not exhaustive unit tests)

**Categories**:
- Core functionality tests
- Integration tests
- UI tests
- Bookmark tests
- Performance tests

**Performance Benchmarks**:
- Navigation operations: < 50ms
- Memory usage: < 10MB for 1000 entries
- File loading: < 5ms additional delay
- History pruning: < 100ms

## Configuration Schema

```lua
Config = {
  -- Display options
  display = {
    enabled = boolean,      -- Default: true
    max_items = number,     -- Default: 10
    hotkey_only = boolean,  -- Default: true (show only on hotkey press)
    collapse_unfocused = boolean, -- Default: true (mini.files-like behavior)
  },
  
  -- History management
  history = {
    max_entries = number,   -- Default: 1000
    max_age_minutes = number, -- Default: 30
    pruning_debounce_minutes = number, -- Default: 2
    save_on_exit = boolean, -- Default: false (optional persistence)
    exploration_timeout_minutes = number, -- Default: 5 (for statusline state)
  },
  
  -- Integration settings
  integration = {
    jumplist = boolean,     -- Default: true (extend built-in jumplist)
    lsp = boolean,          -- Default: true (extend built-in LSP)
    mini_pick = boolean,    -- Default: true if mini.pick available
    statusline = boolean,   -- Default: true (show branch info in statusline)
  },
  
  -- Visual settings
  visual = {
    use_unicode_tree = boolean, -- Default: true (unicode box-drawing chars)
    color_scheme = string,  -- Default: "subtle" (for tree readability)
    floating_window_width = number, -- Default: 80
    floating_window_height = number, -- Default: 20
  },
  
  -- Bookmark settings
  bookmarks = {
    frequent_threshold = number, -- Default: 3 (visits to mark as frequent)
    auto_bookmark_frequent = boolean, -- Default: true
  },
  
  -- Debug settings
  debug = {
    enabled = boolean,      -- Default: false
    log_level = string,     -- Default: "info" ("debug", "info", "warn", "error")
  }
}
```

## Content Sources

This specification was compiled from:
- `.kiro/specs/spaghetti-comb-v2.nvim/design.md` - Design decisions and architecture
- `.kiro/specs/spaghetti-comb-v2.nvim/requirements.md` - User stories and requirements
- `IMPLEMENTATION_PLAN.md` - Implementation details and phases
- Code analysis of current implementation

