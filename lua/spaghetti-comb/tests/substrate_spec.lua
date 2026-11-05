-- Substrate adapter tests (Vera + codanna): parsing, mapping, and error paths
local MiniTest = require("mini.test")
local helpers = MiniTest.new_set()
local vera = require("spaghetti-comb.substrate.vera")
local codanna = require("spaghetti-comb.substrate.codanna")

local function expect_contains(str, needle)
    MiniTest.expect.equality(type(str) == "string" and str:find(needle, 1, true) ~= nil, true)
end

-- Install an exec stub on the module. `responder` is either a result table
-- or a function(argv) -> result table; calls are recorded in `calls`.
local function stub_exec(module, responder, calls)
    module._exec = function(argv, callback)
        if calls then table.insert(calls, argv) end
        local result = type(responder) == "function" and responder(argv) or responder
        callback(result)
    end
end

local function json(value) return vim.json.encode(value) end

local VERA_HITS = {
    {
        file_path = "src/auth.py",
        line_start = 10,
        line_end = 30,
        content = "def authenticate(request):",
        symbol_name = "authenticate",
        symbol_type = "function",
    },
    {
        file_path = "src/middleware.ts",
        line_start = 1,
        line_end = 4,
        content = "import { Middleware }",
        symbol_type = "block",
    },
}

local CODANNA_CALLER = {
    id = 623198,
    name = "test_authenticate_request_wrong_scheme",
    kind = "Function",
    file_path = "mcp/tests/test_auth.py",
    range = { start_line = 100, start_column = 0, end_line = 104, end_column = 39 },
    signature = "() -> None",
    doc_comment = "checks the wrong scheme",
    call_line = 105,
    call_column = 8,
}

local function codanna_envelope(data)
    return json({ type = "result", status = "success", code = "OK", exit_code = 0, data = data })
end

local function codanna_error_envelope(status, exit_code, message, hint, data)
    return json({
        type = "error",
        status = status,
        code = "ERROR",
        exit_code = exit_code,
        message = message,
        hint = hint,
        data = data or vim.NIL,
    })
end

-- Arrange a codanna adapter that never touches the real plugin or binary.
local function use_fake_codanna()
    codanna.reset()
    codanna._core = { config = { codanna_path = "codanna" } }
    codanna._is_executable = function() return 1 end
end

-- Arrange a vera adapter that never touches the real binary.
local function use_fake_vera()
    vera.reset()
    vera._is_executable = function() return 1 end
end

