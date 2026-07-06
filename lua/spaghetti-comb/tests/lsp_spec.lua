-- LSP integration tests (child-process isolated)
local MiniTest = require("mini.test")

local child = MiniTest.new_child_neovim()

local child_preamble = [==[
  _G.lsp_integration = require("spaghetti-comb.navigation.lsp")
]==]

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            child.lua(child_preamble)
        end,
        post_once = child.stop,
    },
})

T["lsp"] = MiniTest.new_set()

T["lsp"]["setup initializes correctly"] = function()
    MiniTest.expect.no_error(
        function()
            child.lua([==[
          lsp_integration.setup({
            debug = { enabled = false },
            integration = { lsp = true },
          })
        ]==])
        end
    )
end

T["lsp"]["check_lsp_availability works"] = function()
    MiniTest.expect.equality(child.lua_get([==[type(lsp_integration.check_lsp_availability())]==]), "boolean")
end

T["lsp"]["get_context_at_position works"] = function()
    child.lua([==[
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
        "function test_function()",
        "    local x = 1",
        "    return x",
        "end",
      })
      _G.context = lsp_integration.get_context_at_position(buf, { 2, 5 })
    ]==])

    MiniTest.expect.equality(child.lua_get([==[type(_G.context)]==]), "table")
    MiniTest.expect.equality(child.lua_get([==[_G.context.current_line ~= nil]==]), true)
end

T["lsp"]["extract_function_name works"] = function()
    child.lua([==[
      _G.cases = {
        { "function myFunction()", "myFunction" },
        { "def test_method", "test_method" },
        { "fn calculate", "calculate" },
        { "local result = someCall()", "someCall" },
      }
      _G.results = {}
      for i, tc in ipairs(_G.cases) do
        _G.results[i] = lsp_integration.extract_function_name(tc[1])
      end
    ]==])

    MiniTest.expect.equality(
        child.lua_get([==[_G.results]==]),
        { "myFunction", "test_method", "calculate", "someCall" }
    )
end

T["lsp"]["lsp_result_to_locations handles single location"] = function()
    child.lua([==[
      _G.locations = lsp_integration.lsp_result_to_locations({
        uri = "file:///test.lua",
        range = {
          start = { line = 1, character = 0 },
          ["end"] = { line = 1, character = 10 },
        },
      })
    ]==])

    MiniTest.expect.equality(child.lua_get([==[#_G.locations]==]), 1)
    MiniTest.expect.equality(child.lua_get([==[_G.locations[1].uri]==]), "file:///test.lua")
end

T["lsp"]["lsp_result_to_locations handles array of locations"] = function()
    child.lua([==[
      _G.locations = lsp_integration.lsp_result_to_locations({
        {
          uri = "file:///test1.lua",
          range = { start = { line = 1, character = 0 }, ["end"] = { line = 1, character = 10 } },
        },
        {
          uri = "file:///test2.lua",
          range = { start = { line = 2, character = 0 }, ["end"] = { line = 2, character = 10 } },
        },
      })
    ]==])

    MiniTest.expect.equality(child.lua_get([==[#_G.locations]==]), 2)
    MiniTest.expect.equality(child.lua_get([==[_G.locations[1].uri]==]), "file:///test1.lua")
    MiniTest.expect.equality(child.lua_get([==[_G.locations[2].uri]==]), "file:///test2.lua")
end

return T
