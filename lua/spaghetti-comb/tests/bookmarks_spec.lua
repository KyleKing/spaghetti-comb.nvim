-- Bookmark management tests
local MiniTest = require("mini.test")
local helpers = MiniTest.new_set()
local bookmarks = require("spaghetti-comb.history.bookmarks")
local config = require("spaghetti-comb.config")

-- Helper functions
local function expect_truthy(value) MiniTest.expect.equality(value ~= nil and value ~= false, true) end

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
helpers["bookmarks"] = MiniTest.new_set({}, {
    -- Task 5.1: Manual bookmark functionality
    ["toggle_bookmark adds then removes"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 10, 5)
        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        local success, action = bookmarks.toggle_bookmark(location)
        expect_truthy(success)
        MiniTest.expect.equality(action, "added")
        MiniTest.expect.equality(#bookmarks.get_all_bookmarks(), 1)

        success, action = bookmarks.toggle_bookmark(location)
        expect_truthy(success)
        MiniTest.expect.equality(action, "removed")
        MiniTest.expect.equality(#bookmarks.get_all_bookmarks(), 0)
    end,

    ["add_bookmark creates manual or automatic bookmarks"] = function()
        for _, is_manual in ipairs({ true, false }) do
            bookmarks.reset()
            bookmarks.setup(config.default)

            local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 15, 8)
            bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

            local success, action = bookmarks.add_bookmark(location, is_manual)

            expect_truthy(success)
            MiniTest.expect.equality(action, "added")

            local all_bookmarks = bookmarks.get_all_bookmarks()
            MiniTest.expect.equality(#all_bookmarks, 1)
            MiniTest.expect.equality(all_bookmarks[1].is_manual == true, is_manual)
        end
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

        expect_truthy(success)
        MiniTest.expect.equality(action, "updated")

        local all_bookmarks = bookmarks.get_all_bookmarks()
        MiniTest.expect.equality(#all_bookmarks, 1)
        expect_truthy(all_bookmarks[1].is_manual)
    end,

    ["remove_bookmark removes existing and reports missing"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 30, 12)
        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        bookmarks.add_bookmark(location, true)

        local success, msg = bookmarks.remove_bookmark(location)
        expect_truthy(success)
        MiniTest.expect.equality(msg, "removed")
        MiniTest.expect.equality(#bookmarks.get_all_bookmarks(), 0)

        success, msg = bookmarks.remove_bookmark(location)
        MiniTest.expect.equality(success, false)
        MiniTest.expect.equality(msg, "Bookmark not found")
    end,

    ["clear_all_bookmarks clears project-only or every bookmark"] = function()
        for _, include_global in ipairs({ false, true }) do
            bookmarks.reset()
            bookmarks.setup(config.default)

            bookmarks.set_current_project("/tmp/project1")
            bookmarks.add_bookmark(create_test_location("/tmp/project1/test.lua", 10, 5), true)

            bookmarks.set_current_project("/tmp/project2")
            bookmarks.add_bookmark(create_test_location("/tmp/project2/test.lua", 20, 8), true)

            local success, _msg = bookmarks.clear_all_bookmarks(include_global)
            expect_truthy(success)

            local remaining = #bookmarks.get_all_bookmarks("/tmp/project1")
                + #bookmarks.get_all_bookmarks("/tmp/project2")
            MiniTest.expect.equality(remaining, include_global and 0 or 1)
        end
    end,

    ["is_bookmarked reflects bookmark presence"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 10, 5)
        bookmarks.set_current_project("/tmp/spaghetti-comb.nvim")

        MiniTest.expect.equality(bookmarks.is_bookmarked(location), false)

        bookmarks.add_bookmark(location, true)

        local is_marked, bookmark = bookmarks.is_bookmarked(location)
        expect_truthy(is_marked)
        expect_truthy(bookmark)
    end,

    ["prune_dead_bookmarks drops bookmarks whose file is gone"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local live = vim.fn.tempname() .. ".lua"
        vim.fn.writefile({ "x" }, live)
        bookmarks.set_current_project(vim.fn.fnamemodify(live, ":h"))

        bookmarks.add_bookmark(create_test_location(live, 1, 1), true)
        bookmarks.add_bookmark(create_test_location(live .. ".gone", 1, 1), true)

        MiniTest.expect.equality(bookmarks.prune_dead_bookmarks(), 1)

        local remaining = bookmarks.get_all_bookmarks()
        MiniTest.expect.equality(#remaining, 1)
        MiniTest.expect.equality(remaining[1].file_path, live)
        os.remove(live)
    end,

    -- Task 5.2: Frequent location tracking
    ["increment_visit_count drives get_visit_count"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 10, 5)

        MiniTest.expect.equality(bookmarks.get_visit_count(location), 0)

        local success, count = bookmarks.increment_visit_count(location)
        expect_truthy(success)
        MiniTest.expect.equality(count, 1)

        bookmarks.increment_visit_count(location)
        bookmarks.increment_visit_count(location)

        MiniTest.expect.equality(bookmarks.get_visit_count(location), 3)
    end,

    ["is_frequent tracks the visit threshold"] = function()
        bookmarks.reset()
        bookmarks.setup(config.default)

        local location = create_test_location("/tmp/spaghetti-comb.nvim/test.lua", 10, 5)

        -- Below the threshold (default 3)
        bookmarks.increment_visit_count(location)
        bookmarks.increment_visit_count(location)

        local is_freq, count = bookmarks.is_frequent(location)
        MiniTest.expect.equality(is_freq, false)
        MiniTest.expect.equality(count, 2)

        bookmarks.increment_visit_count(location)

        is_freq, count = bookmarks.is_frequent(location)
        expect_truthy(is_freq)
        MiniTest.expect.equality(count, 3)
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

        local success, _msg = bookmarks.update_frequent_locations()

        expect_truthy(success)

        -- Check that location1 was auto-bookmarked
        local is_marked, bookmark = bookmarks.is_bookmarked(location1)
        expect_truthy(is_marked)
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
