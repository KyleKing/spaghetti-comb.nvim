-- Relations commands and relations-tree tests; the codanna adapter is stubbed
-- so no real codanna.nvim or binary is needed.
local MiniTest = require("mini.test")
local commands = require("spaghetti-comb.navigation.commands")
local relations = require("spaghetti-comb.navigation.relations")
local history_manager = require("spaghetti-comb.history.manager")
local codanna = require("spaghetti-comb.substrate.codanna")
local vera = require("spaghetti-comb.substrate.vera")
local relations_tree = require("spaghetti-comb.ui.relations_tree")

local T = MiniTest.new_set()
local seen = {}

local originals = {
    find_callers = codanna.find_callers,
    get_calls = codanna.get_calls,
    analyze_impact = codanna.analyze_impact,
    search_symbols = codanna.search_symbols,
    codanna_health = codanna.index_health,
    vera_health = vera.index_health,
    show = relations_tree.show,
    notify = vim.notify,
}

local function expect_contains(str, needle)
    MiniTest.expect.equality(type(str) == "string" and str:find(needle, 1, true) ~= nil, true)
end

local function restore_all()
    codanna.find_callers = originals.find_callers
    codanna.get_calls = originals.get_calls
    codanna.analyze_impact = originals.analyze_impact
    codanna.search_symbols = originals.search_symbols
    codanna.index_health = originals.codanna_health
    vera.index_health = originals.vera_health
    relations_tree.show = originals.show
    vim.notify = originals.notify
end

local function stub_notify()
    vim.notify = function(msg, level)
        seen.notify_msg = msg
        seen.notify_level = level
    end
end

local function stub_show()
    relations_tree.show = function(root, groups, opts)
        seen.shown = { root = root, groups = groups, opts = opts }
        return true, "shown"
    end
end

-- Point the current buffer's <cword> at a word (or whitespace when col sits
-- between words) so _resolve_symbol exercises the real cursor path.
local function set_cursor_on(lines, row, col)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, { row, col })
end

local function pre_case()
    seen = {}
    stub_notify()
    history_manager.reset()
    history_manager.setup({})
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })
end

T["symbol resolution"] = MiniTest.new_set({
    hooks = { pre_case = pre_case, post_case = restore_all },
})

T["symbol resolution"]["explicit arg beats the cursor word"] = function()
    set_cursor_on({ "local helper = 1" }, 1, 7)

    MiniTest.expect.equality(relations._resolve_symbol("explicit_sym"), "explicit_sym")
    MiniTest.expect.equality(relations._resolve_symbol(nil), "helper")
    MiniTest.expect.equality(relations._resolve_symbol(""), "helper")
end

T["symbol resolution"]["whitespace under cursor resolves to nil"] = function()
    set_cursor_on({ "     " }, 1, 0)

    MiniTest.expect.equality(relations._resolve_symbol(nil), nil)
end

T["queries"] = MiniTest.new_set({
    hooks = { pre_case = pre_case, post_case = restore_all },
})

