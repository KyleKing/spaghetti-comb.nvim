-- Demo Scenario 2: LSP Integration
-- This demo showcases how Spaghetti Comb integrates with LSP navigation

local demo = {}

function demo.setup()
    require("spaghetti-comb").setup({
        integration = {
            lsp = true,
            jumplist = true,
        },
        history = {
            max_entries = 500,
        },
    })
end

-- Demo: LSP definition tracking
function demo.lsp_definition_tracking()
    print("\nLSP Definition Tracking Demo")
    print("============================\n")

    local history_manager = require("spaghetti-comb.history.manager")
    history_manager.set_current_project(vim.fn.getcwd())

    print("Simulating LSP definition jumps...")
    print("(In actual usage, these would be triggered by LSP)")

    -- Simulate LSP definition jumps
    local lsp_jumps = {
        {
            from = { file = "src/main.lua", line = 10, symbol = "setup" },
            to = { file = "src/init.lua", line = 17, definition = "function setup()" },
        },
        {
            from = { file = "src/init.lua", line = 25, symbol = "history_manager" },
            to = { file = "src/history/manager.lua", line = 18, definition = "local M = {}" },
        },
        {
            from = { file = "src/history/manager.lua", line = 60, symbol = "record_jump" },
            to = { file = "src/history/manager.lua", line = 60, definition = "function M.record_jump()" },
        },
    }

    for i, jump in ipairs(lsp_jumps) do
        print(string.format("\n%d. Jump to definition:", i))
        print(string.format("   From: %s:%d (%s)", jump.from.file, jump.from.line, jump.from.symbol))
        print(string.format("   To:   %s:%d (%s)", jump.to.file, jump.to.line, jump.to.definition))

        local from_location = {
            file_path = vim.fn.getcwd() .. "/" .. jump.from.file,
            position = { line = jump.from.line, column = 1 },
            context = { symbol = jump.from.symbol },
        }

        local to_location = {
            file_path = vim.fn.getcwd() .. "/" .. jump.to.file,
            position = { line = jump.to.line, column = 1 },
            context = {
                function_name = jump.to.definition,
                symbol_type = "function",
            },
        }

        local success = history_manager.record_jump(from_location, to_location, "lsp_definition")
        print(string.format("   Status: %s", success and "✓ Tracked" or "✗ Failed"))
    end

    -- Show jump type statistics
    print("\n\nJump Type Distribution:")
    local trail = history_manager.get_current_trail()
    if trail then
        local jump_types = {}
        for _, entry in ipairs(trail.entries) do
            jump_types[entry.jump_type] = (jump_types[entry.jump_type] or 0) + 1
        end

        for jump_type, count in pairs(jump_types) do
            print(string.format("  %s: %d", jump_type, count))
        end
    end
end

-- Demo: LSP reference tracking
function demo.lsp_reference_tracking()
    print("\n\nLSP Reference Tracking Demo")
    print("===========================\n")

    local history_manager = require("spaghetti-comb.history.manager")

    print("Finding all references to a symbol...")

    local reference_locations = {
        { file = "src/init.lua", line = 43, context = "setup()" },
        { file = "src/main.lua", line = 5, context = "require('init').setup()" },
        { file = "tests/init_spec.lua", line = 12, context = "setup(config)" },
        { file = "plugin/plugin.lua", line = 8, context = "spaghetti_comb.setup()" },
    }

    print("References found:")
    for i, ref in ipairs(reference_locations) do
        print(string.format("  %d. %s:%d - %s", i, ref.file, ref.line, ref.context))

        -- Record reference jump
        local current_location = {
            file_path = vim.fn.getcwd() .. "/src/init.lua",
            position = { line = 17, column = 1 },
        }

        local ref_location = {
            file_path = vim.fn.getcwd() .. "/" .. ref.file,
            position = { line = ref.line, column = 1 },
            context = { reference_context = ref.context },
        }

        history_manager.record_jump(current_location, ref_location, "lsp_reference")
    end

    print("\n✓ All references tracked in navigation history")
end

