-- Main plugin entry point
local M = {}

-- Plugin version
M.version = "0.1.0"

-- Default configuration
local default_config = require("spaghetti-comb-v2.config").default

-- Plugin state
local state = {
    initialized = false,
    config = nil,
}

-- Initialize the plugin
function M.setup(opts)
    if state.initialized then return end

    -- Merge user config with defaults
    state.config = vim.tbl_deep_extend("force", default_config, opts or {})

    -- Initialize core components
    local history_manager = require("spaghetti-comb-v2.history.manager")
    local bookmarks = require("spaghetti-comb-v2.history.bookmarks")
    local commands = require("spaghetti-comb-v2.navigation.commands")
    local events = require("spaghetti-comb-v2.navigation.events")
    local jumplist = require("spaghetti-comb-v2.navigation.jumplist")
    local lsp_integration = require("spaghetti-comb-v2.navigation.lsp")
    local debug_utils = require("spaghetti-comb-v2.utils.debug")

    -- UI components
    local breadcrumbs = require("spaghetti-comb-v2.ui.breadcrumbs")
    local preview = require("spaghetti-comb-v2.ui.preview")
    local floating_tree = require("spaghetti-comb-v2.ui.floating_tree")
    local picker = require("spaghetti-comb-v2.ui.picker")
    local statusline = require("spaghetti-comb-v2.ui.statusline")

    -- Setup debug logging first
    debug_utils.setup(state.config.debug)

    -- Setup components with config
    history_manager.setup(state.config)
    bookmarks.setup(state.config)
    commands.setup(state.config)
    events.setup(state.config)
    jumplist.setup(state.config)
    lsp_integration.setup(state.config)

    -- Setup UI components
    preview.setup(state.config)
    breadcrumbs.setup(state.config)
    floating_tree.setup(state.config)
    picker.setup(state.config)
    statusline.setup(state.config)

    -- Setup persistence (auto-save on exit if enabled)
    if state.config.history and state.config.history.save_on_exit then
        history_manager.setup_auto_save()
        bookmarks.setup_auto_save()
    end

    state.initialized = true
end

-- Get current configuration
function M.get_config() return state.config end

-- Check if plugin is initialized
function M.is_initialized() return state.initialized end

return M
