-- Bookmark management tests
local helpers = require("mini.test").new_set()
local bookmarks = require("spaghetti-comb-v2.history.bookmarks")
local config = require("spaghetti-comb-v2.config")

-- Helper functions
local function create_test_location(file_path, line, col)
    return {
        file_path = file_path or "/tmp/test_file.lua",
        position = { line = line or 10, column = col or 5 },
        context = {
            before_lines = { "-- context before" },
            after_lines = { "-- context after" },
            function_name = "test_function",
        },
    }
end

-- Tests
helpers.add = vim.tbl_deep_extend("force", helpers.add or {}, {
    -- Setup and teardown
    ["setup initializes bookmark manager"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local state = bookmarks.get_state()
        MiniTest.expect.truthy(state.initialized)
    end,

    -- Task 5.1: Manual bookmark functionality
    ["toggle_bookmark adds bookmark when not present"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 10, 5)
        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        local success, action = bookmarks.toggle_bookmark(location)

        MiniTest.expect.truthy(success)
        MiniTest.expect.equality(action, "added")

        local all_bookmarks = bookmarks.get_all_bookmarks()
        MiniTest.expect.equality(#all_bookmarks, 1)
    end,

    ["toggle_bookmark removes bookmark when present"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 10, 5)
        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        -- Add bookmark first
        bookmarks.toggle_bookmark(location)

        -- Toggle again to remove
        local success, action = bookmarks.toggle_bookmark(location)

        MiniTest.expect.truthy(success)
        MiniTest.expect.equality(action, "removed")

        local all_bookmarks = bookmarks.get_all_bookmarks()
        MiniTest.expect.equality(#all_bookmarks, 0)
    end,

    ["add_bookmark creates manual bookmark"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 15, 8)
        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        local success, action = bookmarks.add_bookmark(location, true)

        MiniTest.expect.truthy(success)
        MiniTest.expect.equality(action, "added")

        local all_bookmarks = bookmarks.get_all_bookmarks()
        MiniTest.expect.equality(#all_bookmarks, 1)
        MiniTest.expect.truthy(all_bookmarks[1].is_manual)
    end,

    ["add_bookmark creates automatic bookmark"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 20, 3)
        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        local success, action = bookmarks.add_bookmark(location, false)

        MiniTest.expect.truthy(success)
        MiniTest.expect.equality(action, "added")

        local all_bookmarks = bookmarks.get_all_bookmarks()
        MiniTest.expect.equality(#all_bookmarks, 1)
        MiniTest.expect.equality(all_bookmarks[1].is_manual, false)
    end,

    ["add_bookmark updates existing bookmark"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 25, 10)
        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        -- Add first time
        bookmarks.add_bookmark(location, false)

        -- Add again (should update to manual)
        local success, action = bookmarks.add_bookmark(location, true)

        MiniTest.expect.truthy(success)
        MiniTest.expect.equality(action, "updated")

        local all_bookmarks = bookmarks.get_all_bookmarks()
        MiniTest.expect.equality(#all_bookmarks, 1)
        MiniTest.expect.truthy(all_bookmarks[1].is_manual)
    end,

    ["remove_bookmark removes existing bookmark"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 30, 12)
        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        -- Add bookmark first
        bookmarks.add_bookmark(location, true)

        -- Remove it
        local success, msg = bookmarks.remove_bookmark(location)

        MiniTest.expect.truthy(success)
        MiniTest.expect.equality(msg, "removed")

        local all_bookmarks = bookmarks.get_all_bookmarks()
        MiniTest.expect.equality(#all_bookmarks, 0)
    end,

    ["remove_bookmark fails when bookmark not found"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 35, 7)
        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        local success, msg = bookmarks.remove_bookmark(location)

        MiniTest.expect.equality(success, false)
        MiniTest.expect.equality(msg, "Bookmark not found")
    end,

    ["clear_all_bookmarks clears project bookmarks"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        -- Add multiple bookmarks
        bookmarks.add_bookmark(create_test_location("/tmp/spaghetti-comb.nvim/test1.lua", 10, 5), true)
        bookmarks.add_bookmark(create_test_location("/tmp/spaghetti-comb.nvim/test2.lua", 20, 8), true)

        local success, msg = bookmarks.clear_all_bookmarks(false)

        MiniTest.expect.truthy(success)

        local all_bookmarks = bookmarks.get_all_bookmarks()
        MiniTest.expect.equality(#all_bookmarks, 0)
    end,

    ["clear_all_bookmarks clears global bookmarks"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        -- Add bookmarks to multiple projects
        bookmarks.set_current_project("/tmp/project1")
        bookmarks.add_bookmark(create_test_location("/tmp/project1/test.lua", 10, 5), true)

        bookmarks.set_current_project("/tmp/project2")
        bookmarks.add_bookmark(create_test_location("/tmp/project2/test.lua", 20, 8), true)

        local success, msg = bookmarks.clear_all_bookmarks(true)

        MiniTest.expect.truthy(success)

        local all_bookmarks = bookmarks.get_all_bookmarks()
        MiniTest.expect.equality(#all_bookmarks, 0)
    end,

    ["get_all_bookmarks returns current project bookmarks"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        bookmarks.add_bookmark(create_test_location("/tmp/spaghetti-comb.nvim/test1.lua", 10, 5), true)
        bookmarks.add_bookmark(create_test_location("/tmp/spaghetti-comb.nvim/test2.lua", 20, 8), true)

        local all_bookmarks = bookmarks.get_all_bookmarks()

        MiniTest.expect.equality(#all_bookmarks, 2)
    end,

    ["get_all_bookmarks returns specific project bookmarks"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        bookmarks.set_current_project("/tmp/project1")
        bookmarks.add_bookmark(create_test_location("/tmp/project1/test.lua", 10, 5), true)

        bookmarks.set_current_project("/tmp/project2")
        bookmarks.add_bookmark(create_test_location("/tmp/project2/test.lua", 20, 8), true)

        local project1_bookmarks = bookmarks.get_all_bookmarks("/tmp/project1")

        MiniTest.expect.equality(#project1_bookmarks, 1)
        MiniTest.expect.equality(project1_bookmarks[1].file_path, "/tmp/project1/test.lua")
    end,

    ["is_bookmarked returns true for bookmarked location"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 10, 5)
        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        bookmarks.add_bookmark(location, true)

        local is_marked, bookmark = bookmarks.is_bookmarked(location)

        MiniTest.expect.truthy(is_marked)
        MiniTest.expect.truthy(bookmark)
    end,

    ["is_bookmarked returns false for non-bookmarked location"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 10, 5)
        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        local is_marked, _ = bookmarks.is_bookmarked(location)

        MiniTest.expect.equality(is_marked, false)
    end,

    -- Task 5.2: Frequent location tracking
    ["increment_visit_count increments count"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 10, 5)

        local success, count = bookmarks.increment_visit_count(location)

        MiniTest.expect.truthy(success)
        MiniTest.expect.equality(count, 1)

        -- Increment again
        success, count = bookmarks.increment_visit_count(location)
        MiniTest.expect.equality(count, 2)
    end,

    ["get_visit_count returns correct count"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 10, 5)

        -- Initial count should be 0
        local count = bookmarks.get_visit_count(location)
        MiniTest.expect.equality(count, 0)

        -- Increment and check
        bookmarks.increment_visit_count(location)
        bookmarks.increment_visit_count(location)
        bookmarks.increment_visit_count(location)

        count = bookmarks.get_visit_count(location)
        MiniTest.expect.equality(count, 3)
    end,

    ["is_frequent returns true when threshold met"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 10, 5)

        -- Increment to threshold (default is 3)
        bookmarks.increment_visit_count(location)
        bookmarks.increment_visit_count(location)
        bookmarks.increment_visit_count(location)

        local is_freq, count = bookmarks.is_frequent(location)

        MiniTest.expect.truthy(is_freq)
        MiniTest.expect.equality(count, 3)
    end,

    ["is_frequent returns false when threshold not met"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 10, 5)

        -- Increment below threshold
        bookmarks.increment_visit_count(location)
        bookmarks.increment_visit_count(location)

        local is_freq, count = bookmarks.is_frequent(location)

        MiniTest.expect.equality(is_freq, false)
        MiniTest.expect.equality(count, 2)
    end,

    ["update_frequent_locations promotes frequent locations"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        local location1 = create_test_location("/tmp/spaghetti-comb.nvim/test1.lua", 10, 5)
        local location2 = create_test_location("/tmp/spaghetti-comb.nvim/test2.lua", 20, 8)

        -- Visit location1 enough to be frequent
        bookmarks.increment_visit_count(location1)
        bookmarks.increment_visit_count(location1)
        bookmarks.increment_visit_count(location1)

        -- Visit location2 below threshold
        bookmarks.increment_visit_count(location2)

        local success, msg = bookmarks.update_frequent_locations()

        MiniTest.expect.truthy(success)

        -- Check that location1 was auto-bookmarked
        local is_marked, bookmark = bookmarks.is_bookmarked(location1)
        MiniTest.expect.truthy(is_marked)
        MiniTest.expect.equality(bookmark.is_manual, false)

        -- Check that location2 was not auto-bookmarked
        is_marked, _ = bookmarks.is_bookmarked(location2)
        MiniTest.expect.equality(is_marked, false)
    end,

    ["get_frequent_locations returns sorted list"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location1 = create_test_location("/tmp/spaghetti-comb.nvim/test1.lua", 10, 5)
        local location2 = create_test_location("/tmp/spaghetti-comb.nvim/test2.lua", 20, 8)

        -- Visit location1 3 times
        bookmarks.increment_visit_count(location1)
        bookmarks.increment_visit_count(location1)
        bookmarks.increment_visit_count(location1)

        -- Visit location2 5 times
        for _ = 1, 5 do
            bookmarks.increment_visit_count(location2)
        end

        local frequent = bookmarks.get_frequent_locations()

        MiniTest.expect.equality(#frequent, 2)
        -- Should be sorted by visit count descending
        MiniTest.expect.equality(frequent[1].visit_count, 5)
        MiniTest.expect.equality(frequent[2].visit_count, 3)
    end,

    -- Project separation tests
    ["bookmarks are project-separated"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        -- Add bookmark to project1
        bookmarks.set_current_project("/tmp/project1")
        local loc1 = create_test_location("/tmp/project1/test.lua", 10, 5)
        bookmarks.add_bookmark(loc1, true)

        -- Add bookmark to project2
        bookmarks.set_current_project("/tmp/project2")
        local loc2 = create_test_location("/tmp/project2/test.lua", 20, 8)
        bookmarks.add_bookmark(loc2, true)

        -- Check project1 bookmarks
        bookmarks.set_current_project("/tmp/project1")
        local project1_bookmarks = bookmarks.get_all_bookmarks()
        MiniTest.expect.equality(#project1_bookmarks, 1)

        -- Check project2 bookmarks
        bookmarks.set_current_project("/tmp/project2")
        local project2_bookmarks = bookmarks.get_all_bookmarks()
        MiniTest.expect.equality(#project2_bookmarks, 1)
    end,
})

return helpers
