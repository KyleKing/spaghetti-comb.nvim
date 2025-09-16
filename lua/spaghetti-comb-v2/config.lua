-- Configuration management
local M = {}

-- Default configuration schema
M.default = {
  -- Display options
  display = {
    enabled = true,
    max_items = 10,
    hotkey_only = true,  -- Show only on hotkey press
    collapse_unfocused = true,  -- Mini.files-like behavior
  },
  
  -- History management
  history = {
    max_entries = 1000,
    max_age_minutes = 30,
    pruning_debounce_minutes = 2,
    save_on_exit = false,  -- Optional persistence
    exploration_timeout_minutes = 5,  -- For statusline state
  },
  
  -- Integration settings
  integration = {
    jumplist = true,  -- Extend built-in jumplist
    lsp = true,  -- Extend built-in LSP
    mini_pick = true,  -- Use mini.pick if available
    statusline = true,  -- Show branch info in statusline
  },
  
  -- Visual settings
  visual = {
    use_unicode_tree = true,  -- Unicode box-drawing chars
    color_scheme = "subtle",  -- For tree readability
    floating_window_width = 80,
    floating_window_height = 20,
  },
  
  -- Bookmark settings
  bookmarks = {
    frequent_threshold = 3,  -- Visits to mark as frequent
    auto_bookmark_frequent = true,
  },
  
  -- Debug settings
  debug = {
    enabled = false,
    log_level = "info",  -- "debug", "info", "warn", "error"
  }
}

-- Validate configuration
function M.validate(config)
  local errors = {}
  
  -- Validate display settings
  if config.display then
    if config.display.max_items and (type(config.display.max_items) ~= "number" or config.display.max_items < 1) then
      table.insert(errors, "display.max_items must be a positive number")
    end
  end
  
  -- Validate history settings
  if config.history then
    if config.history.max_entries and (type(config.history.max_entries) ~= "number" or config.history.max_entries < 1) then
      table.insert(errors, "history.max_entries must be a positive number")
    end
    if config.history.max_age_minutes and (type(config.history.max_age_minutes) ~= "number" or config.history.max_age_minutes < 1) then
      table.insert(errors, "history.max_age_minutes must be a positive number")
    end
  end
  
  -- Validate visual settings
  if config.visual then
    if config.visual.floating_window_width and (type(config.visual.floating_window_width) ~= "number" or config.visual.floating_window_width < 10) then
      table.insert(errors, "visual.floating_window_width must be at least 10")
    end
    if config.visual.floating_window_height and (type(config.visual.floating_window_height) ~= "number" or config.visual.floating_window_height < 5) then
      table.insert(errors, "visual.floating_window_height must be at least 5")
    end
  end
  
  return #errors == 0, errors
end

-- Merge configurations
function M.merge(base, override)
  return vim.tbl_deep_extend("force", base, override or {})
end

return M