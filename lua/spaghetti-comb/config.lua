-- Configuration management
local M = {}

-- Default configuration schema
M.default = {
    -- Display options
    display = {
        enabled = true,
        max_items = 10,
        hotkey_only = true, -- Show only on hotkey press
        collapse_unfocused = true, -- Mini.files-like behavior
    },

    -- History management
    history = {
        max_entries = 1000,
        max_age_minutes = 30,
        pruning_debounce_minutes = 2,
        save_on_exit = false, -- Optional persistence
        exploration_timeout_minutes = 5, -- For statusline state
    },

    -- Integration settings
    integration = {
        jumplist = true, -- Extend built-in jumplist
        lsp = true, -- Extend built-in LSP
        mini_pick = true, -- Use mini.pick if available
        statusline = true, -- Show branch info in statusline
    },

    -- Visual settings
    visual = {
        use_unicode_tree = true, -- Unicode box-drawing chars
        color_scheme = "subtle", -- For tree readability
        floating_window_width = 80,
        floating_window_height = 20,
    },

    -- Bookmark settings
    bookmarks = {
        frequent_threshold = 3, -- Visits to mark as frequent
        auto_bookmark_frequent = true,
    },

    -- Debug settings
    debug = {
        enabled = false,
        log_level = "info", -- "debug", "info", "warn", "error"
    },
}

local COLOR_SCHEMES = { subtle = true }
local LOG_LEVELS = { debug = true, info = true, warn = true, error = true }

local function is_table(value) return type(value) == "table" end

local function is_boolean(value) return type(value) == "boolean" end

local function positive_number(value) return type(value) == "number" and value > 0 end

local function at_least(minimum)
    return function(value) return type(value) == "number" and value >= minimum end
end

-- { path, check, expectation } — checked only when the value is present, so a
-- missing key falls through to the default rather than flagging an error.
local FIELD_RULES = {
    { "display", is_table, "must be a table" },
    { "display.enabled", is_boolean, "must be a boolean" },
    { "display.max_items", positive_number, "must be a positive number" },
    { "display.hotkey_only", is_boolean, "must be a boolean" },
    { "display.collapse_unfocused", is_boolean, "must be a boolean" },
    { "history", is_table, "must be a table" },
    { "history.max_entries", positive_number, "must be a positive number" },
    { "history.max_age_minutes", positive_number, "must be a positive number" },
    { "history.pruning_debounce_minutes", positive_number, "must be a positive number" },
    { "history.save_on_exit", is_boolean, "must be a boolean" },
    { "history.exploration_timeout_minutes", positive_number, "must be a positive number" },
    { "history.jump_debounce_ms", positive_number, "must be a positive number" },
    { "integration", is_table, "must be a table" },
    { "integration.jumplist", is_boolean, "must be a boolean" },
    { "integration.lsp", is_boolean, "must be a boolean" },
    { "integration.mini_pick", is_boolean, "must be a boolean" },
    { "integration.statusline", is_boolean, "must be a boolean" },
    { "visual", is_table, "must be a table" },
    { "visual.use_unicode_tree", is_boolean, "must be a boolean" },
    { "visual.color_scheme", function(value) return COLOR_SCHEMES[value] == true end, "must be one of: subtle" },
    { "visual.floating_window_width", at_least(10), "must be at least 10" },
    { "visual.floating_window_height", at_least(5), "must be at least 5" },
    { "bookmarks", is_table, "must be a table" },
    { "bookmarks.frequent_threshold", positive_number, "must be a positive number" },
    { "bookmarks.auto_bookmark_frequent", is_boolean, "must be a boolean" },
    { "debug", is_table, "must be a table" },
    { "debug.enabled", is_boolean, "must be a boolean" },
    {
        "debug.log_level",
        function(value) return LOG_LEVELS[value] == true end,
        "must be one of: debug, info, warn, error",
    },
}

local function get_path(tbl, path)
    local node = tbl
    for key in path:gmatch("[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = node[key]
    end
    return node
end

local function clear_path(tbl, path)
    local keys = {}
    for key in path:gmatch("[^%.]+") do
        table.insert(keys, key)
    end
    local node = tbl
    for i = 1, #keys - 1 do
        node = node[keys[i]]
        if type(node) ~= "table" then return end
    end
    node[keys[#keys]] = nil
end

-- Collect { path, message } for every present-but-invalid value
local function collect_errors(config)
    local errors = {}

    for _, rule in ipairs(FIELD_RULES) do
        local value = get_path(config, rule[1])
        if value ~= nil and not rule[2](value) then
            table.insert(errors, {
                path = rule[1],
                message = string.format("%s %s (got %s)", rule[1], rule[3], vim.inspect(value)),
            })
        end
    end

    if config.keymaps ~= nil then
        if type(config.keymaps) ~= "table" then
            table.insert(errors, {
                path = "keymaps",
                message = string.format("keymaps must be a table (got %s)", vim.inspect(config.keymaps)),
            })
        else
            for name, binding in pairs(config.keymaps) do
                if type(binding) ~= "string" and type(binding) ~= "function" then
                    table.insert(errors, {
                        path = "keymaps." .. tostring(name),
                        message = string.format(
                            "keymaps.%s must be a string or function (got %s)",
                            tostring(name),
                            vim.inspect(binding)
                        ),
                    })
                end
            end
        end
    end

    return errors
end

-- Validate configuration
---@param config table User-supplied config (pre-merge)
---@return boolean valid
---@return string[] errors One message per invalid key
function M.validate(config)
    local messages = {}
    for _, err in ipairs(collect_errors(config or {})) do
        table.insert(messages, err.message)
    end
    return #messages == 0, messages
end

-- Strip invalid values so the merge falls back to defaults for those keys only
---@param opts table|nil User-supplied config (pre-merge)
---@return table cleaned Deep copy of opts with invalid values removed
---@return string[] errors One message per removed key
function M.sanitize(opts)
    local cleaned = vim.deepcopy(opts or {})
    local messages = {}

    for _, err in ipairs(collect_errors(cleaned)) do
        clear_path(cleaned, err.path)
        table.insert(messages, err.message)
    end

    return cleaned, messages
end

-- Merge configurations
function M.merge(base, override) return vim.tbl_deep_extend("force", base, override or {}) end

return M
