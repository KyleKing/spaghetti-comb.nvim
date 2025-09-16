--- *spaghetti-comb-v1.nvim* Code exploration and relationship visualization
---
--- MIT License Copyright (c) 2024 Kyle King
---
--- ==============================================================================
---
--- Spaghetti Comb v2 is a Neovim plugin designed to help developers untangle
--- complex codebases by visualizing code relationships and dependencies. The name
--- is a playful reference to "spaghetti code" - this plugin serves as a "comb"
--- to help untangle and understand intricate code relationships.
---
--- Key Features:
--- - LSP-powered symbol analysis with references, definitions, and call hierarchy
--- - Split window Relations panel with vim motion navigation
--- - Navigation stack with bidirectional history
--- - Focus mode with side-by-side code previews
--- - Coupling analysis with numerical indicators
--- - Bookmark system with collections and persistence
--- - Session management for exploration state
--- - Multi-language support (TypeScript, JavaScript, Python, Rust, Go, Lua)
---
--- # Setup ~
---
--- This module needs to be set up with `require('spaghetti-comb-v1').setup({})`.
--- See |SpaghettiCombv2.setup()| for configuration options.
---
--- >lua
---   require('spaghetti-comb-v1').setup({
---     relations = {
---       height = 15,        -- Relations panel height
---       focus_height = 30,  -- Height in focus mode
---       position = 'bottom' -- Panel position
---     }
---   })
--- <
---
--- # Commands ~
---
--- The plugin provides these user commands:
--- - |:SpaghettiCombv2Show| - Show Relations panel for symbol under cursor
--- - |:SpaghettiCombv2References| - Find all references to current symbol
--- - |:SpaghettiCombv2Definition| - Jump to symbol definition
--- - |:SpaghettiCombv2Toggle| - Toggle Relations panel visibility
--- - |:SpaghettiCombv2Next| - Navigate forward in exploration stack
--- - |:SpaghettiCombv2Prev| - Navigate backward in exploration stack
--- - |:SpaghettiCombv2SaveSession| - Save current exploration session
--- - |:SpaghettiCombv2LoadSession| - Load exploration session
--- - |:SpaghettiCombv2BookmarkCurrent| - Bookmark current symbol
---
--- # Key Mappings ~
---
--- Default key mappings (can be customized in setup):
--- - `<leader>sr` - Show Relations panel
--- - `<leader>sf` - Find references
--- - `<leader>sd` - Go to definition
--- - `<leader>sn` - Navigate forward
--- - `<leader>sp` - Navigate backward
--- - `<leader>ss` - Save session
--- - `<leader>sl` - Load session
--- - `<leader>sb` - Bookmark current symbol
---
--- Within Relations Panel:
--- - `<CR>` - Navigate to selected item
--- - `<C-]>` - Explore selected symbol deeper
--- - `<C-o>` - Navigate back in stack
--- - `<Tab>` - Toggle focus mode (expand + preview)
--- - `m` - Toggle bookmark for selected item
--- - `c` - Show coupling metrics
--- - `/` - Search relations
--- - `f` - Cycle coupling filter
--- - `s` - Cycle sort mode
--- - `q` - Close Relations panel
---
---@tag spaghetti-comb-v1.nvim

local M = {}

--- Global plugin object containing configuration and state
---@class SpaghettiCombv2Plugin
---@field config SpaghettiCombv2Config Plugin configuration
---@field state SpaghettiCombv2State Plugin state
local SpaghettiCombv2 = {
    config = {},
    state = {
        navigation_stack = {},
        relations_window = nil,
        active_session = nil,
    },
}

