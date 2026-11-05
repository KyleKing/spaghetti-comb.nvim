-- Orient command and sc-CLI dispatch tests; substrate calls are stubbed.
local MiniTest = require("mini.test")
local cli = require("spaghetti-comb.cli")
local codanna = require("spaghetti-comb.substrate.codanna")
local orient = require("spaghetti-comb.navigation.orient")
local relations = require("spaghetti-comb.navigation.relations")
local relations_tree = require("spaghetti-comb.ui.relations_tree")
local th = require("spaghetti-comb.tests.helpers")
local vera = require("spaghetti-comb.substrate.vera")

local T = MiniTest.new_set()
local seen = {}

local expect_contains = th.expect_contains

local restore_all = th.save({
    { vera, "overview" },
    { vera, "structural" },
    { vera, "index_health" },
    { vera, "search" },
    { vera, "find_related" },
    { codanna, "index_health" },
    { codanna, "find_callers" },
    { relations_tree, "show" },
    { relations, "jump_to_item" },
    { vim, "notify" },
})

local function pre_case()
    seen = {}
    vim.notify = function(msg, level)
        seen.notify_msg = msg
        seen.notify_level = level
    end
end

local function stub_show() th.stub_show(relations_tree, "show", seen, { "root", "groups", "opts" }) end

local OVERVIEW = {
    file_count = 67,
    chunk_count = 753,
    languages = { { language = "lua", files = 41, chunks = 590 } },
    top_directories = { { directory = "lua", files = 34 } },
    symbol_types = { { symbol_type = "function", count = 463 } },
    conventions = { "GitHub Actions CI" },
    entry_points = { { file_path = "plugin/spaghetti-comb.lua" } },
    hotspots = { { file_path = "lua/spaghetti-comb/history/manager.lua", chunks = 52 } },
}

local function stub_collect(overrides)
    local cfg = overrides or {}
    vera.overview = function(cb)
        if cfg.overview_err then return cb(nil, cfg.overview_err) end
        cb(cfg.overview or OVERVIEW, nil)
    end
    vera.structural = function(intent, query, cb)
        seen.structural_calls = seen.structural_calls or {}
        table.insert(seen.structural_calls, { intent = intent, query = query })
        if cfg.structural_err then return cb(nil, cfg.structural_err) end
        cb((cfg.structure or {})[intent] or {}, nil)
    end
    codanna.index_health = function(cb)
        if cfg.codanna_err then return cb(nil, cfg.codanna_err) end
        cb(cfg.codanna_health or { tool = "codanna", symbol_count = 9, edge_count = 4, healthy = true }, nil)
    end
end

T["build"] = MiniTest.new_set({
    hooks = { pre_case = pre_case, post_case = restore_all },
})