-- Demo: Call hierarchy navigation
function demo.call_hierarchy()
    print("\n\nCall Hierarchy Navigation Demo")
    print("==============================\n")

    local history_manager = require("spaghetti-comb.history.manager")

    print("Navigating call hierarchy...")
    print("\nCall chain:")
    print("  main() → init() → setup() → configure() → validate()")

    local call_chain = {
        { func = "main", file = "src/main.lua", line = 5 },
        { func = "init", file = "src/init.lua", line = 10 },
        { func = "setup", file = "src/init.lua", line = 17 },
        { func = "configure", file = "src/config.lua", line = 53 },
        { func = "validate", file = "src/config.lua", line = 98 },
    }

    for i = 1, #call_chain - 1 do
        local from = call_chain[i]
        local to = call_chain[i + 1]

        print(string.format("\n%d. %s() → %s()", i, from.func, to.func))
        print(string.format("   %s:%d → %s:%d", from.file, from.line, to.file, to.line))

        local from_location = {
            file_path = vim.fn.getcwd() .. "/" .. from.file,
            position = { line = from.line, column = 1 },
            context = { function_name = from.func },
        }

        local to_location = {
            file_path = vim.fn.getcwd() .. "/" .. to.file,
            position = { line = to.line, column = 1 },
            context = { function_name = to.func },
        }

        history_manager.record_jump(from_location, to_location, "lsp_call_hierarchy")
    end

    print("\n✓ Call hierarchy tracked")
    print("\nTip: Use Ctrl-O to navigate back through the call chain!")
end

-- Demo: Symbol search
function demo.workspace_symbol_search()
    print("\n\nWorkspace Symbol Search Demo")
    print("============================\n")

    local history_manager = require("spaghetti-comb.history.manager")

    print("Searching for symbols matching 'manager'...")

    local symbols = {
        { name = "history_manager", file = "src/history/manager.lua", line = 5, kind = "module" },
        { name = "M.setup", file = "src/history/manager.lua", line = 18, kind = "function" },
        { name = "bookmark_manager", file = "src/history/bookmarks.lua", line = 3, kind = "module" },
    }

    print("\nSymbols found:")
    for i, symbol in ipairs(symbols) do
        print(string.format("  %d. [%s] %s - %s:%d", i, symbol.kind, symbol.name, symbol.file, symbol.line))
    end

    -- Jump to first result
    print("\nJumping to first result...")
    local from_location = {
        file_path = vim.fn.getcwd() .. "/src/main.lua",
        position = { line = 1, column = 1 },
    }

    local to_location = {
        file_path = vim.fn.getcwd() .. "/" .. symbols[1].file,
        position = { line = symbols[1].line, column = 1 },
        context = {
            symbol_name = symbols[1].name,
            symbol_kind = symbols[1].kind,
        },
    }

    local success = history_manager.record_jump(from_location, to_location, "lsp_workspace_symbol")
    print(string.format("  %s Jumped to %s", success and "✓" or "✗", symbols[1].name))
end

-- Demo: Showing how exploration state changes
function demo.exploration_state()
    print("\n\nExploration State Demo")
    print("======================\n")

    local history_manager = require("spaghetti-comb.history.manager")

    print("The plugin tracks your exploration state:")
    print("  - idle: No recent navigation")
    print("  - exploring: Active code exploration")

    print("\nCurrent state: " .. history_manager.determine_exploration_state())

    print("\nAfter navigating...")
    local from_loc = { file_path = "/test/file1.lua", position = { line = 1, column = 1 } }
    local to_loc = { file_path = "/test/file2.lua", position = { line = 2, column = 2 } }
    history_manager.record_jump(from_loc, to_loc, "lsp_definition")

    print("Current state: " .. history_manager.determine_exploration_state())
    print("\nThe statusline will show 🔎 when actively exploring")
end

-- Run all LSP demos
function demo.run_all()
    print("\n╔════════════════════════════════════════╗")
    print("║   LSP Integration Demo                ║")
    print("╚════════════════════════════════════════╝")

    demo.setup()

    demo.lsp_definition_tracking()
    demo.lsp_reference_tracking()
    demo.call_hierarchy()
    demo.workspace_symbol_search()
    demo.exploration_state()

    print("\n╔════════════════════════════════════════╗")
    print("║   LSP Demo Complete!                  ║")
    print("╚════════════════════════════════════════╝\n")
end

return demo
