-- Navigation command tests
local MiniTest = require("mini.test")
local history_manager = require("spaghetti-comb.history.manager")
local commands = require("spaghetti-comb.navigation.commands")
local jumplist = require("spaghetti-comb.navigation.jumplist")

local T = MiniTest.new_set()

local function record_sequential_jumps(count)
    for i = 1, count do
        local from_loc = { file_path = "/test/file" .. i .. ".lua", position = { line = i, column = 1 } }
        local to_loc = { file_path = "/test/file" .. (i + 1) .. ".lua", position = { line = i + 1, column = 1 } }
        history_manager.record_jump(from_loc, to_loc, "manual")
    end
end

T["navigation commands"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            history_manager.reset()
            history_manager.setup({})
            history_manager.set_current_project("/test/project")
        end,
    },
})

T["navigation commands"]["command wrappers no-op before setup"] = function()
    -- Guarded by state.initialized; must be safe no-ops rather than error.
    -- Avoid commands.setup here because it registers global LSP autocmds.
    MiniTest.expect.no_error(function()
        commands.go_back()
        commands.go_forward()
        commands.jump_to_history_item(1)
    end)
end

T["navigation commands"]["navigate_to_index moves within bounds and rejects out of bounds"] = function()
    record_sequential_jumps(5)

    local success, entry = history_manager.navigate_to_index(3)
    MiniTest.expect.equality(success, true)
    MiniTest.expect.equality(entry.position.line, 4)

    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail.current_index, 3)

    success, entry = history_manager.navigate_to_index(99)
    MiniTest.expect.equality(success, false)
    MiniTest.expect.equality(type(entry), "string")
end

T["jumplist"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            history_manager.reset()
            history_manager.setup({})
            require("spaghetti-comb.utils.debug").setup({})
        end,
    },
})

T["jumplist"]["jump_to_index rejects invalid index"] = function()
    MiniTest.expect.no_error(function() jumplist.jump_to_index(0) end)
    MiniTest.expect.no_error(function() jumplist.jump_to_index("not a number") end)
end

T["jumplist"]["enhanced mode toggles"] = function()
    local initial = jumplist.is_enhanced_mode()
    MiniTest.expect.equality(type(initial), "boolean")

    local toggled = jumplist.toggle_enhanced_mode()
    MiniTest.expect.equality(toggled, not initial)

    jumplist.toggle_enhanced_mode()
    MiniTest.expect.equality(jumplist.is_enhanced_mode(), initial)
end

T["jumplist"]["navigate_to_entry returns false for unreadable file"] = function()
    local missing_path = vim.fn.tempname() .. "-does-not-exist.lua"
    local result = jumplist.navigate_to_entry({
        file_path = missing_path,
        position = { line = 1, column = 1 },
    })
    MiniTest.expect.equality(result, false)
end

T["jumplist"]["navigate_to_entry and jump_to_index move the cursor in a real file"] = function()
    local tmp_path = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "line one", "line two", "line three" }, tmp_path)

    local result = jumplist.navigate_to_entry({
        file_path = tmp_path,
        position = { line = 2, column = 3 },
    })
    MiniTest.expect.equality(result, true)

    local cursor = vim.api.nvim_win_get_cursor(0)
    MiniTest.expect.equality(cursor[1], 2)
    MiniTest.expect.equality(cursor[2], 2)

    -- jump_to_index resolves a recorded trail entry and lands on its position
    history_manager.record_jump(
        { file_path = tmp_path, position = { line = 2, column = 3 } },
        { file_path = tmp_path, position = { line = 3, column = 1 } },
        "manual"
    )
    jumplist.jump_to_index(1)
    MiniTest.expect.equality(vim.api.nvim_win_get_cursor(0)[1], 3)

    local bufnr = vim.fn.bufnr(tmp_path)
    if bufnr ~= -1 then vim.api.nvim_buf_delete(bufnr, { force = true }) end
    vim.fn.delete(tmp_path)
end

return T