T["build"]["root carries project name plus vera and codanna counts"] = function()
    local root, groups = orient._build({
        root_path = "/proj/spaghetti-comb.nvim",
        overview = OVERVIEW,
        structure = {},
        codanna_health = { tool = "codanna", symbol_count = 9, edge_count = 4, healthy = true },
        errors = {},
    })

    MiniTest.expect.equality(root.name, "spaghetti-comb.nvim — 67 files, 753 chunks, 9 symbols, 4 edges")
    MiniTest.expect.equality(root.file_path, nil)
    MiniTest.expect.equality(#groups, 3)
end

T["build"]["structure hits become labeled jumpable groups"] = function()
    local _, groups = orient._build({
        root_path = "/proj/x",
        overview = nil,
        structure = {
            routes = {
                { file_path = "src/api.py", line_start = 12, symbol_name = "get_users", symbol_type = "Function" },
            },
            env = {},
            sql = {},
        },
        errors = {},
    })

    MiniTest.expect.equality(#groups, 1)
    MiniTest.expect.equality(groups[1].label, "Routes")
    local item = groups[1].items[1]
    MiniTest.expect.equality(item.name, "get_users")
    MiniTest.expect.equality(item.file_path, "src/api.py")
    MiniTest.expect.equality(item.line, 12)
end

T["build"]["parsed overview yields entry points, hotspots, and info lines"] = function()
    local _, groups = orient._build({ root_path = "/proj/x", overview = OVERVIEW, structure = {}, errors = {} })

    MiniTest.expect.equality(groups[1].label, "Entry points")
    MiniTest.expect.equality(groups[1].items[1].file_path, "plugin/spaghetti-comb.lua")
    MiniTest.expect.equality(groups[1].items[1].line, 1)

    MiniTest.expect.equality(groups[2].label, "Hotspots")
    MiniTest.expect.equality(groups[2].items[1].kind, "52 chunks")
    MiniTest.expect.equality(groups[2].items[1].file_path, "lua/spaghetti-comb/history/manager.lua")

    MiniTest.expect.equality(groups[3].label, "Overview")
    local names = {}
    for _, item in ipairs(groups[3].items) do
        table.insert(names, item.name)
        MiniTest.expect.equality(item.file_path, nil)
    end
    expect_contains(table.concat(names, "\n"), "lang lua: 41 files, 590 chunks")
    expect_contains(table.concat(names, "\n"), "dir lua: 34 files")
    expect_contains(table.concat(names, "\n"), "type function: 463")
    expect_contains(table.concat(names, "\n"), "convention: GitHub Actions CI")
end

T["build"]["prose overview renders as read-only lines"] = function()
    local _, groups = orient._build({
        root_path = "/proj/x",
        overview = "Project overview:\n42 files\n\nlots of lua",
        structure = {},
        errors = {},
    })

    MiniTest.expect.equality(#groups, 1)
    MiniTest.expect.equality(groups[1].label, "Overview")
    MiniTest.expect.equality(#groups[1].items, 3)
    MiniTest.expect.equality(groups[1].items[2].name, "42 files")
    MiniTest.expect.equality(groups[1].items[1].file_path, nil)
end

T["collect"] = MiniTest.new_set({
    hooks = { pre_case = pre_case, post_case = restore_all },
})

T["collect"]["queries every unguided intent and aggregates results"] = function()
    stub_collect({ structure = { routes = { { file_path = "r.py", line_start = 1 } } } })

    local report
    orient._collect(function(r) report = r end)

    MiniTest.expect.equality(#seen.structural_calls, 3)
    for _, call in ipairs(seen.structural_calls) do
        MiniTest.expect.equality(call.query, nil)
    end
    MiniTest.expect.equality(#report.structure.routes, 1)
    MiniTest.expect.equality(report.overview.file_count, 67)
    MiniTest.expect.equality(report.codanna_health.symbol_count, 9)
    MiniTest.expect.equality(#report.errors, 0)
    MiniTest.expect.equality(type(report.root_path), "string")
end

T["collect"]["per-source failures land in errors without aborting"] = function()
    stub_collect({ structural_err = "vera-ai: structural blew up", codanna_err = "codanna: missing" })

    local report
    orient._collect(function(r) report = r end)

    MiniTest.expect.equality(#report.errors, 4)
    MiniTest.expect.equality(report.overview.file_count, 67)
    MiniTest.expect.equality(report.codanna_health, nil)
end

T["show"] = MiniTest.new_set({
    hooks = { pre_case = pre_case, post_case = restore_all },
})

T["show"]["groups decide tree vs warning"] = function()
    stub_show()

    -- Total failure notifies the collected errors and never opens the tree
    stub_collect({
        overview_err = "vera-ai binary not found",
        structural_err = "vera-ai binary not found",
        codanna_err = "codanna binary not found",
    })
    orient.show()

    MiniTest.expect.equality(seen.shown, nil)
    MiniTest.expect.equality(seen.notify_level, vim.log.levels.WARN)
    expect_contains(seen.notify_msg, "vera-ai binary not found")
    expect_contains(seen.notify_msg, "codanna binary not found")

    -- Partial failure still opens the tree and warns once; the orient tree
    -- intentionally has no re-root hook
    seen = {}
    stub_show()
    stub_collect({ structural_err = "vera-ai: no index" })
    orient.show()

    MiniTest.expect.equality(type(seen.shown), "table")
    MiniTest.expect.equality(seen.shown.opts.on_reroot, nil)
    MiniTest.expect.equality(seen.notify_level, vim.log.levels.WARN)
    expect_contains(seen.notify_msg, "no index")
end

T["cli parse"] = MiniTest.new_set({
    hooks = { pre_case = pre_case, post_case = restore_all },
})

T["cli parse"]["dispatches each verb with its args"] = function()
    local verb, args = cli.parse({ "seek", "retry", "logic" })
    MiniTest.expect.equality(verb, "seek")
    MiniTest.expect.equality(#args, 2)

    verb, args = cli.parse({ "related", "f.py", "3", "9" })
    MiniTest.expect.equality(verb, "related")
    MiniTest.expect.equality(args[2], "3")

    verb = cli.parse({ "callers", "setup" })
    MiniTest.expect.equality(verb, "callers")
    verb = cli.parse({ "orient" })
    MiniTest.expect.equality(verb, "orient")
    verb = cli.parse({ "status" })
    MiniTest.expect.equality(verb, "status")
end

T["cli parse"]["rejects unknown verbs and missing args"] = function()
    local verb, _, err = cli.parse({})
    MiniTest.expect.equality(verb, nil)
    expect_contains(err, "usage: sc")

    verb, _, err = cli.parse({ "frobnicate" })
    MiniTest.expect.equality(verb, nil)
    expect_contains(err, "unknown verb")

    verb, _, err = cli.parse({ "seek" })
    MiniTest.expect.equality(verb, nil)
    expect_contains(err, "query")

    verb, _, err = cli.parse({ "callers" })
    MiniTest.expect.equality(verb, nil)
    expect_contains(err, "symbol")

    verb, _, err = cli.parse({ "related", "f.py", "x", "9" })
    MiniTest.expect.equality(verb, nil)
    expect_contains(err, "numbers")
end

T["cli run"] = MiniTest.new_set({
    hooks = { pre_case = pre_case, post_case = restore_all },
})

T["cli run"]["seek joins argv into one query and returns hits"] = function()
    vera.search = function(query, opts, cb)
        seen.query = query
        seen.limit = opts.limit
        cb({ { file_path = "src/a.py", line_start = 2 } }, nil)
    end

    local result, err = cli.run({ "seek", "retry", "logic" })

    MiniTest.expect.equality(err, nil)
    MiniTest.expect.equality(seen.query, "retry logic")
    MiniTest.expect.equality(seen.limit, 20)
    MiniTest.expect.equality(result[1].file_path, "src/a.py")
end

T["cli run"]["substrate errors propagate as err"] = function()
    codanna.find_callers = function(_symbol, cb) cb(nil, "codanna: not found") end

    local result, err = cli.run({ "callers", "foo" })

    MiniTest.expect.equality(result, nil)
    expect_contains(err, "not found")
end

T["cli run"]["status reports per-tool health or error"] = function()
    codanna.index_health = function(cb) cb({ tool = "codanna", symbol_count = 5, healthy = true }, nil) end
    vera.index_health = function(cb) cb(nil, "vera-ai binary not found") end

    local result, err = cli.run({ "status" })

    MiniTest.expect.equality(err, nil)
    MiniTest.expect.equality(result.codanna.symbol_count, 5)
    MiniTest.expect.equality(result.vera.error, "vera-ai binary not found")
end

return T
