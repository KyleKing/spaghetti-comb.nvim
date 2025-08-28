local utils = require("spaghetti-comb.utils")

local M = {}

local error_state = {
    recent_errors = {},
    error_count = 0,
    last_error_time = 0,
    max_recent_errors = 10,
}

local ERROR_TYPES = {
    LSP_ERROR = "lsp_error",
    FILE_ERROR = "file_error",
    PARSING_ERROR = "parsing_error",
    NETWORK_ERROR = "network_error",
    TREESITTER_ERROR = "treesitter_error",
    CONFIG_ERROR = "config_error",
    UNKNOWN_ERROR = "unknown_error",
}

local ERROR_SEVERITY = {
    LOW = 1,
    MEDIUM = 2,
    HIGH = 3,
    CRITICAL = 4,
}

function M.classify_error(error_msg, context)
    context = context or {}

    if not error_msg then return ERROR_TYPES.UNKNOWN_ERROR, ERROR_SEVERITY.LOW end

    error_msg = tostring(error_msg):lower()

    if error_msg:match("lsp") or error_msg:match("language server") then
        return ERROR_TYPES.LSP_ERROR, ERROR_SEVERITY.MEDIUM
    elseif error_msg:match("file") or error_msg:match("no such file") or error_msg:match("permission denied") then
        return ERROR_TYPES.FILE_ERROR, ERROR_SEVERITY.MEDIUM
    elseif error_msg:match("treesitter") or error_msg:match("parser") then
        return ERROR_TYPES.TREESITTER_ERROR, ERROR_SEVERITY.LOW
    elseif error_msg:match("json") or error_msg:match("parse") or error_msg:match("syntax") then
        return ERROR_TYPES.PARSING_ERROR, ERROR_SEVERITY.MEDIUM
    elseif error_msg:match("network") or error_msg:match("connection") or error_msg:match("timeout") then
        return ERROR_TYPES.NETWORK_ERROR, ERROR_SEVERITY.HIGH
    elseif error_msg:match("config") or error_msg:match("setting") then
        return ERROR_TYPES.CONFIG_ERROR, ERROR_SEVERITY.HIGH
    else
        return ERROR_TYPES.UNKNOWN_ERROR, ERROR_SEVERITY.LOW
    end
end

function M.handle_error(error_msg, context, fallback_fn)
    context = context or {}
    local error_type, severity = M.classify_error(error_msg, context)

    local error_info = {
        message = tostring(error_msg),
        type = error_type,
        severity = severity,
        context = context,
        timestamp = os.time(),
        stack_trace = debug.traceback(),
    }

    table.insert(error_state.recent_errors, 1, error_info)

    if #error_state.recent_errors > error_state.max_recent_errors then table.remove(error_state.recent_errors) end

    error_state.error_count = error_state.error_count + 1
    error_state.last_error_time = os.time()

    if severity >= ERROR_SEVERITY.HIGH then
        utils.error(string.format("[%s] %s", error_type, error_msg))
    elseif severity >= ERROR_SEVERITY.MEDIUM then
        utils.warn(string.format("[%s] %s", error_type, error_msg))
    else
        utils.debug(string.format("[%s] %s", error_type, error_msg))
    end

    if fallback_fn and type(fallback_fn) == "function" then
        local success, result = pcall(fallback_fn, error_info)
        if success then return result end
    end

    return M.get_default_fallback(error_type, context)
end

function M.get_default_fallback(error_type, context)
    local fallbacks = {
        [ERROR_TYPES.LSP_ERROR] = function(ctx)
            utils.debug("Falling back to treesitter and grep-based analysis")
            return { locations = {}, fallback_used = "treesitter_grep" }
        end,
        [ERROR_TYPES.FILE_ERROR] = function(ctx) return { locations = {}, error = "File not accessible" } end,
        [ERROR_TYPES.TREESITTER_ERROR] = function(ctx)
            utils.debug("Falling back to basic text matching")
            return { locations = {}, fallback_used = "text_matching" }
        end,
        [ERROR_TYPES.PARSING_ERROR] = function(ctx) return { locations = {}, error = "Unable to parse content" } end,
        [ERROR_TYPES.NETWORK_ERROR] = function(ctx)
            return { locations = {}, error = "Network issue, using cached results" }
        end,
        [ERROR_TYPES.CONFIG_ERROR] = function(ctx)
            utils.warn("Using default configuration")
            return { config_fallback = true }
        end,
        [ERROR_TYPES.UNKNOWN_ERROR] = function(ctx) return { locations = {}, error = "Unknown error occurred" } end,
    }

    local fallback_fn = fallbacks[error_type]
    if fallback_fn then return fallback_fn(context) end

    return { locations = {}, error = "No fallback available" }
