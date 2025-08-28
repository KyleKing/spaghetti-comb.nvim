local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            child.lua([[SpaghettiComb = require('spaghetti-comb')]])
        end,
        post_once = child.stop,
    },
})

T["setup()"] = new_set()

T["setup()"]["works with default config"] = function()
    child.lua([[SpaghettiComb.setup()]])
    local config = child.lua_get([[SpaghettiComb.get_config()]])

    expect.no_error(function()
        assert(config ~= nil, "Config should not be nil")
        assert(config.relations ~= nil, "Relations config should exist")
        assert(config.keymaps ~= nil, "Keymaps config should exist")
    end)
end

T["setup()"]["merges user config"] = function()
    child.lua([[SpaghettiComb.setup({ relations = { focus_height = 40 } })]])
    local config = child.lua_get([[SpaghettiComb.get_config()]])

    eq(config.relations.focus_height, 40)
    eq(config.relations.height, 15) -- default should be preserved
end

T["setup()"]["creates user commands"] = function()
    child.lua([[SpaghettiComb.setup()]])

    -- Check that commands are created
    local commands = child.lua_get([[vim.tbl_keys(vim.api.nvim_get_commands({}))]])

    local expected_commands = {
        "SpaghettiCombShow",
        "SpaghettiCombReferences",
        "SpaghettiCombDefinition",
        "SpaghettiCombNext",
        "SpaghettiCombPrev",
        "SpaghettiCombToggle",
        "SpaghettiCombSave",
        "SpaghettiCombLoad",
    }

    for _, cmd in ipairs(expected_commands) do
        expect.no_error(
            function() assert(vim.tbl_contains(commands, cmd), string.format("Command %s should exist", cmd)) end
        )
    end
end

T["get_state()"] = function()
    child.lua([[SpaghettiComb.setup()]])
    local state = child.lua_get([[SpaghettiComb.get_state()]])

    expect.no_error(function()
        assert(state ~= nil, "State should not be nil")
        assert(state.navigation_stack ~= nil, "Navigation stack should exist")
        assert(state.relations_window == nil, "Relations window should be nil initially")
        assert(state.active_session == nil, "Active session should be nil initially")
    end)
end

return T