--- Default plugin configuration
---@class SpaghettiCombv2Config
---@field relations SpaghettiCombv2RelationsConfig Relations panel settings
---@field logging SpaghettiCombv2LoggingConfig Logging configuration
---@field languages SpaghettiCombv2LanguagesConfig Language-specific settings
---@field keymaps SpaghettiCombv2KeymapsConfig Key mapping configuration
---@field coupling SpaghettiCombv2CouplingConfig Coupling analysis settings
local default_config = {
    --- Relations panel configuration
    ---@class SpaghettiCombv2RelationsConfig
    ---@field height number Normal split height in lines (default: 15)
    ---@field focus_height number Expanded height in focus mode (default: 30)
    ---@field position string Split position: 'bottom' (default: 'bottom')
    ---@field auto_preview boolean Auto-update preview in focus mode (default: true)
    ---@field show_coupling boolean Show coupling metrics [C:0.7] (default: true)
    relations = {
        height = 15,
        focus_height = 30,
        position = "bottom",
        auto_preview = true,
        show_coupling = true,
    },
    --- Logging configuration
    ---@class SpaghettiCombv2LoggingConfig
    ---@field silent_mode boolean Reduce noise by hiding info messages (default: true)
    ---@field show_debug boolean Show debug messages (default: false)
    ---@field show_trace boolean Show trace messages (default: false)
    logging = {
        silent_mode = true,
        show_debug = false,
        show_trace = false,
    },
    languages = {
        typescript = { enabled = true, coupling_analysis = true },
        javascript = { enabled = true, coupling_analysis = true },
        python = { enabled = true, coupling_analysis = true },
        rust = { enabled = true, coupling_analysis = false },
        go = { enabled = true, coupling_analysis = false },
    },
    keymaps = {
        show_relations = "<leader>sr",
        find_references = "<leader>sf",
        go_definition = "<leader>sd",
        navigate_next = "<leader>sn",
        navigate_prev = "<leader>sp",
        save_session = "<leader>ss",
        load_session = "<leader>sl",
        call_hierarchy_incoming = "<leader>sci",
        call_hierarchy_outgoing = "<leader>sco",
        show_navigation_history = "<leader>sh",
        bookmark_current = "<leader>sb",
        bidirectional_context = "<leader>sc",
        auto_backup = "<leader>sab",
        clean_sessions = "<leader>scs",
    },
    coupling = {
        enabled = true,
        threshold_high = 0.7,
        threshold_medium = 0.4,
        show_metrics = true,
    },
}

local function merge_config(user_config) return vim.tbl_deep_extend("force", default_config, user_config or {}) end

