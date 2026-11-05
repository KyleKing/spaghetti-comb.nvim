-- Adapter over the vera-ai CLI for hybrid semantic search.
local types = require("spaghetti-comb.substrate.types")
local project = require("spaghetti-comb.utils.project")

local M = {}

M.config = {
    vera_path = "vera-ai",
    timeout_ms = 60000,
    default_limit = 10,
    -- Query-by-example reads the file to slice the range; bail past this size.
    max_snippet_bytes = 1024 * 1024,
}

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

-- Subprocess runner; tests replace it to fake vera-ai output.
---@type fun(argv: string[], callback: fun(result: {code: integer, stdout: string|nil, stderr: string|nil}))
M._exec = default_exec

---@param callback fun(err: string|nil)
local function check_binary(callback)
    if M._binary_validated then return callback(nil) end
    if M._is_executable(M.config.vera_path) ~= 1 then
        return callback(
            string.format(
                "vera-ai binary not found at '%s'. Install Vera, then run `vera index .` in your project",
                M.config.vera_path
            )
        )
    end
    M._binary_validated = true
    callback(nil)
end

---@param args string[]
---@param callback fun(result: {code: integer, stdout: string|nil, stderr: string|nil})
local function run(args, callback)
    check_binary(function(err)
        if err then
            callback({ code = -1, stdout = "", stderr = err })
            return
        end
        local argv = { M.config.vera_path }
        vim.list_extend(argv, args)
        M._exec(argv, callback)
    end)
end

-- `vera --json` emits a single JSON value; tolerate log lines before it.
---@param stdout string|nil
---@return any|nil parsed
---@return string|nil err
local function parse_json(stdout)
    stdout = stdout or ""
    local first_bracket = stdout:find("[", 1, true)
    local first_brace = stdout:find("{", 1, true)
    local start = nil
    if first_bracket and first_brace then
        start = math.min(first_bracket, first_brace)
    else
        start = first_bracket or first_brace
    end
    if not start then return nil, "vera-ai: no JSON found in output" end
    local ok, parsed = pcall(vim.json.decode, stdout:sub(start))
    if not ok then return nil, "vera-ai: failed to parse JSON output: " .. tostring(parsed) end
    return parsed, nil
end

---@param result {code: integer, stdout: string|nil, stderr: string|nil}
---@return any|nil parsed
---@return string|nil err
local function parse_result(result)
    if result.code ~= 0 then
        local detail = result.stderr
        if not detail or detail == "" then detail = result.stdout end
        if not detail or detail == "" then detail = "no output" end
        return nil, string.format("vera-ai: exited with code %d: %s", result.code, vim.trim(detail))
    end
    return parse_json(result.stdout)
end

---@param item table
---@return SearchHit
function M._to_search_hit(item)
    return types.search_hit({
        file_path = item.file_path or "",
        line_start = item.line_start or item.line or 1,
        line_end = item.line_end or item.line_start or item.line or 1,
        symbol_name = item.symbol_name or item.name,
        symbol_type = item.symbol_type or item.kind,
        content = item.content,
        score = item.score,
        source = "vera",
    })
end

---@param parsed any
---@return SearchHit[]|nil hits
---@return string|nil err
local function to_search_hits(parsed)
    local list = parsed
    if type(list) == "table" and not vim.islist(list) then list = list.results or list.hits end
    if type(list) ~= "table" or not vim.islist(list) then
        return nil, "vera-ai: unexpected response shape (expected a JSON array)"
    end
    local hits = {}
    for _, item in ipairs(list) do
        table.insert(hits, M._to_search_hit(item))
    end
    return hits, nil
end

---@param query string
---@param opts {limit: integer|nil, lang: string|nil, path: string|nil, scope: string|nil}|nil
---@param callback fun(hits: SearchHit[]|nil, err: string|nil)
local function cli_search(query, opts, callback)
    -- Query goes last behind `--`: snippet queries can begin with a comment
    -- marker like `--` or `//`, which clap would otherwise read as a flag.
    local args = { "search", "--limit", tostring(opts.limit or M.config.default_limit), "--json" }
    if opts.lang then vim.list_extend(args, { "--lang", opts.lang }) end
    if opts.path then vim.list_extend(args, { "--path", opts.path }) end
    if opts.scope then vim.list_extend(args, { "--scope", opts.scope }) end
    vim.list_extend(args, { "--", query })
    run(args, function(result)
        local parsed, err = parse_result(result)
        if not parsed then return callback(nil, err) end
        callback(to_search_hits(parsed))
    end)
end

---@param query string Natural-language or symbol query
---@param opts {limit: integer|nil, lang: string|nil, path: string|nil, scope: string|nil}|nil
---@param callback fun(hits: SearchHit[]|nil, err: string|nil)
function M.search(query, opts, callback) cli_search(query, opts or {}, callback) end