T["queries"]["callers resolves cursor word and opens the tree"] = function()
    stub_show()
    local item = {
        name = "login_handler",
        kind = "Function",
        file_path = "src/session.py",
        line = 44,
        direction = "callers",
    }
    codanna.find_callers = function(symbol, cb)
        seen.symbol = symbol
        cb({ item }, nil)
    end
    codanna.search_symbols = function(query, opts, cb)
        seen.search_query = query
        seen.search_limit = opts.limit
        cb({
            {
                symbol_name = "helper",
                symbol_type = "Function",
                file_path = "src/helper.py",
                line_start = 9,
            },
        }, nil)
    end
    set_cursor_on({ "local helper = 1" }, 1, 7)

    local cb_items, cb_err
    relations.callers(nil, function(items, err)
        cb_items = items
        cb_err = err
    end)

    MiniTest.expect.equality(seen.symbol, "helper")
    MiniTest.expect.equality(seen.search_query, "helper")
    MiniTest.expect.equality(seen.search_limit, 1)
    MiniTest.expect.equality(cb_err, nil)
    MiniTest.expect.equality(#cb_items, 1)

    local shown = seen.shown
    MiniTest.expect.equality(shown.root.name, "helper")
    MiniTest.expect.equality(shown.root.kind, "Function")
    MiniTest.expect.equality(shown.root.file_path, "src/helper.py")
    MiniTest.expect.equality(shown.root.line, 9)
    MiniTest.expect.equality(shown.groups[1].label, "Callers")
    MiniTest.expect.equality(shown.groups[1].items[1].name, "login_handler")
    expect_contains(shown.opts.title, "Callers")
end

T["queries"]["calls and impact reach the matching adapter fns"] = function()
    stub_show()
    codanna.get_calls = function(symbol, cb)
        seen.calls_arg = symbol
        cb({ { name = "callee", file_path = "src/c.lua", line = 3, direction = "calls" } }, nil)
    end
    codanna.analyze_impact = function(symbol, cb)
        seen.impact_arg = symbol
        cb({ { name = "downstream", file_path = "src/d.lua", line = 5, direction = "impact", depth = 1 } }, nil)
    end

    local impacts = {}
    for _ = 1, 2 do
        relations.calls("target_calls")
        relations.impact("target_impact", function(items) table.insert(impacts, items) end)
    end

    MiniTest.expect.equality(seen.calls_arg, "target_calls")
    MiniTest.expect.equality(seen.impact_arg, "target_impact")
    MiniTest.expect.equality(#impacts, 2)
end

T["queries"]["missing symbol notifies and never calls the adapter"] = function()
    codanna.find_callers = function() seen.called = true end
    set_cursor_on({ "     " }, 1, 0)

    local cb_err
    relations.callers(nil, function(_items, err) cb_err = err end)

    MiniTest.expect.equality(seen.called, nil)
    MiniTest.expect.equality(seen.notify_level, vim.log.levels.WARN)
    expect_contains(seen.notify_msg, "no symbol under cursor")
    MiniTest.expect.equality(type(cb_err), "string")
end

T["queries"]["adapter errors surface via WARN notify and the callback"] = function()
    stub_show()
    codanna.find_callers = function(_symbol, cb) cb(nil, "codanna: not found — Function 'x' not found") end

    local cb_err
    relations.callers("x", function(_items, err) cb_err = err end)

    MiniTest.expect.equality(seen.shown, nil)
    MiniTest.expect.equality(seen.notify_level, vim.log.levels.WARN)
    expect_contains(seen.notify_msg, "Function 'x' not found")
    expect_contains(cb_err, "not found")
end

T["queries"]["empty results notify at INFO and skip the tree"] = function()
    stub_show()
    codanna.find_callers = function(_symbol, cb) cb({}, nil) end

    local cb_items
    relations.callers("lonely", function(items) cb_items = items end)

    MiniTest.expect.equality(seen.shown, nil)
    MiniTest.expect.equality(seen.notify_level, vim.log.levels.INFO)
    expect_contains(seen.notify_msg, "no callers")
    MiniTest.expect.equality(#cb_items, 0)
end

T["grouping"] = MiniTest.new_set({
    hooks = { pre_case = pre_case, post_case = restore_all },
})

T["grouping"]["callers form a single labeled group"] = function()
    local groups = relations._group_items("callers", {
        { name = "a", file_path = "a.py", line = 1, direction = "callers" },
        { name = "b", file_path = "b.py", line = 2, direction = "callers" },
    })

    MiniTest.expect.equality(#groups, 1)
    MiniTest.expect.equality(groups[1].label, "Callers")
    MiniTest.expect.equality(#groups[1].items, 2)
end

T["grouping"]["impact buckets items into sorted depth rings"] = function()
    local groups = relations._group_items("impact", {
        { name = "far", file_path = "f.py", line = 1, direction = "impact", depth = 2 },
        { name = "base", file_path = "b.py", line = 1, direction = "impact" },
        { name = "mid_b", file_path = "mb.py", line = 1, direction = "impact", depth = 1 },
        { name = "mid_a", file_path = "ma.py", line = 1, direction = "impact", depth = 1 },
    })

    MiniTest.expect.equality(#groups, 3)
    MiniTest.expect.equality(groups[1].label, "Impact")
    MiniTest.expect.equality(groups[1].items[1].name, "base")
    MiniTest.expect.equality(groups[2].label, "Depth 1")
    MiniTest.expect.equality(#groups[2].items, 2)
    MiniTest.expect.equality(groups[3].label, "Depth 2")
    MiniTest.expect.equality(groups[3].items[1].name, "far")
end

T["tree rows"] = MiniTest.new_set({
    hooks = { pre_case = pre_case, post_case = restore_all },
})

T["tree rows"]["build_rows renders root, group headers, and items"] = function()
    local rows = relations_tree._build_rows(
        { name = "authenticate", kind = "Function", file_path = "src/auth.py", line = 10 },
        {
            {
                label = "Callers",
                items = {
                    {
                        name = "login_handler",
                        kind = "Function",
                        file_path = "src/session.py",
                        line = 44,
                        direction = "callers",
                    },
                    {
                        name = "test_auth",
                        file_path = "tests/test_auth.py",
                        line = 5,
                        direction = "callers",
                    },
                },
            },
        }
    )

    MiniTest.expect.equality(#rows, 4)
    MiniTest.expect.equality(rows[1].row_type, "root")
    expect_contains(rows[1].text, "◆ authenticate")
    expect_contains(rows[1].text, "(Function)")
    expect_contains(rows[1].text, "auth.py:10")
    MiniTest.expect.equality(rows[1].item and rows[1].item.line, 10)

    MiniTest.expect.equality(rows[2].row_type, "group")
    expect_contains(rows[2].text, "Callers (2)")
    MiniTest.expect.equality(rows[2].item, nil)

    MiniTest.expect.equality(rows[3].row_type, "item")
    expect_contains(rows[3].text, "├─ login_handler")
    expect_contains(rows[3].text, "session.py:44")
    expect_contains(rows[4].text, "└─ test_auth")
end

T["tree rows"]["root without a file is not jumpable"] = function()
    local rows = relations_tree._build_rows({ name = "bare" }, {})

    MiniTest.expect.equality(#rows, 1)
    MiniTest.expect.equality(rows[1].item, nil)
    MiniTest.expect.equality(rows[1].text, "◆ bare")
end

T["jump recording"] = MiniTest.new_set({
    hooks = { pre_case = pre_case, post_case = restore_all },
})

T["jump recording"]["jump_to_item records a codanna_* trail entry"] = function()
    local path = vim.fn.tempname() .. ".py"
    vim.fn.writefile({ "def helper():", "    return 42", "", "def other():", "    pass" }, path)
    vim.cmd("enew!")

    relations.jump_to_item({ name = "helper", file_path = path, line = 2, direction = "callers" }, "codanna_callers")

    MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0)[1], 2)

    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(type(trail), "table")
    MiniTest.expect.equality(#trail.entries, 1)
    MiniTest.expect.equality(trail.entries[1].jump_type, "codanna_callers")
    MiniTest.expect.equality(trail.entries[1].file_path, path)
    MiniTest.expect.equality(trail.entries[1].context.function_name, "helper")

    local bufnr = vim.fn.bufnr(path)
    if bufnr ~= -1 then vim.api.nvim_buf_delete(bufnr, { force = true }) end
    vim.fn.delete(path)
end

T["re-root"] = MiniTest.new_set({
    hooks = { pre_case = pre_case, post_case = restore_all },
})

T["re-root"]["re-roots by symbol_id and skips root resolution"] = function()
    stub_show()
    codanna.find_callers = function(symbol, cb)
        seen.symbol = symbol
        cb({ { name = "deeper", file_path = "src/deep.py", line = 3, direction = "callers" } }, nil)
    end
    codanna.search_symbols = function() seen.search_called = true end

    relations._reroot({
        name = "deep_fn",
        kind = "Function",
        file_path = "src/deep.py",
        line = 7,
        direction = "callers",
        symbol_id = 42,
    }, "callers")

    MiniTest.expect.equality(seen.symbol, "symbol_id:42")
    MiniTest.expect.equality(seen.search_called, nil)
    MiniTest.expect.equality(seen.shown.root.name, "deep_fn")
    MiniTest.expect.equality(seen.shown.root.file_path, "src/deep.py")
    MiniTest.expect.equality(seen.shown.root.line, 7)
end

T["re-root"]["falls back to the item name without symbol_id"] = function()
    stub_show()
    codanna.get_calls = function(symbol, cb)
        seen.symbol = symbol
        cb({ { name = "leaf", file_path = "src/leaf.py", line = 1, direction = "calls" } }, nil)
    end

    relations._reroot({ name = "plain_fn", file_path = "src/plain.py", line = 2, direction = "calls" }, "calls")

    MiniTest.expect.equality(seen.symbol, "plain_fn")
    MiniTest.expect.equality(seen.shown.groups[1].label, "Calls")
end

T["tree interaction"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            pre_case()
            relations_tree.setup({})
        end,
        post_case = function()
            relations_tree.reset()
            restore_all()
        end,
    },
})

local RELATIONS_GROUPS = {
    {
        label = "Callers",
        items = {
            { name = "alpha", kind = "Function", file_path = "src/a.py", line = 1, direction = "callers" },
            { name = "beta", kind = "Function", file_path = "src/b.py", line = 2, direction = "callers" },
        },
    },
}

T["tree interaction"]["show renders rows and selects the first item"] = function()
    local ok = relations_tree.show({ name = "root_fn" }, RELATIONS_GROUPS, { title = " Callers " })

    MiniTest.expect.equality(ok, true)
    MiniTest.expect.equality(relations_tree.is_visible(), true)

    local st = relations_tree.get_state()
    MiniTest.expect.equality(#st.rows, 4)
    MiniTest.expect.equality(st.selected_index, 3)

    local lines = vim.api.nvim_buf_get_lines(st.buffer, 0, -1, false)
    MiniTest.expect.equality(#lines, 4)
    expect_contains(lines[1], "root_fn")
end

T["tree interaction"]["motion clamps, CR jumps, C-] re-roots"] = function()
    local jumps, reroots = {}, {}
    relations_tree.show({ name = "root_fn" }, RELATIONS_GROUPS, {
        on_jump = function(item) table.insert(jumps, item) end,
        on_reroot = function(item) table.insert(reroots, item) end,
    })
    local st = relations_tree.get_state()

    relations_tree._move_selection(-10)
    MiniTest.expect.equality(st.selected_index, 1)
    relations_tree._move_selection(10)
    MiniTest.expect.equality(st.selected_index, 4)

    relations_tree._reroot_selected()
    MiniTest.expect.equality(reroots[1].name, "beta")
    MiniTest.expect.equality(relations_tree.is_visible(), true)

    relations_tree._move_selection(-1)
    relations_tree._jump_to_selected()
    MiniTest.expect.equality(jumps[1].name, "alpha")
    MiniTest.expect.equality(relations_tree.is_visible(), false)
end

T["status"] = MiniTest.new_set({
    hooks = { pre_case = pre_case, post_case = restore_all },
})

T["status"]["aggregates branch status and both substrate healths"] = function()
    codanna.index_health = function(cb)
        cb({
            tool = "codanna",
            healthy = true,
            symbol_count = 420,
            edge_count = 25,
            indexed_files = 16,
        }, nil)
    end
    vera.index_health = function(cb)
        cb({ tool = "vera", healthy = true, message = "vera v2.3.1 checks passed", index_age_seconds = 7200 }, nil)
    end

    commands.status()

    expect_contains(seen.notify_msg, "No active navigation")
    expect_contains(seen.notify_msg, "codanna index: ok")
    expect_contains(seen.notify_msg, "420 symbols")
    expect_contains(seen.notify_msg, "25 edges")
    expect_contains(seen.notify_msg, "16 files")
    expect_contains(seen.notify_msg, "vera index: ok")
    expect_contains(seen.notify_msg, "index age 2h")
    expect_contains(seen.notify_msg, "vera v2.3.1")
end

T["status"]["health errors pass the adapter message through"] = function()
    codanna.index_health = function(cb) cb(nil, "codanna binary not found at 'codanna'") end
    vera.index_health = function(cb) cb({ tool = "vera", healthy = false, message = "index missing" }, nil) end

    commands.status()

    expect_contains(seen.notify_msg, "codanna binary not found")
    expect_contains(seen.notify_msg, "vera index: unhealthy")
    expect_contains(seen.notify_msg, "index missing")
end

T["status"]["formats counts and duration"] = function()
    MiniTest.expect.equality(
        commands._format_index_health(
            "codanna",
            { healthy = true, symbol_count = 5, edge_count = 3, indexed_files = 2, index_age_seconds = 90 }
        ),
        "codanna index: ok — 5 symbols, 3 edges, 2 files, index age 1m"
    )
    MiniTest.expect.equality(commands._format_index_health("vera", nil, "vera-ai: boom"), "vera-ai: boom")
end

return T
