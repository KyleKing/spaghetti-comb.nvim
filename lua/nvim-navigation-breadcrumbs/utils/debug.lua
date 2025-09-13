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
  local log_dir = vim.fn.stdpath('log')
  state.log_file = log_dir .. '/nvim-navigation-breadcrumbs.log'
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
  if type(level) == "string" then
    return LOG_LEVELS[level:upper()] or LOG_LEVELS.INFO
  end
  return level or LOG_LEVELS.INFO
end

-- Check if logging is enabled for level
local function should_log(level)
  if not state.config then
    return level >= LOG_LEVELS.ERROR  -- Always log errors
  end
  
  local config_level = get_log_level(state.config.log_level or "info")
  local message_level = get_log_level(level)
  
  return state.config.enabled or message_level >= LOG_LEVELS.ERROR
end

-- Core logging function
function M.log(level, message, data)
  if not should_log(level) then
    return
  end
  
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local level_str = ""
  
  for name, num in pairs(LOG_LEVELS) do
    if num == get_log_level(level) then
      level_str = name
      break
    end
  end
  
  local log_message = string.format("[%s] [%s] %s", timestamp, level_str, message)
  
  if data then
    log_message = log_message .. " " .. vim.inspect(data)
  end
  
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
    
    vim.notify("nvim-navigation-breadcrumbs: " .. message, vim_level)
  end
end

-- Convenience logging functions
function M.debug(message, data)
  M.log("DEBUG", message, data)
end

function M.info(message, data)
  M.log("INFO", message, data)
end

function M.warn(message, data)
  M.log("WARN", message, data)
end

function M.error(message, data)
  M.log("ERROR", message, data)
end

-- State inspection (placeholder for future implementation)
function M.dump_history()
  -- TODO: Implement in task 9.1
end

function M.dump_config()
  M.info("Current configuration", state.config)
end

function M.dump_bookmarks()
  -- TODO: Implement in task 9.1
end

-- Log management
function M.set_log_level(level)
  if state.config then
    state.config.log_level = level
  end
end

function M.is_debug_enabled()
  return state.config and state.config.enabled and get_log_level(state.config.log_level) <= LOG_LEVELS.DEBUG
end

return M