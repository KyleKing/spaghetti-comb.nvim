local MiniTest = require("mini.test")
local new_set = MiniTest.new_set

local T = new_set({
    hooks = {
        pre_case = function()
            vim.cmd("silent! %bwipeout!")
            local temp_file = vim.fn.tempname() .. ".lua"
            vim.cmd("edit " .. temp_file)

            local test_content = {
                "local function test_function()",
                "    local var = 'hello'",
                "    return var",
                "end",
                "",
                "local function another_function()",
                "    return test_function()",
                "end",
                "",
                "test_function()",
            }

            vim.api.nvim_buf_set_lines(0, 0, -1, false, test_content)
            vim.api.nvim_win_set_cursor(0, { 1, 15 })
        end,
        post_case = function() vim.cmd("silent! %bwipeout!") end,
    },
})

local analyzer = require("spaghetti-comb-v1.analyzer")
local utils = require("spaghetti-comb-v1.utils")

T["analyzer"] = new_set()

T["analyzer"]["get_lsp_clients"] = function()
    local clients = analyzer.get_lsp_clients and analyzer.get_lsp_clients()
    MiniTest.expect.no_error(
        function() assert(type(clients) == "table" or clients == nil, "get_lsp_clients should return table or nil") end
    )
end

T["analyzer"]["process_lsp_response"] = function()
    local mock_response = {
        {
            uri = "file:///test.lua",
            range = {
                start = { line = 0, character = 0 },
                ["end"] = { line = 0, character = 10 },
            },
        },
    }

    local result = analyzer.process_lsp_response("textDocument/references", mock_response)

    MiniTest.expect.equality(result.method, "textDocument/references")
    MiniTest.expect.equality(type(result.locations), "table")
    MiniTest.expect.equality(#result.locations, 1)
    MiniTest.expect.equality(result.locations[1].uri, "file:///test.lua")
end

T["analyzer"]["process_lsp_response with empty response"] = function()
    local result = analyzer.process_lsp_response("textDocument/references", nil)

    MiniTest.expect.equality(type(result), "table")
    MiniTest.expect.equality(result.method, "textDocument/references")
    MiniTest.expect.equality(type(result.locations), "table")
    MiniTest.expect.equality(#result.locations, 0)
end

T["analyzer"]["find_references_fallback"] = function()
    local symbol_text = "test_function"
    local results = analyzer.find_references_fallback(symbol_text)

    MiniTest.expect.equality(type(results), "table")
end

T["analyzer"]["find_definitions_treesitter"] = function()
    local bufnr = vim.api.nvim_get_current_buf()
    local symbol_text = "test_function"

    vim.api.nvim_buf_set_option(bufnr, "filetype", "lua")

    local results = analyzer.find_definitions_treesitter(symbol_text, bufnr)

    MiniTest.expect.equality(type(results), "table")
end

T["analyzer"]["find_references with callback"] = function()
    local symbol_info = utils.get_cursor_symbol()
    local callback_called = false
    local processed_data = nil

    analyzer.find_references_with_fallback(symbol_info, function(data)
        callback_called = true
        processed_data = data
    end)

    vim.wait(1000, function() return callback_called end)

    MiniTest.expect.equality(callback_called, true)
    MiniTest.expect.equality(type(processed_data), "table")
    MiniTest.expect.equality(type(processed_data.locations), "table")
end

T["analyzer"]["find_definitions with callback"] = function()
    local symbol_info = utils.get_cursor_symbol()
    local callback_called = false
    local processed_data = nil

    analyzer.find_definitions_with_fallback(symbol_info, function(data)
        callback_called = true
        processed_data = data
    end)

    vim.wait(1000, function() return callback_called end)

    MiniTest.expect.equality(callback_called, true)
    MiniTest.expect.equality(type(processed_data), "table")
    MiniTest.expect.equality(type(processed_data.locations), "table")
end

T["analyzer"]["analyze_current_symbol"] = function()
    MiniTest.expect.no_error(function() analyzer.analyze_current_symbol() end)
end

return T
