-- Navigation command tests
local MiniTest = require("mini.test")
local history_manager = require("spaghetti-comb.history.manager")
local bookmarks = require("spaghetti-comb.history.bookmarks")
local commands = require("spaghetti-comb.navigation.commands")

local T = MiniTest.new_set()

-- Test setup
T["navigation commands"] = MiniTest.new_set()

T["navigation commands"]["setup"] = function()
    -- Test basic setup
    local config = {}
    commands.setup(config)

    -- Should not error during setup
    MiniTest.expect.no_error(function() commands.setup(config) end)
end

T["navigation commands"]["go back and forward"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.clear_all_history()
    history_manager.set_current_project("/test/project")

    -- Create navigation history
    for i = 1, 3 do
        local from_loc = { file_path = "/test/file" .. i .. ".lua", position = { line = i, column = 1 } }
        local to_loc = { file_path = "/test/file" .. (i + 1) .. ".lua", position = { line = i + 1, column = 1 } }
        history_manager.record_jump(from_loc, to_loc, "manual")
    end

    -- Test go_back
    local success = history_manager.go_back(1)
    MiniTest.expect.equality(success, true)
    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail.current_index, 2)

    -- Test go_forward
    success = history_manager.go_forward(1)
    MiniTest.expect.equality(success, true)
    trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail.current_index, 3)
end

T["navigation commands"]["jump to specific index"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.clear_all_history()
    history_manager.set_current_project("/test/project")

    -- Create navigation history
    for i = 1, 5 do
        local from_loc = { file_path = "/test/file" .. i .. ".lua", position = { line = i, column = 1 } }
        local to_loc = { file_path = "/test/file" .. (i + 1) .. ".lua", position = { line = i + 1, column = 1 } }
        history_manager.record_jump(from_loc, to_loc, "manual")
    end

    -- Jump to specific index
    local success, entry = history_manager.navigate_to_index(3)
    MiniTest.expect.equality(success, true)
    MiniTest.expect.equality(entry.position.line, 4)

    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail.current_index, 3)
end

T["navigation commands"]["bookmark management"] = function()
    -- Setup
    bookmarks.setup({})
    bookmarks.clear_all_bookmarks(true) -- Clear globally

    local location = {
        file_path = "/test/bookmark.lua",
        position = { line = 42, column = 10 },
    }

    -- Add bookmark
    local success, bookmark = bookmarks.add_bookmark(location, true) -- manual bookmark
    MiniTest.expect.equality(success, true)
    MiniTest.expect.equality(bookmark.is_manual, true)

    -- Get bookmarks
    local all_bookmarks = bookmarks.get_all_bookmarks()
    MiniTest.expect.equality(#all_bookmarks >= 1, true)

    -- Check if location is bookmarked
    local is_bookmarked = bookmarks.is_bookmarked(location)
    MiniTest.expect.equality(is_bookmarked, true)

    -- Remove bookmark
    success = bookmarks.remove_bookmark(location)
    MiniTest.expect.equality(success, true)

    -- Should no longer be bookmarked
    is_bookmarked = bookmarks.is_bookmarked(location)
    MiniTest.expect.equality(is_bookmarked, false)
end

T["navigation commands"]["bookmark toggle"] = function()
    -- Setup
    bookmarks.setup({})
    bookmarks.clear_all_bookmarks(true)

    local location = {
        file_path = "/test/toggle.lua",
        position = { line = 10, column = 1 },
    }

    -- Toggle on
    local success, action = bookmarks.toggle_bookmark(location)
    MiniTest.expect.equality(success, true)
    MiniTest.expect.equality(action, "added")

    -- Toggle off
    success, action = bookmarks.toggle_bookmark(location)
    MiniTest.expect.equality(success, true)
    MiniTest.expect.equality(action, "removed")
end

T["navigation commands"]["history clearing"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.set_current_project("/test/project")

    -- Add history
    local from_loc = { file_path = "/test/file1.lua", position = { line = 1, column = 1 } }
    local to_loc = { file_path = "/test/file2.lua", position = { line = 2, column = 2 } }
    history_manager.record_jump(from_loc, to_loc, "manual")

    -- Clear current project
    local success = history_manager.clear_current_project_history()
    MiniTest.expect.equality(success, true)

    -- Should have no trail
    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail, nil)
end

T["navigation commands"]["project switching"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.clear_all_history()

    -- Set project 1
    history_manager.set_current_project("/test/project1")
    local from_loc = { file_path = "/test/project1/file.lua", position = { line = 1, column = 1 } }
    local to_loc = { file_path = "/test/project1/file2.lua", position = { line = 2, column = 2 } }
    history_manager.record_jump(from_loc, to_loc, "manual")

    -- Set project 2
    history_manager.set_current_project("/test/project2")
    from_loc = { file_path = "/test/project2/file.lua", position = { line = 10, column = 10 } }
    to_loc = { file_path = "/test/project2/file2.lua", position = { line = 20, column = 20 } }
    history_manager.record_jump(from_loc, to_loc, "manual")

    -- Check project 1 trail
    local success = history_manager.switch_to_project("/test/project1")
    MiniTest.expect.equality(success, true)
    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 1)
    MiniTest.expect.equality(trail.entries[1].position.line, 2)

    -- Check project 2 trail
    success = history_manager.switch_to_project("/test/project2")
    MiniTest.expect.equality(success, true)
    trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 1)
    MiniTest.expect.equality(trail.entries[1].position.line, 20)
end

return T
