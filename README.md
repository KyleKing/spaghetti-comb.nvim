# Spaghetti Comb

A Neovim plugin for code exploration designed to help developers untangle complex codebases by visualizing code relationships and dependencies. The name is a playful reference to "spaghetti code" - this plugin serves as a "comb" to help untangle and understand intricate code relationships.

## Why Spaghetti Comb?

When exploring an unfamiliar codebase, you need contextual information on demand:
- Where and how is the current function used?
- Where and how is the code under the cursor defined?
- How can I navigate through the exploration stack without losing context?

Spaghetti Comb provides these capabilities through intelligent navigation history tracking and code relationship visualization.

## Current Status: v2 in Development

**Spaghetti Comb v2** is currently in active development. This version takes a different approach than v1:

- **v1** (fully implemented): Relations panel approach with split window UI, coupling analysis, and session management
- **v2** (in development): Breadcrumb-based navigation that extends Neovim's built-in functionality (jumplist, LSP) with minimal UI intrusion

### Why v2?

v2 was created to provide a more integrated, less intrusive code exploration experience:
- **Extends rather than replaces** Neovim's built-in navigation (jumplist, LSP)
- **Minimal UI footprint** with hotkey-triggered breadcrumbs instead of persistent panels
- **Project-aware history** with intelligent pruning and location recovery
- **Better performance** through efficient data structures and lazy loading

### Migration from v1

If you're using v1, note that v2 is a clean break - no backward compatibility is maintained. However, many v1 features are being ported to v2:

**Reusable from v1:**
- LSP integration patterns (`analyzer.lua`)
- Coupling analysis algorithms (`coupling/metrics.lua`, `coupling/graph.lua`)
- Navigation stack concepts (`navigation.lua`)
- Storage patterns (`persistence/storage.lua`)
- Bookmark management (`persistence/bookmarks.lua`)
- Code preview functionality (`ui/preview.lua`)

**v2 New Features:**
- Project-aware history separation
- Intelligent pruning with location recovery
- Breadcrumb-based navigation (when implemented)
- Statusline integration (when implemented)
- Floating tree visualization (when implemented)

See [DEVELOPER.md](DEVELOPER.md) for migration details and [SPEC.md](SPEC.md) for complete feature specifications.

## Installation

### Using a Package Manager

```lua
-- Using lazy.nvim
{
  'your-username/spaghetti-comb.nvim',
  config = function()
    require('spaghetti-comb-v2').setup()
  end
}

-- Using packer.nvim
use {
  'your-username/spaghetti-comb.nvim',
  config = function()
    require('spaghetti-comb-v2').setup()
  end
}
```

### Manual Installation

1. Clone the repository to your Neovim configuration directory
2. Add to your `init.lua`:

```lua
require('spaghetti-comb-v2').setup()
```

## Requirements

- Neovim 0.8+
- LSP server configured for your language (for full functionality)
- (Optional) mini.pick for picker functionality

## Quick Start

1. Position your cursor on any function, variable, or symbol
2. Use LSP commands (go to definition, find references) - navigation is automatically tracked
3. Navigate through your exploration history using enhanced navigation commands
4. View breadcrumb trail (when implemented) to see your exploration path

## Features

### Core Features (v2 - In Development)

- **Navigation History Tracking** - Automatically tracks navigation jumps with intelligent pruning
- **Project-Aware History** - Separate history trails per project
- **Location Recovery** - Handles file changes and line shifts gracefully
- **Breadcrumb Navigation** - Visual trail of exploration path (when implemented)
- **Enhanced Jumplist** - Extends Neovim's built-in jumplist functionality
- **LSP Integration** - Extends built-in LSP commands with history tracking

### Planned Features

- **Floating Tree Visualization** - Unicode tree showing branch history
- **Code Previews** - Context-aware code previews in picker and tree views
- **Bookmark System** - Manual and automatic frequent location detection
- **Statusline Integration** - Minimal branch status display
- **Dual-Mode Picker** - Bookmark and navigation modes with mini.pick integration

## Documentation

- **[README.md](README.md)** (this file) - Project overview and quick start
- **[AGENTS.md](AGENTS.md)** - Concise AI-specific development guidance
- **[DEVELOPER.md](DEVELOPER.md)** - Comprehensive developer documentation
- **[SPEC.md](SPEC.md)** - Feature specifications and architecture decisions

For detailed usage instructions, see `:help spaghetti-comb-v2` (when documentation is generated).

## License

MIT License - see [LICENSE](LICENSE) file for details.
