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
    local commands = require("spaghetti-comb-v2.navigation.commands")

    -- Setup components with config
    history_manager.setup(state.config)
    commands.setup(state.config)

    state.initialized = true
end

-- Get current configuration
function M.get_config() return state.config end

-- Check if plugin is initialized
function M.is_initialized() return state.initialized end

return M
