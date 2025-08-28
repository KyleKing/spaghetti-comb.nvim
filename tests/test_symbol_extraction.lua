local MiniTest = require("mini.test")
local new_set = MiniTest.new_set

local T = new_set({
    hooks = {
        pre_case = function() vim.cmd("silent! %bwipeout!") end,
        post_case = function() vim.cmd("silent! %bwipeout!") end,
    },
})

local utils = require("spaghetti-comb.utils")

T["symbol_extraction"] = new_set()

local function create_test_buffer(content, filetype)
    local temp_file = vim.fn.tempname() .. "." .. filetype
    vim.cmd("edit " .. temp_file)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, content)
    vim.api.nvim_buf_set_option(0, "filetype", filetype)
    return vim.api.nvim_get_current_buf()
end

T["symbol_extraction"]["typescript function"] = function()
    local content = {
        "function calculateTotal(amount: number): number {",
        "    return amount * 1.2;",
        "}",
    }

    create_test_buffer(content, "typescript")
    vim.api.nvim_win_set_cursor(0, { 1, 10 })

    local symbol = utils.get_cursor_symbol()

    MiniTest.expect.equality(type(symbol), "table")
    MiniTest.expect.equality(symbol.language, "typescript")
    MiniTest.expect.equality(type(symbol.text), "string")
end

T["symbol_extraction"]["javascript class"] = function()
    local content = {
        "class Calculator {",
        "    add(a, b) {",
        "        return a + b;",
        "    }",
        "}",
    }

    create_test_buffer(content, "javascript")
    vim.api.nvim_win_set_cursor(0, { 1, 8 })

    local symbol = utils.get_cursor_symbol()

    MiniTest.expect.equality(type(symbol), "table")
    MiniTest.expect.equality(symbol.language, "javascript")
    MiniTest.expect.equality(type(symbol.text), "string")
end

T["symbol_extraction"]["python function"] = function()
    local content = {
        "def calculate_total(amount):",
        "    return amount * 1.2",
    }

    create_test_buffer(content, "python")
    vim.api.nvim_win_set_cursor(0, { 1, 8 })

    local symbol = utils.get_cursor_symbol()

    MiniTest.expect.equality(type(symbol), "table")
    MiniTest.expect.equality(symbol.language, "python")
    MiniTest.expect.equality(type(symbol.text), "string")
end

T["symbol_extraction"]["rust function"] = function()
    local content = {
        "fn calculate_total(amount: f64) -> f64 {",
        "    amount * 1.2",
        "}",
    }

    create_test_buffer(content, "rust")
    vim.api.nvim_win_set_cursor(0, { 1, 5 })

    local symbol = utils.get_cursor_symbol()

    MiniTest.expect.equality(type(symbol), "table")
    MiniTest.expect.equality(symbol.language, "rust")
    MiniTest.expect.equality(type(symbol.text), "string")
end

T["symbol_extraction"]["go function"] = function()
    local content = {
        "func calculateTotal(amount float64) float64 {",
        "    return amount * 1.2",
        "}",
    }

    create_test_buffer(content, "go")
    vim.api.nvim_win_set_cursor(0, { 1, 8 })

    local symbol = utils.get_cursor_symbol()

    MiniTest.expect.equality(type(symbol), "table")
    MiniTest.expect.equality(symbol.language, "go")
    MiniTest.expect.equality(type(symbol.text), "string")
end

T["symbol_extraction"]["classify_symbol_type typescript"] = function()
    local mock_node = {
        type = function() return "function_declaration" end,
    }

    local symbol_type = utils.classify_symbol_type(mock_node, "typescript")
    MiniTest.expect.equality(symbol_type, "function")
end

T["symbol_extraction"]["classify_symbol_type python"] = function()
    local mock_node = {
        type = function() return "function_definition" end,
    }

    local symbol_type = utils.classify_symbol_type(mock_node, "python")
    MiniTest.expect.equality(symbol_type, "function")
end

T["symbol_extraction"]["extract_symbol_info typescript"] = function()
    local symbol_data = {
        text = "calculateTotal",
        type = "function",
        language = "typescript",
        bufnr = vim.api.nvim_get_current_buf(),
        line = 0,
        col = 0,
        context = {},
        node = {
            type = function() return "function_declaration" end,
        },
    }

    local info = utils.extract_symbol_info(symbol_data, "typescript")

    MiniTest.expect.equality(type(info), "table")
    MiniTest.expect.equality(info.symbol, "calculateTotal")
    MiniTest.expect.equality(info.type, "function")
    MiniTest.expect.equality(info.language, "typescript")
end

T["symbol_extraction"]["get_word_under_cursor fallback"] = function()
    local content = { "hello world test" }
    create_test_buffer(content, "text")
    vim.api.nvim_win_set_cursor(0, { 1, 8 })

    local word = utils.get_word_under_cursor()

    MiniTest.expect.equality(type(word), "table")
    MiniTest.expect.equality(word.text, "world")
    MiniTest.expect.equality(word.type, "identifier")
end

T["symbol_extraction"]["get_buffer_language"] = function()
    create_test_buffer({ "test content" }, "typescript")

    local language = utils.get_buffer_language()
    MiniTest.expect.equality(language, "typescript")
end

return T
