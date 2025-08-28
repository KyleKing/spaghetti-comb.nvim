# Spaghetti Comb

A Neovim plugin for code exploration designed to help developers untangle complex codebases by visualizing code relationships and dependencies.

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
            width = 50,
            height = 20,
            position = "right",
            auto_preview = true,
            show_coupling = true,
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

After installation, the plugin provides various commands and keymaps for code exploration:

- `<leader>sr` - Show Relations panel for symbol under cursor
- `<leader>sf` - Find references to current symbol
- `<leader>sd` - Go to definition of current symbol
- `<leader>sn` - Navigate forward in exploration stack
- `<leader>sp` - Navigate backward in exploration stack
- `<leader>ss` - Save current exploration session
- `<leader>sl` - Load saved exploration session

See `:help spaghetti-comb` for complete documentation.

## Requirements

- Neovim 0.8+
- LSP server configured for your language
- mini.deps (for installation method shown above)