---@param file_path string
---@param line_start integer
---@param line_end integer
---@return string|nil snippet
---@return string|nil err
function M._read_range(file_path, line_start, line_end)
    local fd = vim.uv.fs_open(file_path, "r", 438)
    if not fd then return nil, "vera-ai: cannot read " .. file_path end
    local stat = vim.uv.fs_fstat(fd)
    if not stat then
        vim.uv.fs_close(fd)
        return nil, "vera-ai: cannot stat " .. file_path
    end
    if stat.size > M.config.max_snippet_bytes then
        vim.uv.fs_close(fd)
        return nil, "vera-ai: file too large for query-by-example: " .. file_path
    end
    local raw = vim.uv.fs_read(fd, stat.size, 0)
    vim.uv.fs_close(fd)
    if not raw then return nil, "vera-ai: cannot read " .. file_path end

    local lines = vim.split(raw, "\n")
    local selected = {}
    for i = line_start, math.min(line_end, #lines) do
        table.insert(selected, lines[i])
    end
    local snippet = table.concat(selected, "\n")
    if vim.trim(snippet) == "" then return nil, "vera-ai: line range is empty in " .. file_path end
    return snippet, nil
end

-- Query-by-example: search with the code at the given range as the query.
---@param file_path string
---@param line_start integer
---@param line_end integer
---@param opts {limit: integer|nil, lang: string|nil, path: string|nil, scope: string|nil}|nil
---@param callback fun(hits: SearchHit[]|nil, err: string|nil)
function M.find_related(file_path, line_start, line_end, opts, callback)
    local snippet, err = M._read_range(file_path, line_start, line_end)
    if not snippet then return callback(nil, err) end
    M.search(snippet, opts, callback)
end

---@param callback fun(overview: table|string|nil, err: string|nil)
function M.overview(callback)
    run({ "overview", "--json" }, function(result)
        if result.code ~= 0 then
            local _, err = parse_result(result)
            return callback(nil, err)
        end
        local parsed = parse_json(result.stdout)
        -- overview --json may degrade to text on older versions; hand it back raw.
        if parsed == nil then return callback(vim.trim(result.stdout or "")) end
        callback(parsed, nil)
    end)
end

-- Whether each intent takes a query term, per `vera structural --help`.
local STRUCTURAL_INTENTS = {
    definitions = "required",
    env = "optional",
    impls = "required",
    routes = "none",
    sql = "none",
}

---@param intent string "definitions"|"env"|"impls"|"routes"|"sql"
---@param query string|nil Required for definitions/impls, optional for env, rejected for routes/sql
---@param callback fun(hits: SearchHit[]|nil, err: string|nil)
function M.structural(intent, query, callback)
    local rule = STRUCTURAL_INTENTS[intent]
    if not rule then return callback(nil, "vera-ai: unknown structural intent '" .. tostring(intent) .. "'") end
    if rule == "none" and query ~= nil then
        return callback(nil, "vera-ai: structural intent '" .. intent .. "' takes no query")
    end
    if rule == "required" and (query == nil or query == "") then
        return callback(nil, "vera-ai: structural intent '" .. intent .. "' requires a query")
    end

    local args = { "structural", intent, "--json" }
    if query then table.insert(args, 3, query) end
    run(args, function(result)
        local parsed, err = parse_result(result)
        if not parsed then return callback(nil, err) end
        callback(to_search_hits(parsed))
    end)
end

-- `vera doctor --json` exits 1 when checks fail but still emits the report.
---@param callback fun(health: IndexHealth|nil, err: string|nil)
function M.index_health(callback)
    run({ "doctor", "--json" }, function(result)
        local parsed = parse_json(result.stdout)
        local health = types.index_health({ tool = "vera" })

        if type(parsed) == "table" then
            health.healthy = parsed.overall_ok == true
            local failures = {}
            if vim.islist(parsed.checks) then
                for _, check in ipairs(parsed.checks) do
                    if check.status and check.status ~= "ok" then
                        table.insert(failures, tostring(check.name) .. ": " .. tostring(check.detail))
                    end
                end
            end
            if #failures > 0 then
                health.message = table.concat(failures, "; ")
            elseif parsed.version then
                health.message = "vera v" .. tostring(parsed.version) .. " checks passed"
            end
        else
            health.healthy = result.code == 0
            local detail = result.stdout
            if not detail or detail == "" then detail = result.stderr end
            health.message = detail and vim.trim(detail) or "vera-ai doctor produced no output"
            if result.code == -1 then return callback(nil, health.message) end
        end

        local root = project.get_current_project_root()
        if root then
            local stat = vim.uv.fs_stat(root .. "/.vera")
            if stat then health.index_age_seconds = os.time() - stat.mtime.sec end
        end

        callback(health, nil)
    end)
end

---@param config table|nil
function M.setup(config) M.config = vim.tbl_deep_extend("force", M.config, config or {}) end

function M.reset()
    M._binary_validated = nil
    M._is_executable = vim.fn.executable
    M._exec = default_exec
end

return M
