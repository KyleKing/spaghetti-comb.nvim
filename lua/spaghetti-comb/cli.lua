-- Argument parsing and dispatch for scripts/sc, the agent-facing CLI.
-- Adapter calls are async-callback based; _await drives them to completion
-- with vim.wait so a headless run stays sequential.
local codanna = require("spaghetti-comb.substrate.codanna")
local vera = require("spaghetti-comb.substrate.vera")

local M = {}

M.TIMEOUT_MS = 120000
M.SEARCH_LIMIT = 20

local VERBS = {
    callers = { usage = "<symbol>" },
    calls = { usage = "<symbol>" },
    impact = { usage = "<symbol>" },
    orient = { usage = "" },
    related = { usage = "<file> <line1> <line2>" },
    seek = { usage = "<query...>" },
    status = { usage = "" },
}

---@return string
function M.usage()
    local lines = { "usage: sc <verb> [args]", "", "verbs:" }
    for _, verb in ipairs({ "seek", "related", "callers", "calls", "impact", "orient", "status" }) do
        local suffix = VERBS[verb].usage ~= "" and (" " .. VERBS[verb].usage) or ""
        table.insert(lines, string.format("  sc %s%s", verb, suffix))
    end
    return table.concat(lines, "\n")
end

-- Parse argv (the positional args after the script name) into verb + args.
---@param argv string[]
---@return string|nil verb
---@return string[]|nil args
---@return string|nil err
function M.parse(argv)
    local verb = argv[1]
    if not verb or verb == "" then return nil, nil, M.usage() end
    if not VERBS[verb] then return nil, nil, string.format("sc: unknown verb '%s'\n%s", verb, M.usage()) end

    local args = {}
    for i = 2, #argv do
        table.insert(args, argv[i])
    end

    if verb == "related" then
        if #args < 3 then return nil, nil, "sc: related expects <file> <line1> <line2>" end
        if not tonumber(args[2]) or not tonumber(args[3]) then
            return nil, nil, "sc: related line numbers must be numbers"
        end
    elseif verb == "seek" then
        if #args == 0 then return nil, nil, "sc: seek expects a query" end
    elseif verb ~= "orient" and verb ~= "status" then
        if #args == 0 then return nil, nil, string.format("sc: %s expects a symbol", verb) end
    end

    return verb, args, nil
end

-- Invoke an adapter function and block until its callback fires.
---@param fn function Adapter fn whose last argument is the callback
---@vararg any Arguments ahead of the callback
---@return any|nil result
---@return string|nil err
function M._await(fn, ...)
    local argv = { ... }
    local done, result, result_err = false, nil, nil
    table.insert(argv, function(res, err)
        result, result_err = res, err
        done = true
    end)
    fn(unpack(argv))
    vim.wait(M.TIMEOUT_MS, function() return done end, 10)
    if not done then return nil, "sc: timed out waiting for substrate" end
    return result, result_err
end

---@return table|nil
---@return string|nil err
local function run_orient()
    local report, collect_err = M._await(require("spaghetti-comb.navigation.orient")._collect)
    if not report then return nil, collect_err end
    local root, groups = require("spaghetti-comb.navigation.orient")._build(report)
    if #groups == 0 and #report.errors > 0 then return nil, table.concat(report.errors, "\n") end
    return { root = root, groups = groups, errors = report.errors }
end

---@return table
local function run_status()
    local health = {}
    local codanna_health, codanna_err = M._await(codanna.index_health)
    health.codanna = codanna_health or { tool = "codanna", error = codanna_err }
    local vera_health, vera_err = M._await(vera.index_health)
    health.vera = vera_health or { tool = "vera", error = vera_err }
    return health
end

-- Run a parsed verb and return a JSON-encodable result.
---@param argv string[] Positional args (verb first)
---@return any|nil result
---@return string|nil err
function M.run(argv)
    local verb, args, err = M.parse(argv)
    if not verb then return nil, err end

    if verb == "seek" then
        return M._await(vera.search, table.concat(args, " "), { limit = M.SEARCH_LIMIT })
    elseif verb == "related" then
        return M._await(vera.find_related, args[1], tonumber(args[2]), tonumber(args[3]), { limit = M.SEARCH_LIMIT })
    elseif verb == "callers" then
        return M._await(codanna.find_callers, args[1])
    elseif verb == "calls" then
        return M._await(codanna.get_calls, args[1])
    elseif verb == "impact" then
        return M._await(codanna.analyze_impact, args[1])
    elseif verb == "orient" then
        return run_orient()
    elseif verb == "status" then
        return run_status()
    end
    return nil, "sc: unhandled verb '" .. verb .. "'"
end

return M