local function setup_commands()
    vim.api.nvim_create_user_command(
        "SpaghettiCombv2Show",
        function() require("spaghetti-comb-v1.ui.relations").show_relations() end,
        { desc = "Show Relations panel for symbol under cursor" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombv2References",
        function() require("spaghetti-comb-v1.analyzer").find_references() end,
        { desc = "Show where current function is used" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombv2Definition",
        function() require("spaghetti-comb-v1.analyzer").go_to_definition() end,
        { desc = "Show where symbol is defined" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombv2Next",
        function() require("spaghetti-comb-v1.navigation").navigate_next() end,
        { desc = "Navigate forward in exploration stack" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombv2Prev",
        function() require("spaghetti-comb-v1.navigation").navigate_prev() end,
        { desc = "Navigate backward in exploration stack" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombv2Toggle",
        function() require("spaghetti-comb-v1.ui.relations").toggle_relations() end,
        { desc = "Toggle Relations panel visibility" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombv2Save",
        function(opts)
            require("spaghetti-comb-v1.persistence.storage").save_session(opts.args ~= "" and opts.args or nil)
        end,
        { desc = "Save current exploration session", nargs = "?" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombv2Load",
        function(opts)
            require("spaghetti-comb-v1.persistence.storage").load_session(opts.args ~= "" and opts.args or nil)
        end,
        { desc = "Load saved exploration session", nargs = "?" }
    )

    vim.api.nvim_create_user_command("SpaghettiCombv2ListSessions", function()
        local sessions = require("spaghetti-comb-v1.persistence.storage").list_sessions()
        if #sessions == 0 then
            require("spaghetti-comb-v1.utils").info("No saved sessions found")
        else
            local lines = { "Available sessions:" }
            for _, session in ipairs(sessions) do
                table.insert(
                    lines,
                    string.format("  %s (modified: %s)", session.name, os.date("%Y-%m-%d %H:%M", session.mtime))
                )
            end
            vim.notify(table.concat(lines, "\n"))
        end
    end, { desc = "List all saved exploration sessions" })

    vim.api.nvim_create_user_command(
        "SpaghettiCombv2CallHierarchyIncoming",
        function() require("spaghetti-comb-v1.analyzer").get_call_hierarchy_incoming() end,
        { desc = "Show incoming calls (who calls this function)" }
    )

    vim.api.nvim_create_user_command(
        "SpaghettiCombv2CallHierarchyOutgoing",
        function() require("spaghetti-comb-v1.analyzer").get_call_hierarchy_outgoing() end,
        { desc = "Show outgoing calls (what this function calls)" }
    )

    vim.api.nvim_create_user_command("SpaghettiCombv2NavigationHistory", function()
        local summary = require("spaghetti-comb-v1.navigation").get_navigation_summary()
        if #summary.entries == 0 then
            require("spaghetti-comb-v1.utils").info("Navigation stack is empty")
        else
            local lines = { string.format("Navigation History (%d/%d):", summary.current_index, summary.total) }
            for _, entry in ipairs(summary.entries) do
                local marker = entry.is_current and ">> " or "   "
                local bookmark = entry.bookmarked and "★ " or ""
                table.insert(
                    lines,
                    string.format("%s%s%s:%d %s", marker, bookmark, entry.relative_path, entry.line, entry.symbol)
                )
            end
            vim.notify(table.concat(lines, "\n"))
        end
    end, { desc = "Show navigation history" })

    vim.api.nvim_create_user_command("SpaghettiCombv2BookmarkCurrent", function()
        require("spaghetti-comb-v1.navigation").update_current_entry({ bookmarked = true })
        require("spaghetti-comb-v1.utils").info("Current navigation entry bookmarked")
    end, { desc = "Bookmark current navigation entry" })

    vim.api.nvim_create_user_command(
        "SpaghettiCombv2Analyze",
        function() require("spaghetti-comb-v1.analyzer").analyze_current_symbol() end,
        { desc = "Analyze current symbol (show all relations)" }
    )

    vim.api.nvim_create_user_command("SpaghettiCombv2NavigateByOffset", function(opts)
        local offset = tonumber(opts.args)
        if not offset then
            require("spaghetti-comb-v1.utils").warn("Invalid offset: " .. opts.args)
            return
        end
        require("spaghetti-comb-v1.navigation").navigate_by_offset(offset)
    end, { desc = "Navigate by offset in stack", nargs = 1 })

    vim.api.nvim_create_user_command("SpaghettiCombv2BidirectionalContext", function()
        local context = require("spaghetti-comb-v1.navigation").get_bidirectional_context(5, 5)
        local lines = { "Navigation Context:" }

        if context.current then
            table.insert(
                lines,
                string.format(
                    "Current: %s at %s:%d",
                    context.current.symbol,
                    context.current.relative_path,
                    context.current.line
                )
            )
        end

        if #context.back_entries > 0 then
            table.insert(lines, "\nBack entries:")
            for _, entry in ipairs(context.back_entries) do
                table.insert(
                    lines,
                    string.format("  -%d: %s at %s:%d", entry.distance, entry.symbol, entry.relative_path, entry.line)
                )
            end
        end

        if #context.forward_entries > 0 then
            table.insert(lines, "\nForward entries:")
            for _, entry in ipairs(context.forward_entries) do
                table.insert(
                    lines,
                    string.format("  +%d: %s at %s:%d", entry.distance, entry.symbol, entry.relative_path, entry.line)
                )
            end
        end

        vim.notify(table.concat(lines, "\n"))
    end, { desc = "Show bidirectional navigation context" })

    vim.api.nvim_create_user_command("SpaghettiCombv2AutoBackup", function()
        local success = require("spaghetti-comb-v1.persistence.storage").auto_backup_session()
        if success then
            require("spaghetti-comb-v1.utils").info("Auto-backup session created")
        else
            require("spaghetti-comb-v1.utils").warn("No navigation stack to backup")
        end
    end, { desc = "Create automatic backup session" })

    vim.api.nvim_create_user_command(
        "SpaghettiCombv2CleanOldSessions",
        function() require("spaghetti-comb-v1.persistence.storage").clean_old_auto_sessions() end,
        { desc = "Clean old auto-backup sessions" }
    )
end

local function setup_keymaps()
    local keymaps = SpaghettiCombv2.config.keymaps

    vim.keymap.set("n", keymaps.show_relations, "<cmd>SpaghettiCombv2Show<cr>", { desc = "Show Relations panel" })
    vim.keymap.set("n", keymaps.find_references, "<cmd>SpaghettiCombv2References<cr>", { desc = "Find references" })
    vim.keymap.set("n", keymaps.go_definition, "<cmd>SpaghettiCombv2Definition<cr>", { desc = "Go to definition" })
    vim.keymap.set("n", keymaps.navigate_next, "<cmd>SpaghettiCombv2Next<cr>", { desc = "Navigate forward in stack" })
    vim.keymap.set("n", keymaps.navigate_prev, "<cmd>SpaghettiCombv2Prev<cr>", { desc = "Navigate backward in stack" })
    vim.keymap.set("n", keymaps.save_session, "<cmd>SpaghettiCombv2Save<cr>", { desc = "Save session" })
    vim.keymap.set("n", keymaps.load_session, "<cmd>SpaghettiCombv2Load<cr>", { desc = "Load session" })
    vim.keymap.set(
        "n",
        keymaps.call_hierarchy_incoming,
        "<cmd>SpaghettiCombv2CallHierarchyIncoming<cr>",
        { desc = "Show incoming calls" }
    )
    vim.keymap.set(
        "n",
        keymaps.call_hierarchy_outgoing,
        "<cmd>SpaghettiCombv2CallHierarchyOutgoing<cr>",
        { desc = "Show outgoing calls" }
    )
    vim.keymap.set(
        "n",
        keymaps.show_navigation_history,
        "<cmd>SpaghettiCombv2NavigationHistory<cr>",
        { desc = "Show navigation history" }
    )
    vim.keymap.set(
        "n",
        keymaps.bookmark_current,
        "<cmd>SpaghettiCombv2BookmarkCurrent<cr>",
        { desc = "Bookmark current" }
    )
    vim.keymap.set(
        "n",
        keymaps.bidirectional_context,
        "<cmd>SpaghettiCombv2BidirectionalContext<cr>",
        { desc = "Show bidirectional navigation context" }
    )
    vim.keymap.set(
        "n",
        keymaps.auto_backup,
        "<cmd>SpaghettiCombv2AutoBackup<cr>",
        { desc = "Create auto-backup session" }
    )
    vim.keymap.set(
        "n",
        keymaps.clean_sessions,
        "<cmd>SpaghettiCombv2CleanOldSessions<cr>",
        { desc = "Clean old sessions" }
    )
end

--- Setup SpaghettiCombv2 plugin with user configuration
---
--- This function initializes the plugin with the provided configuration,
--- sets up user commands and key mappings, and initializes the navigation system.
---
---@param user_config? SpaghettiCombv2Config User configuration (optional)
---
---@usage >lua
---   require('spaghetti-comb-v1').setup()
---   -- OR with custom config
---   require('spaghetti-comb-v1').setup({
---     relations = {
---       height = 20,
---       focus_height = 40
---     },
---     keymaps = {
---       show_relations = '<leader>cr'
---     }
---   })
--- <
function M.setup(user_config)
    SpaghettiCombv2.config = merge_config(user_config)

    -- Configure logging based on user settings
    if SpaghettiCombv2.config.logging then
        require("spaghetti-comb-v1.utils").set_log_config(SpaghettiCombv2.config.logging)
    end

    setup_commands()
    setup_keymaps()

    require("spaghetti-comb-v1.navigation").init(SpaghettiCombv2.state.navigation_stack)
end

--- Get current plugin configuration
---@return SpaghettiCombv2Config Current configuration
function M.get_config() return SpaghettiCombv2.config end

--- Get current plugin state
---@return SpaghettiCombv2State Current plugin state
function M.get_state() return SpaghettiCombv2.state end

return M
