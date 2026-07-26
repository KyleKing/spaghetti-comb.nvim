-- Run all demo scenarios
local ui = require("demos.util")

local M = {}

local DEMOS = {
    { key = "basic", title = "Basic Usage", module = "demos.basic_usage", blurb = "Basic navigation features" },
    { key = "lsp", title = "LSP Integration", module = "demos.lsp_integration", blurb = "LSP integration" },
    {
        key = "advanced",
        title = "Advanced Features",
        module = "demos.advanced_features",
        blurb = "Intelligent pruning and multi-project support",
    },
}

local function find(key)
    for _, entry in ipairs(DEMOS) do
        if entry.key == key then return entry end
    end
end

local function run(entry) require(entry.module).run_all() end

local function pause_for_input()
    ui.rule()
    print("Press Enter to continue...")
    io.read("l")
end

local function clear_screen() print("\027[2J\027[H") end

local FOOTER = [[
You've seen all the major features of Spaghetti Comb:

✓ Navigation History Tracking
✓ Branching Navigation Paths
✓ Smart Bookmark Management
✓ LSP Integration
✓ Intelligent Jump Pruning
✓ Multi-Project Support
✓ Location Recovery
✓ Persistence System

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
       history = { max_entries = 1000, save_on_exit = true },
       integration = { lsp = true, jumplist = true },
   })

═══════════════════════════════════════════════════

LEARN MORE:

• README.md - Installation and usage
• SPEC.md - Detailed specifications
• DEVELOPER.md - Development guide

Report issues: https://github.com/KyleKing/spaghetti-comb.nvim
]]

-- Run every demo, pausing between sections. Needs a real terminal for io.read.
function M.execute_interactive()
    clear_screen()
    ui.banner("🍝 Spaghetti Comb Demo Suite 🧐")
    print("This walks through each demo. Press Enter to advance.\n")
    pause_for_input()

    for i, entry in ipairs(DEMOS) do
        ui.banner(string.format("Demo %d: %s", i, entry.title))
        run(entry)
        pause_for_input()
    end

    clear_screen()
    ui.banner("Demo complete")
    print(FOOTER)
end

-- Run every demo straight through (used by `mise run demo`)
function M.execute()
    ui.banner("🍝 Spaghetti Comb Demo Suite 🧐")

    for i, entry in ipairs(DEMOS) do
        ui.banner(string.format("Demo %d: %s", i, entry.title))
        run(entry)
    end

    ui.banner("All demos complete")
end

function M.run_demo(key)
    local entry = find(key)
    if not entry then
        print("Unknown demo: " .. tostring(key))
        print("Available demos: " .. table.concat(vim.tbl_map(function(d) return d.key end, DEMOS), ", "))
        return
    end
    run(entry)
end

function M.list()
    print("Available Demos:\n")
    for i, entry in ipairs(DEMOS) do
        print(string.format("%d. %-10s - %s", i, entry.key, entry.blurb))
    end
    print([[

Run a specific demo:
  :lua require('demos.run_all').run_demo('basic')

Run all demos:
  :lua require('demos.run_all').execute()

Interactive mode (with pauses):
  :lua require('demos.run_all').execute_interactive()
]])
end

return M
