-- LSP integration tests
local MiniTest = require("mini.test")
local T = MiniTest.new_set()

-- Test LSP module initialization
T["lsp"] = MiniTest.new_set()

T["lsp"]["setup initializes correctly"] = function()
    local lsp_integration = require("spaghetti-comb.navigation.lsp")

    -- Test setup with default config
    lsp_integration.setup({
        debug = { enabled = false },
        integration = { lsp = true },
    })

    -- Should not error
    assert(true, "LSP integration setup completed without errors")
end

T["lsp"]["check_lsp_availability works"] = function()
    local lsp_integration = require("spaghetti-comb.navigation.lsp")

    -- Test LSP availability check
    local available = lsp_integration.check_lsp_availability()

    -- Should return a boolean
    assert(type(available) == "boolean", "check_lsp_availability should return boolean")
end

T["lsp"]["get_context_at_position works"] = function()
    local lsp_integration = require("spaghetti-comb.navigation.lsp")

    -- Create a test buffer
    local buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "function test_function()",
        "    local x = 1",
        "    return x",
        "end",
    })

    -- Test context extraction
    local context = lsp_integration.get_context_at_position(buf, { 2, 5 })

    -- Should return a table with context information
    assert(type(context) == "table", "get_context_at_position should return table")
    assert(context.current_line, "Should have current_line")
end

T["lsp"]["extract_function_name works"] = function()
    local lsp_integration = require("spaghetti-comb.navigation.lsp")

    -- Test various function patterns
    local test_cases = {
        { "function myFunction()", "myFunction" },
        { "def test_method", "test_method" },
        { "fn calculate", "calculate" },
        { "local result = someCall()", "someCall" },
    }

    for _, test_case in ipairs(test_cases) do
        local result = lsp_integration.extract_function_name(test_case[1])
        assert(result == test_case[2], "Should extract '" .. test_case[2] .. "' from '" .. test_case[1] .. "'")
    end
end

T["lsp"]["lsp_result_to_locations handles single location"] = function()
    local lsp_integration = require("spaghetti-comb.navigation.lsp")

    -- Test single location result
    local result = {
        uri = "file:///test.lua",
        range = {
            start = { line = 1, character = 0 },
            ["end"] = { line = 1, character = 10 },
        },
    }

    local locations = lsp_integration.lsp_result_to_locations(result)

    assert(#locations == 1, "Should return one location")
    assert(locations[1].uri == "file:///test.lua", "Should preserve URI")
end

T["lsp"]["lsp_result_to_locations handles array of locations"] = function()
    local lsp_integration = require("spaghetti-comb.navigation.lsp")

    -- Test array result
    local result = {
        {
            uri = "file:///test1.lua",
            range = { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 10 } },
        },
        {
            uri = "file:///test2.lua",
            range = { start = { line = 2, character = 0 }, ["end"] = { line = 2, character = 10 } },
        },
    }

    local locations = lsp_integration.lsp_result_to_locations(result)

    assert(#locations == 2, "Should return two locations")
    assert(locations[1].uri == "file:///test1.lua", "Should preserve first URI")
    assert(locations[2].uri == "file:///test2.lua", "Should preserve second URI")
end

return T