helpers["substrate"] = MiniTest.new_set({}, {
    -- Vera search mapping
    ["vera search maps JSON array to SearchHit list"] = function()
        use_fake_vera()
        stub_exec(vera, { code = 0, stdout = json(VERA_HITS), stderr = "" })

        local hits, err
        vera.search("authentication", {}, function(h, e)
            hits = h
            err = e
        end)

        MiniTest.expect.equality(err, nil)
        MiniTest.expect.equality(#hits, 2)
        MiniTest.expect.equality(hits[1].file_path, "src/auth.py")
        MiniTest.expect.equality(hits[1].line_start, 10)
        MiniTest.expect.equality(hits[1].line_end, 30)
        MiniTest.expect.equality(hits[1].symbol_name, "authenticate")
        MiniTest.expect.equality(hits[1].symbol_type, "function")
        MiniTest.expect.equality(hits[1].source, "vera")
        MiniTest.expect.equality(hits[2].symbol_name, nil)
    end,

    ["vera search builds expected argv"] = function()
        use_fake_vera()
        local calls = {}
        stub_exec(vera, { code = 0, stdout = "[]", stderr = "" }, calls)

        vera.search("auth logic", { limit = 5 }, function() end)

        MiniTest.expect.equality(calls[1][1], "vera-ai")
        MiniTest.expect.equality(calls[1][2], "search")
        MiniTest.expect.equality(calls[1][4], "5")
        MiniTest.expect.equality(calls[1][#calls[1] - 1], "--")
        MiniTest.expect.equality(calls[1][#calls[1]], "auth logic")
    end,

    ["vera search returns error on non-zero exit"] = function()
        use_fake_vera()
        stub_exec(vera, { code = 1, stdout = "", stderr = "no index found" })

        local hits, err
        vera.search("x", {}, function(h, e)
            hits = h
            err = e
        end)

        MiniTest.expect.equality(hits, nil)
        expect_contains(err, "no index found")
    end,

    ["vera search returns error on invalid JSON"] = function()
        use_fake_vera()
        stub_exec(vera, { code = 0, stdout = "definitely not json", stderr = "" })

        local hits, err
        vera.search("x", {}, function(h, e)
            hits = h
            err = e
        end)

        MiniTest.expect.equality(hits, nil)
        expect_contains(err, "JSON")
    end,

    ["vera missing binary errors loudly"] = function()
        vera.reset()
        vera._is_executable = function() return 0 end

        local hits, err
        vera.search("x", {}, function(h, e)
            hits = h
            err = e
        end)

        MiniTest.expect.equality(hits, nil)
        expect_contains(err, "vera-ai binary not found")
    end,

    ["vera find_related reads range and queries with snippet"] = function()
        use_fake_vera()
        local file_path = vim.fn.tempname()
        vim.fn.writefile({ "alpha", "beta line", "gamma", "delta" }, file_path)
        local calls = {}
        stub_exec(vera, { code = 0, stdout = json(VERA_HITS), stderr = "" }, calls)

        local hits, err
        vera.find_related(file_path, 2, 3, {}, function(h, e)
            hits = h
            err = e
        end)

        MiniTest.expect.equality(err, nil)
        MiniTest.expect.equality(#hits, 2)
        MiniTest.expect.equality(calls[1][#calls[1]], "beta line\ngamma")
        os.remove(file_path)
    end,

    ["vera find_related errors on unreadable file"] = function()
        use_fake_vera()

        local hits, err
        vera.find_related("/nonexistent/path/file.lua", 1, 5, {}, function(h, e)
            hits = h
            err = e
        end)

        MiniTest.expect.equality(hits, nil)
        expect_contains(err, "cannot read")
    end,

    ["vera structural validates intents"] = function()
        use_fake_vera()
        stub_exec(vera, { code = 0, stdout = "[]", stderr = "" })

        local err1
        vera.structural("bogus", "q", function(_h, e) err1 = e end)
        expect_contains(err1, "unknown structural intent")

        local err2
        vera.structural("routes", "q", function(_h, e) err2 = e end)
        expect_contains(err2, "takes no query")

        local err3
        vera.structural("definitions", nil, function(_h, e) err3 = e end)
        expect_contains(err3, "requires a query")

        local err4
        vera.structural("sql", "q", function(_h, e) err4 = e end)
        expect_contains(err4, "takes no query")
    end,

    ["vera structural env runs with or without a query"] = function()
        use_fake_vera()
        local calls = {}
        stub_exec(vera, { code = 0, stdout = "[]", stderr = "" }, calls)

        local hits
        vera.structural("env", nil, function(h) hits = h end)
        MiniTest.expect.equality(calls[1][3], "env")
        MiniTest.expect.equality(calls[1][4], "--json")
        MiniTest.expect.equality(#hits, 0)

        vera.structural("env", "DATABASE_URL", function() end)
        MiniTest.expect.equality(calls[2][3], "env")
        MiniTest.expect.equality(calls[2][4], "DATABASE_URL")
    end,

    ["vera structural maps results to SearchHit list"] = function()
        use_fake_vera()
        local calls = {}
        stub_exec(vera, { code = 0, stdout = json(VERA_HITS), stderr = "" }, calls)

        local hits
        vera.structural("impls", "Loader", function(h) hits = h end)

        MiniTest.expect.equality(calls[1][2], "structural")
        MiniTest.expect.equality(calls[1][3], "impls")
        MiniTest.expect.equality(calls[1][4], "Loader")
        MiniTest.expect.equality(#hits, 2)
    end,

    ["vera overview returns parsed table"] = function()
        use_fake_vera()
        stub_exec(vera, { code = 0, stdout = json({ file_count = 42, chunk_count = 100 }), stderr = "" })

        local overview
        vera.overview(function(o) overview = o end)

        MiniTest.expect.equality(overview.file_count, 42)
    end,

    ["vera overview falls back to raw text"] = function()
        use_fake_vera()
        stub_exec(vera, { code = 0, stdout = "Project overview: 42 files", stderr = "" })

        local overview
        vera.overview(function(o) overview = o end)

        MiniTest.expect.equality(overview, "Project overview: 42 files")
    end,

    ["vera index_health parses doctor json"] = function()
        use_fake_vera()
        local doctor = {
            version = "2.3.1",
            overall_ok = true,
            checks = { { name = "version-check", status = "ok", detail = "up to date" } },
        }
        stub_exec(vera, { code = 0, stdout = json(doctor), stderr = "" })

        local health, err
        vera.index_health(function(h, e)
            health = h
            err = e
        end)

        MiniTest.expect.equality(err, nil)
        MiniTest.expect.equality(health.tool, "vera")
        MiniTest.expect.equality(health.healthy, true)
        expect_contains(health.message, "2.3.1")
    end,

    ["vera index_health reports failing checks"] = function()
        use_fake_vera()
        local doctor = {
            overall_ok = false,
            checks = { { name = "local-models", status = "fail", detail = "missing assets" } },
        }
        stub_exec(vera, { code = 1, stdout = json(doctor), stderr = "" })

        local health
        vera.index_health(function(h) health = h end)

        MiniTest.expect.equality(health.healthy, false)
        expect_contains(health.message, "local-models")
        expect_contains(health.message, "missing assets")
    end,

    -- codanna mapping
    ["codanna find_callers maps envelope data to RelationItem"] = function()
        use_fake_codanna()
        stub_exec(codanna, { code = 0, stdout = codanna_envelope({ CODANNA_CALLER }), stderr = "" })

        local items, err
        codanna.find_callers("authenticate_request", function(i, e)
            items = i
            err = e
        end)

        MiniTest.expect.equality(err, nil)
        MiniTest.expect.equality(#items, 1)
        local item = items[1]
        MiniTest.expect.equality(item.name, "test_authenticate_request_wrong_scheme")
        MiniTest.expect.equality(item.kind, "Function")
        MiniTest.expect.equality(item.file_path, "mcp/tests/test_auth.py")
        MiniTest.expect.equality(item.line, 105)
        MiniTest.expect.equality(item.signature, "() -> None")
        MiniTest.expect.equality(item.doc_comment, "checks the wrong scheme")
        MiniTest.expect.equality(item.direction, "callers")
        MiniTest.expect.equality(item.symbol_id, 623198)
    end,

    ["codanna get_calls uses range start line without call_line"] = function()
        use_fake_codanna()
        local callee = {
            id = 5,
            name = "helper",
            kind = "Function",
            file_path = "src/helper.lua",
            range = { start_line = 41, start_column = 0, end_line = 50, end_column = 3 },
        }
        stub_exec(codanna, { code = 0, stdout = codanna_envelope({ callee }), stderr = "" })

        local items
        codanna.get_calls("main", function(i) items = i end)

        MiniTest.expect.equality(items[1].line, 42)
        MiniTest.expect.equality(items[1].direction, "calls")
    end,

    ["codanna analyze_impact maps direction and depth"] = function()
        use_fake_codanna()
        local impacted = {
            id = 9,
            name = "downstream",
            kind = "Function",
            file_path = "src/down.py",
            range = { start_line = 9, start_column = 0, end_line = 15, end_column = 0 },
            depth = 2,
        }
        stub_exec(codanna, { code = 0, stdout = codanna_envelope({ impacted }), stderr = "" })

        local items
        codanna.analyze_impact("core_fn", function(i) items = i end)

        MiniTest.expect.equality(items[1].direction, "impact")
        MiniTest.expect.equality(items[1].depth, 2)
        MiniTest.expect.equality(items[1].line, 10)
    end,

    ["codanna search_symbols maps wrapped symbols to SearchHit"] = function()
        use_fake_codanna()
        local data = {
            {
                symbol = {
                    id = 43,
                    name = "parse_json_response",
                    kind = "Function",
                    file_path = "lua/codanna/utils.lua",
                    line = 147,
                    signature = "function M.parse_json_response(stdout)",
                },
                score = 18.62,
            },
        }
        stub_exec(codanna, { code = 0, stdout = codanna_envelope(data), stderr = "" })

        local hits
        codanna.search_symbols("parse", { limit = 3 }, function(h) hits = h end)

        MiniTest.expect.equality(#hits, 1)
        MiniTest.expect.equality(hits[1].symbol_name, "parse_json_response")
        MiniTest.expect.equality(hits[1].symbol_type, "Function")
        MiniTest.expect.equality(hits[1].line_start, 147)
        MiniTest.expect.equality(hits[1].content, "function M.parse_json_response(stdout)")
        MiniTest.expect.equality(hits[1].score, 18.62)
        MiniTest.expect.equality(hits[1].source, "codanna")
    end,

    ["codanna skips progress lines before the envelope"] = function()
        use_fake_codanna()
        local stdout = "Indexing directory: /proj\nProgress: [====] 100%\n" .. codanna_envelope({ CODANNA_CALLER })
        stub_exec(codanna, { code = 0, stdout = stdout, stderr = "" })

        local items, err
        codanna.find_callers("x", function(i, e)
            items = i
            err = e
        end)

        MiniTest.expect.equality(err, nil)
        MiniTest.expect.equality(#items, 1)
    end,

    ["codanna exit code 1 surfaces not found"] = function()
        use_fake_codanna()
        local stdout = codanna_error_envelope("not_found", 1, "Function 'foo' not found")
        stub_exec(codanna, { code = 1, stdout = stdout, stderr = "" })

        local items, err
        codanna.find_callers("foo", function(i, e)
            items = i
            err = e
        end)

        MiniTest.expect.equality(items, nil)
        expect_contains(err, "not found")
        expect_contains(err, "Function 'foo' not found")
    end,

    ["codanna exit code 7 surfaces index force hint"] = function()
        use_fake_codanna()
        local stdout = codanna_error_envelope("error", 7, "Index version mismatch")
        stub_exec(codanna, { code = 7, stdout = stdout, stderr = "" })

        local err
        codanna.get_calls("foo", function(_i, e) err = e end)

        expect_contains(err, "codanna index --force")
    end,

    ["codanna exit code 2 includes hint and candidates"] = function()
        use_fake_codanna()
        local stdout = codanna_error_envelope(
            "error",
            2,
            "Ambiguous: found 2 symbol(s)",
            "re-run with symbol_id:<id>",
            {
                { id = 221, name = "url_for", kind = "Function", file_path = "src/helpers.py", range = { start_line = 194 } },
                { id = 786, name = "url_for", kind = "Method", file_path = "src/app.py", range = { start_line = 1002 } },
            }
        )
        stub_exec(codanna, { code = 2, stdout = stdout, stderr = "" })

        local err
        codanna.find_callers("url_for", function(_i, e) err = e end)

        expect_contains(err, "Ambiguous")
        expect_contains(err, "symbol_id:221")
        expect_contains(err, "src/helpers.py:195")
        expect_contains(err, "symbol_id:786")
    end,

    ["codanna non-JSON output surfaces stderr"] = function()
        use_fake_codanna()
        stub_exec(codanna, { code = 1, stdout = "", stderr = "index corrupted" })

        local err
        codanna.find_callers("x", function(_i, e) err = e end)

        expect_contains(err, "index corrupted")
    end,

    ["codanna missing plugin errors loudly"] = function()
        -- codanna.nvim is not on the test runtimepath, so the require fails
        codanna.reset()

        local items, err
        codanna.find_callers("x", function(i, e)
            items = i
            err = e
        end)

        MiniTest.expect.equality(items, nil)
        expect_contains(err, "codanna.nvim")
    end,

    ["codanna missing binary errors loudly"] = function()
        use_fake_codanna()
        codanna._is_executable = function() return 0 end

        local err
        codanna.find_callers("x", function(_i, e) err = e end)

        expect_contains(err, "codanna binary not found")
    end,

    ["codanna index_health maps get_index_info"] = function()
        use_fake_codanna()
        local data = { symbol_count = 420, file_count = 16, relationship_count = 25 }
        stub_exec(codanna, { code = 0, stdout = codanna_envelope(data), stderr = "" })

        local health
        codanna.index_health(function(h) health = h end)

        MiniTest.expect.equality(health.tool, "codanna")
        MiniTest.expect.equality(health.indexed_files, 16)
        MiniTest.expect.equality(health.symbol_count, 420)
        MiniTest.expect.equality(health.edge_count, 25)
        MiniTest.expect.equality(health.healthy, true)
    end,
})

return helpers
