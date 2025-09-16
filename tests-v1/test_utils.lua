local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            child.lua([[Utils = require('spaghetti-comb-v1.utils')]])
        end,
        post_once = child.stop,
    },
})

T["get_buffer_language()"] = function()
    child.api.nvim_buf_set_option(0, "filetype", "typescript")
    local language = child.lua_get([[Utils.get_buffer_language()]])
    eq(language, "typescript")

    child.api.nvim_buf_set_option(0, "filetype", "javascript")
    language = child.lua_get([[Utils.get_buffer_language()]])
    eq(language, "javascript")

    child.api.nvim_buf_set_option(0, "filetype", "unknown")
    language = child.lua_get([[Utils.get_buffer_language()]])
    eq(language, "unknown")
end

T["normalize_path()"] = function()
    local result = child.lua_get([[Utils.normalize_path('/tmp/test.js')]])
    eq(result, "/tmp/test.js")

    result = child.lua_get([[Utils.normalize_path(nil)]])
    eq(result, vim.NIL)
end

T["is_valid_location()"] = function()
    local valid_location = {
        uri = "file:///tmp/test.js",
        range = {
            start = { line = 0, character = 0 },
            ["end"] = { line = 0, character = 10 },
        },
    }

    local result = child.lua_get([[Utils.is_valid_location(...)]], { valid_location })
    eq(result, true)

    result = child.lua_get([[Utils.is_valid_location({})]])
    eq(result, false)

    result = child.lua_get([[Utils.is_valid_location(nil)]])
    eq(result, false)
end

T["uri_to_path()"] = function()
    local result = child.lua_get([[Utils.uri_to_path('file:///tmp/test.js')]])
    eq(result, "/tmp/test.js")

    result = child.lua_get([[Utils.uri_to_path(nil)]])
    eq(result, vim.NIL)
end

T["path_to_uri()"] = function()
    local result = child.lua_get([[Utils.path_to_uri('/tmp/test.js')]])
    eq(result, "file:///tmp/test.js")

    result = child.lua_get([[Utils.path_to_uri(nil)]])
    eq(result, vim.NIL)
end

T["create_location_item()"] = function()
    local range = {
        start = { line = 0, character = 5 },
        ["end"] = { line = 0, character = 15 },
    }

    local location =
        child.lua_get([[Utils.create_location_item('file:///tmp/test.js', ..., 'test content')]], { range })

    expect.no_error(function()
        assert(location.uri == "file:///tmp/test.js", "URI should match")
        assert(location.path == "/tmp/test.js", "Path should be converted")
        assert(location.line == 1, "Line should be 1-indexed")
        assert(location.col == 6, "Column should be 1-indexed")
        assert(location.text == "test content", "Text should match")
        assert(location.type == "location", "Type should be location")
    end)
end

T["get_line_text()"] = function()
    child.bo.readonly = false
    child.api.nvim_buf_set_lines(0, 0, -1, true, { "first line", "second line", "third line" })

    local text = child.lua_get([[Utils.get_line_text(0, 1)]])
    eq(text, "second line")

    text = child.lua_get([[Utils.get_line_text(0, 0)]])
    eq(text, "first line")

    text = child.lua_get([[Utils.get_line_text(0, 10)]])
    eq(text, "")
end

return T
