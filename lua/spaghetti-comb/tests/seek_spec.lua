-- Seek/Related commands and content-addressed trail search tests
local MiniTest = require("mini.test")
local commands = require("spaghetti-comb.navigation.commands")
local history_manager = require("spaghetti-comb.history.manager")
local picker = require("spaghetti-comb.ui.picker")
local vera = require("spaghetti-comb.substrate.vera")

local T = MiniTest.new_set()
local seen = {}

local originals = {
    seek = vera.search,
    find_related = vera.find_related,
    show_search_hits = picker.show_search_hits,
    ui_input = vim.ui.input,
    notify = vim.notify,
}

local function expect_contains(str, needle)
    MiniTest.expect.equality(type(str) == "string" and str:find(needle, 1, true) ~= nil, true)
end

local function make_entry(overrides)
    return vim.tbl_deep_extend("force", {
        file_path = "/proj/src/auth.py",
        position = { line = 10, column = 1 },
        jump_type = "lsp_definition",
        timestamp = os.time(),
        branch_id = "branch-42",
        context = {},
    }, overrides or {})
end

local function restore_all()
    vera.search = originals.seek
    vera.find_related = originals.find_related
    picker.show_search_hits = originals.show_search_hits
    vim.ui.input = originals.ui_input
    vim.notify = originals.notify
end

local function stub_shown()
    picker.show_search_hits = function(hits, opts)
        seen.shown = { hits = hits, opts = opts }
        return true, "shown"
    end
end

T["trail search"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            seen = {}
            history_manager.reset()
            history_manager.setup({})
        end,
        post_case = restore_all,
    },
})

T["trail search"]["search text covers path, branch, function, and snippet lines"] = function()
    local entry = make_entry({
        context = {
            function_name = "authenticate",
            before_lines = { "def login(request):", "    user = parse(request)" },
            after_lines = { "    return issue_token(user)" },
        },
    })

    local text = picker._build_search_text(entry)

    expect_contains(text, "auth.py")
    expect_contains(text, "branch-42")
    expect_contains(text, "authenticate")
    expect_contains(text, "user = parse(request)")
    expect_contains(text, "return issue_token(user)")
end

T["trail search"]["navigation item carries display text plus search_text"] = function()
    local item = picker._format_navigation_item(make_entry({
        context = { function_name = "hidden_function" },
    }))

    MiniTest.expect.equality(type(item.text), "string")
    MiniTest.expect.equality(item.text:find("hidden_function", 1, true), nil)
    expect_contains(item.search_text, "hidden_function")
end

T["trail search"]["filter_navigation_entries matches beyond filename"] = function()
    local entries = {
        make_entry({ file_path = "/proj/src/alpha.py", context = { function_name = "retry_loop" } }),
        make_entry({ file_path = "/proj/src/beta.py" }),
    }

    local by_name = picker.filter_navigation_entries(entries, "alpha")
    MiniTest.expect.equality(#by_name, 1)

    local by_function = picker.filter_navigation_entries(entries, "retry_loop")
    MiniTest.expect.equality(#by_function, 1)
    MiniTest.expect.equality(by_function[1].file_path, "/proj/src/alpha.py")
end

T["trail search"]["matcher filters via search text not display text"] = function()
    local items = {
        picker._format_navigation_item(make_entry({ context = { function_name = "authenticate" } })),
        picker._format_navigation_item(make_entry({ file_path = "/proj/src/beta.py" })),
    }
    local search_ctx = { stritems = {}, stritems_lower = {} }
    for i, item in ipairs(items) do
        search_ctx.stritems[i] = item.search_text
        search_ctx.stritems_lower[i] = item.search_text:lower()
    end

    local match = picker._make_search_matcher(search_ctx)

    -- Forced-exact query (' prefix) for a token only present in search_text
    local inds = match({}, { 1, 2 }, { "'", "a", "u", "t", "h", "e", "n" })
    MiniTest.expect.equality(inds, { 1 })
end

T["search hit picker"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            seen = {}
            history_manager.reset()
            history_manager.setup({})
        end,
        post_case = restore_all,
    },
})

T["search hit picker"]["formats hits with location, symbol, and searchable content"] = function()
    local item = picker._format_hit_item({
        file_path = "src/auth.py",
        line_start = 10,
        symbol_name = "authenticate",
        content = "def authenticate(request):",
    })

    MiniTest.expect.equality(item.text, "src/auth.py:10 — authenticate")
    expect_contains(item.search_text, "def authenticate(request):")
    MiniTest.expect.equality(item.hit.line_start, 10)
end

T["search hit picker"]["formats hits without a symbol name"] = function()
    local item = picker._format_hit_item({ file_path = "src/util.py", line_start = 3 })

    MiniTest.expect.equality(item.text, "src/util.py:3")
end

T["search hit picker"]["resolves index-relative paths against project root"] = function()
    MiniTest.expect.equality(picker._resolve_hit_path("/abs/file.py"), "/abs/file.py")

    local resolved = picker._resolve_hit_path("src/auth.py")
    MiniTest.expect.equality(resolved:sub(-11), "src/auth.py")
    MiniTest.expect.equality(resolved:sub(1, 1) == "/" or resolved:match("^%a:") ~= nil, true)
end

T["search hit picker"]["jump_to_hit jumps and records a trail entry"] = function()
    local path = vim.fn.tempname() .. ".py"
    vim.fn.writefile({ "def helper():", "    return 42" }, path)

    picker.jump_to_hit({ file_path = path, line_start = 2, symbol_name = "helper" }, "vera_seek")

    MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0)[1], 2)

    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(type(trail), "table")
    MiniTest.expect.equality(#trail.entries, 1)
    MiniTest.expect.equality(trail.entries[1].jump_type, "vera_seek")
    MiniTest.expect.equality(trail.entries[1].file_path, path)
    MiniTest.expect.equality(trail.entries[1].position.line, 2)
    MiniTest.expect.equality(trail.entries[1].context.function_name, "helper")

    local bufnr = vim.fn.bufnr(path)
    if bufnr ~= -1 then vim.api.nvim_buf_delete(bufnr, { force = true }) end
    vim.fn.delete(path)
end

T["seek command"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            seen = {}
            history_manager.reset()
            history_manager.setup({})
        end,
        post_case = restore_all,
    },
})

