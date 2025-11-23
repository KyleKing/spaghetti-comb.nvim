-- Run all demo scenarios
local M = {}

-- Helper function to create visual separators
local function section_separator(title)
    local width = 50
    local padding = math.floor((width - #title - 2) / 2)
    local line = string.rep("═", width)

    print("\n" .. line)
    print(string.rep(" ", padding) .. "  " .. title:upper() .. "  ")
    print(line .. "\n")
end

local function pause_for_input()
    print("\n" .. string.rep("-", 50))
    print("Press Enter to continue...")
    io.read()
end

local function clear_screen()
    -- ANSI escape code to clear screen (works in most terminals)
    print("\027[2J\027[H")
end

-- Run all demos with pauses
function M.execute_interactive()
    clear_screen()

    print([[
╔══════════════════════════════════════════════════╗
║                                                  ║
║        🍝 SPAGHETTI COMB DEMO SUITE 🧐          ║
║                                                  ║
║     Comprehensive Feature Demonstrations        ║
║                                                  ║
╚══════════════════════════════════════════════════╝

This interactive demo will walk you through all
features of Spaghetti Comb. Press Enter to continue
through each section.

Estimated time: 5-10 minutes
]])

    pause_for_input()

    -- Demo 1: Basic Usage
    section_separator("Demo 1: Basic Usage")
    print("Demonstrating core navigation features...\n")
    local basic_demo = require("demos.basic_usage")
    basic_demo.run_all()
    pause_for_input()

    -- Demo 2: LSP Integration
    section_separator("Demo 2: LSP Integration")
    print("Showing how Spaghetti Comb enhances LSP navigation...\n")
    local lsp_demo = require("demos.lsp_integration")
    lsp_demo.run_all()
    pause_for_input()

    -- Demo 3: Advanced Features
    section_separator("Demo 3: Advanced Features")
    print("Exploring intelligent pruning and multi-project support...\n")
    local advanced_demo = require("demos.advanced_features")
    advanced_demo.run_all()
    pause_for_input()

    -- Final summary
    clear_screen()
    print([[
╔══════════════════════════════════════════════════╗
║                                                  ║
║              ✨ DEMO COMPLETE! ✨               ║
║                                                  ║
╚══════════════════════════════════════════════════╝

You've seen all the major features of Spaghetti Comb:

✓ Navigation History Tracking
✓ Branching Navigation Paths
✓ Smart Bookmark Management
✓ LSP Integration
✓ Intelligent Jump Pruning
✓ Multi-Project Support
✓ Location Recovery
✓ Persistence System
✓ Performance Optimizations

═══════════════════════════════════════════════════

NEXT STEPS:

1. Try the UI commands in Neovim:
   :SpaghettiCombBreadcrumbs
   :SpaghettiCombTree
   :SpaghettiCombBookmarks
   :SpaghettiCombHistory

2. Navigate your own codebase:
   - Use normal LSP commands (gd, gr)
   - Navigation is tracked automatically
   - Use Ctrl-O/Ctrl-I to navigate history

3. Customize your configuration:
   require('spaghetti-comb').setup({
       history = {
           max_entries = 1000,
           save_on_exit = true,
       },
       integration = {
           lsp = true,
           jumplist = true,
       },
   })

4. Set up keybindings (optional):
   vim.keymap.set("n", "<leader>sb", "<cmd>SpaghettiCombBreadcrumbs<cr>")
   vim.keymap.set("n", "<leader>st", "<cmd>SpaghettiCombTree<cr>")
   vim.keymap.set("n", "<leader>sm", "<cmd>SpaghettiCombBookmarks<cr>")

═══════════════════════════════════════════════════

LEARN MORE:

• README.md - Installation and usage
• SPEC.md - Detailed specifications
• DEVELOPER.md - Development guide
• tests/ - Test suite examples

═══════════════════════════════════════════════════

Thank you for trying Spaghetti Comb! 🍝

Report issues: https://github.com/KyleKing/spaghetti-comb.nvim
]])
end

-- Run all demos without pauses (for CI/testing)
function M.execute()
    print([[
╔══════════════════════════════════════════════════╗
║        🍝 SPAGHETTI COMB DEMO SUITE 🧐          ║
╚══════════════════════════════════════════════════╝
]])

    -- Demo 1
    print("\n" .. string.rep("=", 50))
    print("DEMO 1: BASIC USAGE")
    print(string.rep("=", 50))
    require("demos.basic_usage").run_all()

    -- Demo 2
    print("\n\n" .. string.rep("=", 50))
    print("DEMO 2: LSP INTEGRATION")
    print(string.rep("=", 50))
    require("demos.lsp_integration").run_all()

    -- Demo 3
    print("\n\n" .. string.rep("=", 50))
    print("DEMO 3: ADVANCED FEATURES")
    print(string.rep("=", 50))
    require("demos.advanced_features").run_all()

    print([[

╔══════════════════════════════════════════════════╗
║              ✨ ALL DEMOS COMPLETE! ✨          ║
╚══════════════════════════════════════════════════╝
]])
end

-- Run a specific demo by name
function M.run_demo(demo_name)
    local demos = {
        basic = "demos.basic_usage",
        lsp = "demos.lsp_integration",
        advanced = "demos.advanced_features",
    }

    local module_name = demos[demo_name]
    if not module_name then
        print("Unknown demo: " .. demo_name)
        print("Available demos: basic, lsp, advanced")
        return
    end

    local demo = require(module_name)
    demo.run_all()
end

-- List available demos
function M.list()
    print([[
Available Demos:

1. basic       - Basic navigation features
2. lsp         - LSP integration
3. advanced    - Advanced features

Run a specific demo:
  :lua require('demos.run_all').run_demo('basic')

Run all demos:
  :lua require('demos.run_all').execute()

Interactive mode (with pauses):
  :lua require('demos.run_all').execute_interactive()
]])
end

return M
