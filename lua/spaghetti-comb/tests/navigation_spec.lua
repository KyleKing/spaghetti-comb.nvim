-- Navigation command tests
local MiniTest = require("mini.test")
local history_manager = require("spaghetti-comb.history.manager")
local bookmarks = require("spaghetti-comb.history.bookmarks")
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

T["navigation commands"]["go back and forward"] = function()
    record_sequential_jumps(3)

    local success = history_manager.go_back(1)
    MiniTest.expect.equality(success, true)
    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail.current_index, 2)

    success = history_manager.go_forward(1)
    MiniTest.expect.equality(success, true)
    trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail.current_index, 3)
end

T["navigation commands"]["jump to specific index"] = function()
    record_sequential_jumps(5)

    local success, entry = history_manager.navigate_to_index(3)
    MiniTest.expect.equality(success, true)
    MiniTest.expect.equality(entry.position.line, 4)

    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail.current_index, 3)
end

T["navigation commands"]["navigate_to_index rejects out of bounds"] = function()
    record_sequential_jumps(2)

    local success, err = history_manager.navigate_to_index(99)
    MiniTest.expect.equality(success, false)
    MiniTest.expect.equality(type(err), "string")
end

T["navigation commands"]["history clearing"] = function()
    local from_loc = { file_path = "/test/file1.lua", position = { line = 1, column = 1 } }
    local to_loc = { file_path = "/test/file2.lua", position = { line = 2, column = 2 } }
    history_manager.record_jump(from_loc, to_loc, "manual")

    local success = history_manager.clear_current_project_history()
    MiniTest.expect.equality(success, true)

    -- get_current_trail lazily recreates an empty trail for the project
    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 0)
end

T["navigation commands"]["project switching keeps trails isolated"] = function()
    history_manager.clear_all_history()

    history_manager.set_current_project("/test/project1")
    history_manager.record_jump(
        { file_path = "/test/project1/file.lua", position = { line = 1, column = 1 } },
        { file_path = "/test/project1/file2.lua", position = { line = 2, column = 2 } },
        "manual"
    )

    history_manager.set_current_project("/test/project2")
    history_manager.record_jump(
        { file_path = "/test/project2/file.lua", position = { line = 10, column = 10 } },
        { file_path = "/test/project2/file2.lua", position = { line = 20, column = 20 } },
        "manual"
    )

    local success = history_manager.switch_to_project("/test/project1")
    MiniTest.expect.equality(success, true)
    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 1)
    MiniTest.expect.equality(trail.entries[1].position.line, 2)

    success = history_manager.switch_to_project("/test/project2")
    MiniTest.expect.equality(success, true)
    trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 1)
    MiniTest.expect.equality(trail.entries[1].position.line, 20)
end

T["bookmarks"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            bookmarks.reset()
            bookmarks.setup({})
            bookmarks.clear_all_bookmarks(true)
            bookmarks.set_current_project("/test/project")
        end,
    },
})

T["bookmarks"]["add, query, and remove bookmark"] = function()
    local location = {
        file_path = "/test/bookmark.lua",
        position = { line = 42, column = 10 },
    }

    local success, action = bookmarks.add_bookmark(location, true)
    MiniTest.expect.equality(success, true)
    MiniTest.expect.equality(action, "added")

    local all_bookmarks = bookmarks.get_all_bookmarks()
    MiniTest.expect.equality(#all_bookmarks >= 1, true)
    MiniTest.expect.equality(all_bookmarks[1].is_manual, true)

    local is_bookmarked = bookmarks.is_bookmarked(location)
    MiniTest.expect.equality(is_bookmarked, true)

    success = bookmarks.remove_bookmark(location)
    MiniTest.expect.equality(success, true)

    is_bookmarked = bookmarks.is_bookmarked(location)
    MiniTest.expect.equality(is_bookmarked, false)
end

T["bookmarks"]["toggle adds then removes"] = function()
    local location = {
        file_path = "/test/toggle.lua",
        position = { line = 10, column = 1 },
    }

    local success, action = bookmarks.toggle_bookmark(location)
    MiniTest.expect.equality(success, true)
    MiniTest.expect.equality(action, "added")

    success, action = bookmarks.toggle_bookmark(location)
    MiniTest.expect.equality(success, true)
    MiniTest.expect.equality(action, "removed")
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

T["jumplist"]["get_jumplist_info returns structure"] = function()
    local info = jumplist.get_jumplist_info()
    MiniTest.expect.equality(type(info), "table")
    MiniTest.expect.equality(type(info.current_index), "number")
    MiniTest.expect.equality(type(info.total_entries), "number")
end

T["jumplist"]["check_jumplist_compatibility succeeds"] = function()
    MiniTest.expect.equality(jumplist.check_jumplist_compatibility(), true)
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

T["jumplist"]["navigate_to_entry moves cursor in real file"] = function()
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

    local bufnr = vim.fn.bufnr(tmp_path)
    if bufnr ~= -1 then vim.api.nvim_buf_delete(bufnr, { force = true }) end
    vim.fn.delete(tmp_path)
end

return T