T["seek command"]["explicit query searches vera and forwards hits"] = function()
    stub_shown()
    vera.search = function(query, opts, cb)
        seen.query = query
        seen.limit = opts and opts.limit
        cb({ { file_path = "src/auth.py", line_start = 10 } }, nil)
    end

    commands.seek("retry logic")

    MiniTest.expect.equality(seen.query, "retry logic")
    MiniTest.expect.equality(seen.limit, 20)
    MiniTest.expect.equality(#seen.shown.hits, 1)
    MiniTest.expect.equality(seen.shown.opts.jump_type, "vera_seek")
    expect_contains(seen.shown.opts.name, "retry logic")
end

T["seek command"]["empty arg prompts then searches typed query"] = function()
    stub_shown()
    vim.ui.input = function(opts, cb)
        seen.prompt = opts.prompt
        cb("typed query")
    end
    vera.search = function(query, _opts, cb)
        seen.query = query
        cb({}, nil)
    end

    commands.seek("")

    MiniTest.expect.equality(seen.query, "typed query")

    -- Cancelled input does not search
    seen.query = nil
    vim.ui.input = function(_opts, cb) cb(nil) end
    commands.seek()
    MiniTest.expect.equality(seen.query, nil)
end

T["seek command"]["substrate errors notify at WARN"] = function()
    vera.search = function(_q, _o, cb) cb(nil, "vera-ai: binary not found") end
    local level, msg
    vim.notify = function(m, l)
        msg = m
        level = l
    end

    commands.seek("anything")

    MiniTest.expect.equality(level, vim.log.levels.WARN)
    expect_contains(msg, "vera-ai")
end

T["seek command"]["find_related passes file range and records vera_related"] = function()
    stub_shown()
    vera.find_related = function(file_path, line_start, line_end, opts, cb)
        seen.range = { file_path, line_start, line_end }
        seen.limit = opts and opts.limit
        cb({ { file_path = "src/retry.py", line_start = 5 } }, nil)
    end

    commands.find_related("/proj/src/impl.py", 8, 14)

    MiniTest.expect.equality(seen.range[1], "/proj/src/impl.py")
    MiniTest.expect.equality(seen.range[2], 8)
    MiniTest.expect.equality(seen.range[3], 14)
    MiniTest.expect.equality(seen.limit, 20)
    MiniTest.expect.equality(seen.shown.opts.jump_type, "vera_related")
end

T["seek command"]["find_related without a file notifies and skips search"] = function()
    vera.find_related = function() seen.called = true end
    local level
    vim.notify = function(_m, l) level = l end

    commands.find_related("", 1, 5)

    MiniTest.expect.equality(seen.called, nil)
    MiniTest.expect.equality(level, vim.log.levels.WARN)
end

return T
