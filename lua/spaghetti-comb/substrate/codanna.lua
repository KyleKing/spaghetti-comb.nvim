-- Adapter over the codanna CLI for verified call-graph relations. Self-execs
-- `codanna mcp --json` because codanna.nvim drops the error envelope on non-zero exit.
local types = require("spaghetti-comb.substrate.types")

local M = {}

M.config = {
    timeout_ms = 30000,
    codanna_path = nil, -- nil: use codanna.nvim's configured path
}

---@type table|nil codanna.core module, or a test double
M._core = nil

---@type boolean|nil
M._binary_validated = nil

---@type fun(path: string): integer
M._is_executable = vim.fn.executable

---@param argv string[]
---@param callback fun(result: {code: integer, stdout: string|nil, stderr: string|nil})
local function default_exec(argv, callback)
    vim.system(argv, { text = true, timeout = M.config.timeout_ms }, function(result)
        vim.schedule(function() callback(result) end)
    end)
end

-- Subprocess runner; tests replace it to fake codanna output.
---@type fun(argv: string[], callback: fun(result: {code: integer, stdout: string|nil, stderr: string|nil}))
M._exec = default_exec

---@return table|nil core codanna.core module
---@return string|nil err
local function get_core()
    if M._core then return M._core, nil end
    local ok, core = pcall(require, "codanna.core")
    if not ok then return nil, "codanna substrate requires the codanna.nvim plugin (provides `codanna.core`)" end
    M._core = core
    return core, nil
end

local function codanna_path()
    local core = get_core()
    if M.config.codanna_path then return M.config.codanna_path end
    if core and core.config and core.config.codanna_path then return core.config.codanna_path end
    return "codanna"
end

-- Ambiguity envelopes carry the candidate symbols in data; surface their
-- symbol_id values so the "re-run with symbol_id:<id>" hint is actionable.
---@param env table
---@return string|nil
local function ambiguity_candidates(env)
    if type(env.data) ~= "table" or not vim.islist(env.data) then return nil end
    local candidates = {}
    for _, item in ipairs(env.data) do
        if item.id and item.file_path then
            local line = type(item.range) == "table" and (item.range.start_line or 0) + 1 or item.line
            table.insert(
                candidates,
                string.format("symbol_id:%s %s:%s %s", item.id, item.file_path, line or "?", item.kind or "")
            )
        end
    end
    if #candidates == 0 then return nil end
    return table.concat(candidates, "; ")
end

---@param env table Parsed JSON envelope
---@param process_code integer Process exit code
---@return string err
local function exit_error(env, process_code)
    local code = env.exit_code or process_code
    local message = env.message or "codanna command failed"
    if code == 7 then return "codanna: index version mismatch — run `codanna index --force`" end
    if code == 1 then return string.format("codanna: not found — %s", message) end
    local detail = env.hint and string.format("%s (%s)", message, env.hint) or message
    local candidates = ambiguity_candidates(env)
    if candidates then detail = detail .. "\ncandidates: " .. candidates end
    return string.format("codanna: error (exit %s): %s", tostring(code), detail)
end

-- codanna prints index progress lines to stdout before the JSON envelope,
-- so the parse starts at the first line that opens an object.
---@param result {code: integer, stdout: string|nil, stderr: string|nil}
---@return any|nil data Envelope `data` field on success
---@return string|nil err
function M._parse_envelope(result)
    local stdout = result.stdout or ""
    local lines = vim.split(stdout, "\n")
    local json_start = nil
    for i, line in ipairs(lines) do
        if line:match("^%s*{") then
            json_start = i
            break
        end
    end
    if not json_start then
        local detail = result.stderr
        if not detail or detail == "" then detail = stdout end
        if detail == "" then detail = "no output" end
        return nil, string.format("codanna: exited with code %d: %s", result.code, vim.trim(detail))
    end

    local ok, env = pcall(vim.json.decode, table.concat(lines, "\n", json_start))
    if not ok then return nil, "codanna: failed to parse JSON response: " .. tostring(env) end
    ---@cast env table

    -- codanna uses non-"success" statuses for errors too ("not_found" is its own)
    if env.status ~= "success" then return nil, exit_error(env, result.code) end
    if env.data == vim.NIL then return nil, nil end
    return env.data, nil
end