end

function M.safe_call(fn, context, fallback_fn)
    context = context or {}

    if type(fn) ~= "function" then
        return M.handle_error("Invalid function provided to safe_call", context, fallback_fn)
    end

    local success, result = pcall(fn)

    if success then
        return result
    else
        return M.handle_error(result, context, fallback_fn)
    end
end

function M.safe_lsp_call(method, params, callback, context)
    context = context or {}
    context.lsp_method = method

    local function lsp_fallback(error_info)
        if method == "textDocument/references" then
            return require("spaghetti-comb.analyzer").find_references_fallback(context.symbol_text or "")
        elseif method == "textDocument/definition" then
            return require("spaghetti-comb.analyzer").find_definitions_treesitter(
                context.symbol_text or "",
                context.bufnr or vim.api.nvim_get_current_buf()
            )
        end
        return {}
    end

    local function safe_callback(result, err)
        if err then
            local fallback_result = M.handle_error(err.message or tostring(err), context, lsp_fallback)
            callback(fallback_result, nil)
        else
            callback(result, err)
        end
    end

    local clients = vim.lsp.get_clients and vim.lsp.get_clients({ bufnr = context.bufnr })
        or vim.lsp.get_active_clients({ bufnr = context.bufnr })

    if #clients == 0 then
        local fallback_result = M.handle_error("No LSP clients available", context, lsp_fallback)
        callback(fallback_result, nil)
        return
    end

    local client = clients[1]

    local timeout_timer = vim.loop.new_timer()
    local request_completed = false

    timeout_timer:start(5000, 0, function()
        if not request_completed then
            request_completed = true
            timeout_timer:close()
            local fallback_result = M.handle_error("LSP request timeout", context, lsp_fallback)
            vim.schedule(function() callback(fallback_result, nil) end)
        end
    end)

    client.request(method, params, function(err, result)
        if not request_completed then
            request_completed = true
            timeout_timer:close()
            safe_callback(result, err)
        end
    end)
end

function M.safe_file_operation(file_path, operation, fallback_fn)
    if not file_path or file_path == "" then
        return M.handle_error("Invalid file path", { file_path = file_path }, fallback_fn)
    end

    if not vim.fn.filereadable(file_path) then
        return M.handle_error("File not readable: " .. file_path, { file_path = file_path }, fallback_fn)
    end

    return M.safe_call(function() return operation(file_path) end, { file_path = file_path }, fallback_fn)
end

function M.get_error_summary()
    return {
        total_errors = error_state.error_count,
        recent_errors = #error_state.recent_errors,
        last_error_time = error_state.last_error_time,
        error_types = M.get_error_type_counts(),
    }
end

function M.get_error_type_counts()
    local counts = {}
    for _, error_info in ipairs(error_state.recent_errors) do
        counts[error_info.type] = (counts[error_info.type] or 0) + 1
    end
    return counts
end

function M.clear_error_history()
    error_state.recent_errors = {}
    error_state.error_count = 0
    error_state.last_error_time = 0
    utils.debug("Error history cleared")
end

function M.get_recent_errors(limit)
    limit = limit or 5
    local recent = {}
    for i = 1, math.min(limit, #error_state.recent_errors) do
        local error_info = error_state.recent_errors[i]
        table.insert(recent, {
            message = error_info.message,
            type = error_info.type,
            severity = error_info.severity,
            timestamp = error_info.timestamp,
            context = error_info.context,
        })
    end
    return recent
end

function M.validate_config(config)
    if not config then
        return M.handle_error(
            "Configuration is nil",
            { config = config },
            function() return require("spaghetti-comb").get_config() or {} end
        )
    end

    if type(config) ~= "table" then
        return M.handle_error("Configuration must be a table", { config = config }, function() return {} end)
    end

    local required_fields = { "relations", "languages", "keymaps" }
    for _, field in ipairs(required_fields) do
        if not config[field] then utils.warn(string.format("Missing configuration field: %s", field)) end
    end

    return config
end

M.ERROR_TYPES = ERROR_TYPES
M.ERROR_SEVERITY = ERROR_SEVERITY

return M
