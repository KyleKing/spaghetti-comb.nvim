# Spaghetti Comb

A Neovim plugin for code exploration designed to help developers untangle complex codebases by visualizing code relationships and dependencies.

## Features

- **Split Window Relations Panel** - Opens at bottom of screen like vim's `:help` command
- **Focus Mode** - Press `<Tab>` to expand relations window and show side-by-side code preview
- **Vim Motion Navigation** - Use `j/k`, arrow keys, and other vim motions to navigate relations
- **LSP Integration** - Works with any LSP server for references, definitions, and call hierarchy
- **Navigation Stack** - Bidirectional exploration history with bookmark support
- **Coupling Analysis** - Visual indicators showing code relationship strength
- **Session Persistence** - Save and restore exploration sessions

## Installation (Local Download)

If you've downloaded this plugin locally instead of cloning from git, you can install it using mini.deps:

### Using mini.deps

Add the following to your Neovim configuration:

```lua
local add, _now, later = MiniDeps.add, MiniDeps.now, MiniDeps.later

-- Setup the plugin
later(function()
    add({
        -- Install from local directory replacing with the actual path
        source = "file:///Users/kyleking/Developer/local-code/spaghetti-comb.nvim",
        depends = {},
    })

    require("spaghetti-comb").setup({
        -- Configuration options (optional)
        relations = {
            height = 15,              -- Normal split height
            focus_height = 30,        -- Expanded height in focus mode
            position = "bottom",      -- Split position
            auto_preview = true,      -- Auto-update preview in focus mode
            show_coupling = true,     -- Show coupling metrics
        },
        keymaps = {
            show_relations = "<leader>sr",
            find_references = "<leader>sf",
            go_definition = "<leader>sd",
            navigate_next = "<leader>sn",
            navigate_prev = "<leader>sp",
            save_session = "<leader>ss",
            load_session = "<leader>sl",
        },
    })
end)
```

### Alternative: Manual Plugin Path

You can also add the plugin directory directly to Neovim's runtime path:

```lua
-- Add to your init.lua
vim.opt.runtimepath:append("/path/to/your/local/spaghetti-comb.nvim")

-- Then setup normally
require("spaghetti-comb").setup()
```

## Usage

### Quick Start

1. Position your cursor on any function, variable, or symbol
1. Press `<leader>sr` to open the Relations panel
1. Use `j/k` or arrow keys to navigate the results
1. Press `<Tab>` to enter **Focus Mode** for expanded view with preview
1. Press `<Enter>` to jump to a location, or `<C-]>` to explore it further

### Default Keymaps

**Global keymaps:**

- `<leader>sr` - Show Relations panel for symbol under cursor
- `<leader>sf` - Find references to current symbol
- `<leader>sd` - Go to definition of current symbol
- `<leader>sn` - Navigate forward in exploration stack
- `<leader>sp` - Navigate backward in exploration stack
- `<leader>ss` - Save current exploration session
- `<leader>sl` - Load saved exploration session

**Within Relations panel:**

- `<Enter>` - Navigate to selected location
- `<C-]>` - Explore symbol at selected location (go deeper)
- `<C-o>` - Navigate backward in exploration stack
- `<Tab>` - Toggle focus mode (expand window + show preview)
- `m` - Toggle bookmark for selected item
- `c` - Show coupling metrics for selected item
- `/` - Search relations
- `f` - Cycle coupling filter (all/high/medium/low)
- `s` - Cycle sort mode (default/coupling/file/line)
- `b` - Toggle bookmarked items only
- `r` - Reset all filters
- `q` or `<Esc>` - Close Relations panel

### Focus Mode

Press `<Tab>` in the Relations panel to enter **Focus Mode**:

- Relations window expands to double height
- Preview window opens on the right showing code context
- Preview automatically updates as you navigate with `j/k`
- Press `<Tab>` again to return to normal mode

### UI Layout

**Normal Mode:**

```
┌─ Your Code Buffer ──────────────────────────────────┐
│ function calculateTotal() {                         │
│   const tax = getTax();     ← cursor here           │
│   return base + tax - discount;                     │
│ }                                                   │
├─ Relations Panel ───────────────────────────────────┤
│ Relations for 'getTax':                             │
│ References (3):                                     │
│ ├─ 📄 checkout.ts:42 [C:0.7]                      │
│ ├─ 📄 invoice.ts:18 [C:0.4]                       │
│ └─ 📄 report.ts:95 [C:0.2]                        │
│                                                     │
│ Press <Tab> for Focus Mode                          │
└─────────────────────────────────────────────────────┘
```

**Focus Mode:**

```
┌─ Your Code Buffer ──────────────────────────────────┐
│ function calculateTotal() {                         │
│   const tax = getTax();     ← cursor here           │
├─ Relations Panel ───────────┬─ Preview ─────────────┤
│ Relations for 'getTax':     │ [Preview: checkout.ts]│
│ References (3):             │  41 │ const total =   │
│ ├─ 📄 checkout.ts:42 [C:0.7]│▶42 │   calculateTotal│
│ ├─ 📄 invoice.ts:18 [C:0.4] │  43 │ return total;   │
│ └─ 📄 report.ts:95 [C:0.2]  │                       │
│                             │ Navigate with j/k     │
│ Use j/k to navigate         │ to update preview     │
│ Press <Tab> to exit         │                       │
└─────────────────────────────┴───────────────────────┘
```

See `:help spaghetti-comb` for complete documentation.

## Requirements

- Neovim 0.8+
- LSP server configured for your language
- mini.deps (for installation method shown above)
