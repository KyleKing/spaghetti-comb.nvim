# spaghetti-comb.nvim

A Neovim plugin that extends built-in navigation with project-aware history, bookmarks, and visual exploration tools. The name is a playful reference to "spaghetti code": this plugin is a comb for untangling unfamiliar codebases.

## Why

When exploring a large or generated codebase, it is easy to lose track of how you arrived somewhere. This plugin records your navigation jumps (LSP definitions, references, jumplist movement) into a per-project trail with branching, then gives you lightweight UIs to review and jump around that trail.

## Features

- Navigation history recorded per project, with branching when you jump from mid-trail
- Intelligent pruning: drops inconsequential jumps, recovers positions after line shifts, debounced cleanup
- Manual bookmarks plus automatic detection of frequently visited locations
- Hotkey-triggered breadcrumb bar showing your trail (`file1.lua:10 › file2.lua:25`)
- Floating tree view of the trail with a live code preview pane
- Dual-mode picker (bookmarks and history) using mini.pick when available, with a built-in fallback
- Statusline component showing exploration state and branch depth
- Optional JSON persistence of history and bookmarks under `stdpath('data')/spaghetti-comb/`

## Requirements

- Neovim 0.10+
- An LSP server for your language (optional; jumplist tracking works without one)
- [mini.pick](https://github.com/echasnovski/mini.nvim) (optional, for the picker UI)

## Installation

With mini.deps:

```lua
local add, later = MiniDeps.add, MiniDeps.later

later(function()
    add({ source = "KyleKing/spaghetti-comb.nvim" })
    require("spaghetti-comb").setup()
end)
```

Or from a local checkout:

```lua
vim.opt.runtimepath:append("/path/to/spaghetti-comb.nvim")
require("spaghetti-comb").setup()
```

## Usage

Navigate as you normally would (LSP go-to-definition, `<C-o>`/`<C-i>`, file switching). The plugin records jumps automatically. Then:

- `<leader>sb` toggles the breadcrumb trail view
- `<leader>st` toggles the floating tree with preview
- `<leader>sh` opens the history picker
- `<leader>sm` opens the bookmark picker
- `<leader>sB` toggles a bookmark at the cursor
- `<leader>ss` shows the current navigation status

### Commands

| Command | Description |
| --- | --- |
| `:SpaghettiCombBreadcrumbs` | Toggle breadcrumb trail view |
| `:SpaghettiCombTree` | Toggle navigation tree with preview |
| `:SpaghettiCombHistory` | Navigation history picker |
| `:SpaghettiCombBookmarks` | Bookmark picker |
| `:SpaghettiCombBookmarkToggle` | Toggle bookmark at cursor |
| `:SpaghettiCombBookmarkClear [global]` | Clear bookmarks |
| `:SpaghettiCombBack` / `:SpaghettiCombForward` | Move through the trail |
| `:SpaghettiCombJumpTo {index}` | Jump to a trail entry |
| `:SpaghettiCombHistoryClear [all]` | Clear navigation history |
| `:SpaghettiCombStatus` | Show navigation status |
| `:SpaghettiCombSaveHistory` / `:SpaghettiCombLoadHistory` | Persist or restore history for the current project |
| `:SpaghettiCombSaveBookmarks` / `:SpaghettiCombLoadBookmarks` | Persist or restore bookmarks |
| `:SpaghettiCombStorageStats` | Persistence storage statistics |
| `:SpaghettiCombCleanupPersistence [days]` | Delete old persistence files |
| `:SpaghettiCombListProjects` | List projects with saved data |
| `:SpaghettiCombDebug` / `:SpaghettiCombLogLevel {level}` | Debug helpers |

## Configuration

Defaults shown; pass overrides to `setup()`:

```lua
require("spaghetti-comb").setup({
    display = {
        enabled = true,
        max_items = 10,          -- Breadcrumb entries shown
        hotkey_only = true,      -- Show breadcrumbs only on demand
        collapse_unfocused = true,
    },
    history = {
        max_entries = 1000,
        max_age_minutes = 30,
        pruning_debounce_minutes = 2,
        save_on_exit = false,    -- Enable persistence on VimLeavePre
        exploration_timeout_minutes = 5,
    },
    integration = {
        jumplist = true,
        lsp = true,
        mini_pick = true,
        statusline = true,
    },
    visual = {
        use_unicode_tree = true,
        color_scheme = "subtle",
        floating_window_width = 80,
        floating_window_height = 20,
    },
    bookmarks = {
        frequent_threshold = 3,  -- Visits before auto-bookmarking
        auto_bookmark_frequent = true,
    },
    debug = {
        enabled = false,
        log_level = "info",
    },
})
```

For the statusline component, call `require("spaghetti-comb.ui.statusline").get_status()` from your statusline config.

## Project Structure

```
lua/spaghetti-comb/
├── init.lua              -- Setup and component wiring
├── config.lua            -- Config schema and validation
├── types.lua             -- NavigationEntry / NavigationTrail / BookmarkEntry
├── history/              -- Trail recording, pruning, bookmarks, persistence
├── navigation/           -- Commands, LSP hooks, jumplist integration, events
├── ui/                   -- Breadcrumbs, floating tree, preview, picker, statusline
├── utils/                -- Project detection, debug logging
└── tests/                -- mini.test specs
```

## Development

See [DEVELOPER.md](DEVELOPER.md) for setup and [ROADMAP.md](ROADMAP.md) for planned work. Quick commands:

```bash
mise run test       # Run the test suite (headless nvim + mini.test)
mise run lint       # stylua check
mise run format     # stylua fix
mise run typecheck  # selene
```

Feature specification lives in [SPEC.md](SPEC.md).