---@param tool string codanna mcp tool name
---@param args string[]
---@param callback fun(data: any|nil, err: string|nil)
local function run(tool, args, callback)
    local core, err = get_core()
    if not core then
        callback(nil, err)
        return
    end

    local bin = codanna_path()
    if not M._binary_validated then
        if M._is_executable(bin) ~= 1 then
            callback(
                nil,
                string.format(
                    "codanna binary not found at '%s'. Install codanna: https://github.com/bartolli/codanna",
                    bin
                )
            )
            return
        end
        M._binary_validated = true
    end

    local argv = { bin, "mcp", "--json", tool }
    vim.list_extend(argv, args or {})
    M._exec(argv, function(result)
        local data, parse_err = M._parse_envelope(result)
        callback(data, parse_err)
    end)
end

---@param data any
---@return table[]
local function as_list(data)
    if type(data) ~= "table" then return {} end
    if vim.islist(data) then return data end
    if vim.islist(data.results) then return data.results end
    return {}
end

-- codanna ranges are 0-indexed; call_line/call_column are 1-indexed.
---@param item table codanna symbol object
---@param direction RelationDirection
---@return RelationItem
function M._to_relation_item(item, direction)
    local line = item.call_line
    if not line and type(item.range) == "table" then line = (item.range.start_line or 0) + 1 end
    return types.relation_item({
        name = item.name or "unknown",
        kind = item.kind,
        file_path = item.file_path or "",
        line = line or item.line or 1,
        signature = item.signature,
        doc_comment = item.doc_comment,
        direction = direction,
        depth = item.depth,
        symbol_id = item.id,
    })
end

---@param data any
---@param direction RelationDirection
---@return RelationItem[]
function M._to_relation_items(data, direction)
    local items = {}
    for _, item in ipairs(as_list(data)) do
        table.insert(items, M._to_relation_item(item, direction))
    end
    return items
end

-- search_symbols entries wrap the symbol: {symbol = {...}, score, highlights}
---@param entry table
---@return SearchHit
function M._to_search_hit(entry)
    local sym = entry.symbol or entry
    local line_start = sym.line
    local line_end = nil
    if type(sym.range) == "table" then
        line_start = line_start or (sym.range.start_line or 0) + 1
        if sym.range.end_line then line_end = sym.range.end_line + 1 end
    end
    return types.search_hit({
        file_path = sym.file_path or "",
        line_start = line_start or 1,
        line_end = line_end,
        symbol_name = sym.name,
        symbol_type = sym.kind,
        content = sym.signature,
        score = entry.score,
        source = "codanna",
    })
end

---@param symbol string Symbol name or `symbol_id:<id>`
---@param callback fun(items: RelationItem[]|nil, err: string|nil)
function M.find_callers(symbol, callback)
    run("find_callers", { symbol }, function(data, err)
        if err then return callback(nil, err) end
        callback(M._to_relation_items(data, "callers"), nil)
    end)
end

---@param symbol string Symbol name or `symbol_id:<id>`
---@param callback fun(items: RelationItem[]|nil, err: string|nil)
function M.get_calls(symbol, callback)
    run("get_calls", { symbol }, function(data, err)
        if err then return callback(nil, err) end
        callback(M._to_relation_items(data, "calls"), nil)
    end)
end

---@param symbol string Symbol name or `symbol_id:<id>`
---@param callback fun(items: RelationItem[]|nil, err: string|nil)
function M.analyze_impact(symbol, callback)
    run("analyze_impact", { symbol }, function(data, err)
        if err then return callback(nil, err) end
        callback(M._to_relation_items(data, "impact"), nil)
    end)
end

---@param query string
---@param opts {kind: string|nil, limit: integer|nil}|nil
---@param callback fun(hits: SearchHit[]|nil, err: string|nil)
function M.search_symbols(query, opts, callback)
    opts = opts or {}
    local args = { "query:" .. query }
    if opts.kind then table.insert(args, "kind:" .. opts.kind) end
    if opts.limit then table.insert(args, "limit:" .. tostring(opts.limit)) end
    run("search_symbols", args, function(data, err)
        if err then return callback(nil, err) end
        local hits = {}
        for _, entry in ipairs(as_list(data)) do
            table.insert(hits, M._to_search_hit(entry))
        end
        callback(hits, nil)
    end)
end

---@param callback fun(health: IndexHealth|nil, err: string|nil)
function M.index_health(callback)
    run("get_index_info", {}, function(data, err)
        if err then return callback(nil, err) end
        callback(
            types.index_health({
                tool = "codanna",
                indexed_files = data and data.file_count or nil,
                symbol_count = data and data.symbol_count or nil,
                edge_count = data and data.relationship_count or nil,
                message = "codanna index info",
            }),
            nil
        )
    end)
end

---@param config table|nil
function M.setup(config) M.config = vim.tbl_deep_extend("force", M.config, config or {}) end

function M.reset()
    M._core = nil
    M._binary_validated = nil
    M._is_executable = vim.fn.executable
    M._exec = default_exec
end

return M
