-- Debug logging utilities
local M = {}

-- Module state
local state = {
    config = nil,
    log_file = nil,
}

-- Setup debug logging
function M.setup(config)
    state.config = config or {}

    -- Set up log file path
    local log_dir = vim.fn.stdpath("log")
    state.log_file = log_dir .. "/spaghetti-comb.log"
end

-- Log levels
local LOG_LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
}

-- Get numeric log level
local function get_log_level(level)
    if type(level) == "string" then return LOG_LEVELS[level:upper()] or LOG_LEVELS.INFO end
    return level or LOG_LEVELS.INFO
end

-- Check if logging is enabled for level
local function should_log(level)
    if not state.config then
        return level >= LOG_LEVELS.ERROR -- Always log errors
    end

    local config_level = get_log_level(state.config.log_level or "info")
    local message_level = get_log_level(level)

    return state.config.enabled or message_level >= LOG_LEVELS.ERROR
end

-- Core logging function
function M.log(level, message, data)
    if not should_log(level) then return end

    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local level_str = ""

    for name, num in pairs(LOG_LEVELS) do
        if num == get_log_level(level) then
            level_str = name
            break
        end
    end

    local log_message = string.format("[%s] [%s] %s", timestamp, level_str, message)

    if data then log_message = log_message .. " " .. vim.inspect(data) end

    -- Write to log file if available
    if state.log_file then
        local file = io.open(state.log_file, "a")
        if file then
            file:write(log_message .. "\n")
            file:close()
        end
    end

    -- Also output to vim messages for errors and warnings
    if get_log_level(level) >= LOG_LEVELS.WARN then
        local vim_level = vim.log.levels.INFO
        if get_log_level(level) >= LOG_LEVELS.ERROR then
            vim_level = vim.log.levels.ERROR
        elseif get_log_level(level) >= LOG_LEVELS.WARN then
            vim_level = vim.log.levels.WARN
        end

        vim.notify("spaghetti-comb: " .. message, vim_level)
    end
end

-- Convenience logging functions
function M.debug(message, data) M.log("DEBUG", message, data) end

function M.info(message, data) M.log("INFO", message, data) end

function M.warn(message, data) M.log("WARN", message, data) end

function M.error(message, data) M.log("ERROR", message, data) end

-- Task 9.1: State inspection commands
function M.dump_history()
    local history_manager = require("spaghetti-comb.history.manager")
    local trail = history_manager.get_current_trail()

    if not trail then
        M.info("No navigation history available")
        return
    end

    M.info("Navigation History", {
        entries = #trail.entries,
        current_index = trail.current_index,
        project_root = trail.project_root,
        branches = vim.tbl_count(trail.branches),
    })

    return trail
end

function M.dump_config()
    local plugin = require("spaghetti-comb")
    local config = plugin.get_config()

    M.info("Current configuration", config)
    return config
end

function M.dump_bookmarks()
    local bookmarks = require("spaghetti-comb.history.bookmarks")
    local all_bookmarks = bookmarks.get_all_bookmarks()

    M.info("Bookmarks", {
        count = #all_bookmarks,
        manual = vim.tbl_filter(function(b) return b.is_manual end, all_bookmarks),
        automatic = vim.tbl_filter(function(b) return not b.is_manual end, all_bookmarks),
    })

    return all_bookmarks
end

function M.dump_all_state()
    M.info("=== Spaghetti Comb State Dump ===")
    M.dump_config()
    M.dump_history()
    M.dump_bookmarks()
    M.info("=== End State Dump ===")
end

-- Log management
function M.set_log_level(level)
    if state.config then state.config.log_level = level end
end

function M.is_debug_enabled()
    return state.config and state.config.enabled and get_log_level(state.config.log_level) <= LOG_LEVELS.DEBUG
end

return M
