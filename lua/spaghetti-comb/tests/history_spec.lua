-- History manager tests
local MiniTest = require("mini.test")
local history_manager = require("spaghetti-comb.history.manager")

local T = MiniTest.new_set()

-- Test setup
T["history manager"] = MiniTest.new_set({
    hooks = {
        pre_case = function() history_manager.reset() end,
    },
})

T["history manager"]["setup"] = function()
    -- Test basic setup
    local config = {
        history = {
            exploration_timeout_minutes = 5,
        },
    }

    history_manager.setup(config)

    -- Should be able to set current project
    history_manager.set_current_project("/test/project")
    MiniTest.expect.equality(history_manager.get_current_project(), "/test/project")
end

T["history manager"]["records jumps correctly"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.set_current_project("/test/project")

    -- Record a jump
    local from_location = {
        file_path = "/test/project/file1.lua",
        position = { line = 10, column = 5 },
    }
    local to_location = {
        file_path = "/test/project/file2.lua",
        position = { line = 20, column = 10 },
    }

    local success, entry = history_manager.record_jump(from_location, to_location, "manual")

    MiniTest.expect.equality(success, true)
    MiniTest.expect.equality(entry.file_path, "/test/project/file2.lua")
    MiniTest.expect.equality(entry.position.line, 20)
    MiniTest.expect.equality(entry.jump_type, "manual")

    -- Check trail state
    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 1)
    MiniTest.expect.equality(trail.current_index, 1)
end

T["history manager"]["handles branching paths"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.set_current_project("/test/project")

    -- Record initial jumps
    local loc1 = { file_path = "/test/project/file1.lua", position = { line = 1, column = 1 } }
    local loc2 = { file_path = "/test/project/file2.lua", position = { line = 2, column = 2 } }
    local loc3 = { file_path = "/test/project/file3.lua", position = { line = 3, column = 3 } }

    history_manager.record_jump(loc1, loc2, "manual")
    history_manager.record_jump(loc2, loc3, "manual")

    -- Navigate back to middle
    history_manager.navigate_to_index(1)

    -- Record new jump (should create branch)
    local loc4 = { file_path = "/test/project/file4.lua", position = { line = 4, column = 4 } }
    history_manager.record_jump(loc2, loc4, "manual")

    -- Check that we have branches
    local branches = history_manager.get_active_branches()
    MiniTest.expect.equality(#branches > 0, true)
end

T["history manager"]["prunes old entries"] = function()
    -- Setup with a max age so backdated entries become stale
    history_manager.setup({
        history = {
            max_age_minutes = 30,
        },
    })

    -- Use a real file (readable) whose context cannot be recovered, so the
    -- stale entry is actually pruned rather than "recovered" and kept.
    local tmp = vim.fn.tempname()
    vim.fn.writefile({ "alpha", "beta", "gamma" }, tmp)
    history_manager.set_current_project(vim.fn.fnamemodify(tmp, ":h"))

    local from_loc = { file_path = tmp, position = { line = 1, column = 1 } }
    local to_loc = { file_path = tmp, position = { line = 2, column = 2 } }
    local _, entry = history_manager.record_jump(from_loc, to_loc, "manual")

    -- Backdate beyond max age and give it an unmatchable recovery context
    entry.timestamp = os.time() - (60 * 60)
    entry.original_position = { line = 999, column = 1 }
    entry.context = {}

    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 1)

    local success, result = history_manager.prune_with_recovery()
    MiniTest.expect.equality(success, true)
    MiniTest.expect.equality(result.total_pruned, 1)
    MiniTest.expect.equality(result.total_recovered, 0)

    -- The stale, unrecoverable entry (and its now-empty trail) should be gone
    trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 0)

    vim.fn.delete(tmp)
end

T["history manager"]["prunes inconsequential jumps"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.set_current_project("/test/project")

    -- Create a series of small auto jumps within the same file
    local file_path = "/test/project/file1.lua"
    for i = 1, 5 do
        local from_loc = { file_path = file_path, position = { line = i, column = 1 } }
        local to_loc = { file_path = file_path, position = { line = i + 1, column = 1 } }
        history_manager.record_jump(from_loc, to_loc, "auto")
    end

    local trail = history_manager.get_current_trail()
    local initial_count = #trail.entries
    MiniTest.expect.equality(initial_count, 5)

    -- Prune inconsequential jumps
    local pruned_entries = history_manager.prune_inconsequential_jumps(trail.entries)

    -- Small consecutive auto movements should collapse into fewer entries
    MiniTest.expect.equality(#pruned_entries < initial_count, true)
end

T["history manager"]["determines inconsequential jumps"] = function()
    -- Setup
    history_manager.setup({})

    -- Same file, small distance, auto jump
    local entry1 = {
        file_path = "/test/file.lua",
        position = { line = 10, column = 1 },
        timestamp = os.time(),
        jump_type = "auto",
    }
    local entry2 = {
        file_path = "/test/file.lua",
        position = { line = 12, column = 1 },
        timestamp = os.time(),
        jump_type = "auto",
    }

    -- Should be inconsequential (same file, small distance, auto jump)
    MiniTest.expect.equality(history_manager.is_inconsequential_jump(entry1, entry2), true)

    -- Different file should not be inconsequential
    entry2.file_path = "/test/other.lua"
    MiniTest.expect.equality(history_manager.is_inconsequential_jump(entry1, entry2), false)

    -- Large distance should not be inconsequential
    entry2.file_path = "/test/file.lua"
    entry2.position.line = 100
    MiniTest.expect.equality(history_manager.is_inconsequential_jump(entry1, entry2), false)

    -- Manual jump should not be inconsequential
    entry2.position.line = 12
    entry2.jump_type = "manual"
    MiniTest.expect.equality(history_manager.is_inconsequential_jump(entry1, entry2), false)
end

T["history manager"]["recovers shifted locations"] = function()
    -- Setup
    history_manager.setup({})

    -- Write a real temporary file so location recovery can read it
    local tmp = vim.fn.tempname()
    vim.fn.writefile({
        "line one",
        "line two",
        "target line",
        "line four",
        "line five",
    }, tmp)

    -- An entry whose surrounding context still matches the file resolves to itself
    local entry = {
        file_path = tmp,
        position = { line = 3, column = 2 },
        original_position = { line = 3, column = 2 },
        context = {
            before_lines = { "line two" },
            after_lines = { "line four" },
        },
    }

    local recovered = history_manager.find_shifted_location(entry)
    MiniTest.expect.equality(type(recovered), "table")
    MiniTest.expect.equality(recovered.line, 3)
    MiniTest.expect.equality(recovered.column, 2)

    -- When the original line no longer exists, recovery falls back to locating
    -- a unique context string and returns the shifted line
    local shifted = {
        file_path = tmp,
        position = { line = 99, column = 4 },
        original_position = { line = 99, column = 4 },
        context = {
            before_lines = { "target line" },
        },
    }
    local relocated = history_manager.find_shifted_location(shifted)
    MiniTest.expect.equality(type(relocated), "table")
    MiniTest.expect.equality(relocated.line, 3)
    MiniTest.expect.equality(relocated.column, 4)

    vim.fn.delete(tmp)
end

T["history manager"]["debounces pruning operations"] = function()
    -- Setup
    history_manager.setup({})

    local function pending_timer_ids()
        local ids = {}
        for _, info in ipairs(vim.fn.timer_info()) do
            ids[info.id] = true
        end
        return ids
    end

    local base = pending_timer_ids()

    -- First schedule creates a pending timer
    MiniTest.expect.equality(history_manager.schedule_pruning(), true)
    local after_first = pending_timer_ids()

    local first_timer
    for id in pairs(after_first) do
        if not base[id] then first_timer = id end
    end
    MiniTest.expect.equality(type(first_timer), "number")

    -- Second schedule cancels the first timer (debounce) and creates a new one
    MiniTest.expect.equality(history_manager.schedule_pruning(), true)
    local after_second = pending_timer_ids()
    MiniTest.expect.equality(after_second[first_timer], nil)

    -- Clean up any timers this test created so pruning never fires mid-suite
    for id in pairs(after_second) do
        if not base[id] then vim.fn.timer_stop(id) end
    end
end

T["history manager"]["navigates backward and forward"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.set_current_project("/test/project")

    -- Record multiple jumps
    for i = 1, 5 do
        local from_loc = { file_path = "/test/project/file" .. i .. ".lua", position = { line = i, column = 1 } }
        local to_loc =
            { file_path = "/test/project/file" .. (i + 1) .. ".lua", position = { line = i + 1, column = 1 } }
        history_manager.record_jump(from_loc, to_loc, "manual")
    end

    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail.current_index, 5)

    -- Go back
    local success = history_manager.go_back(2)
    MiniTest.expect.equality(success, true)
    trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail.current_index, 3)

    -- Go forward
    success = history_manager.go_forward(1)
    MiniTest.expect.equality(success, true)
    trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail.current_index, 4)
end

T["history manager"]["clears history correctly"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.set_current_project("/test/project")

    -- Add some entries
    local from_loc = { file_path = "/test/project/file1.lua", position = { line = 1, column = 1 } }
    local to_loc = { file_path = "/test/project/file2.lua", position = { line = 2, column = 2 } }
    history_manager.record_jump(from_loc, to_loc, "manual")

    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 1)

    -- Clear current project
    local success = history_manager.clear_current_project_history()
    MiniTest.expect.equality(success, true)

    -- Trail is lazily recreated empty for the current project
    trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 0)

    -- Add entries again under a different project
    history_manager.set_current_project("/test/project2")
    history_manager.record_jump(from_loc, to_loc, "manual")

    -- Clear all history
    success = history_manager.clear_all_history()
    MiniTest.expect.equality(success, true)
    MiniTest.expect.equality(#history_manager.get_current_trail().entries, 0)
end

T["history manager"]["gets statistics"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.set_current_project("/test/project")

    -- Record some jumps
    for i = 1, 3 do
        local from_loc = { file_path = "/test/project/file" .. i .. ".lua", position = { line = i, column = 1 } }
        local to_loc =
            { file_path = "/test/project/file" .. (i + 1) .. ".lua", position = { line = i + 1, column = 1 } }
        history_manager.record_jump(from_loc, to_loc, "manual")
    end

    local stats = history_manager.get_stats()
    MiniTest.expect.equality(stats.total_entries, 3)
    MiniTest.expect.equality(stats.current_index, 3)
    MiniTest.expect.equality(stats.project_root, "/test/project")
end

T["history manager"]["detects exploration state"] = function()
    -- Setup
    history_manager.setup({
        history = {
            exploration_timeout_minutes = 1, -- 1 minute for testing
        },
    })
    history_manager.set_current_project("/test/project")

    -- Initially should be idle
    MiniTest.expect.equality(history_manager.determine_exploration_state(), "idle")

    -- After recording a jump, should be exploring
    local from_loc = { file_path = "/test/project/file1.lua", position = { line = 1, column = 1 } }
    local to_loc = { file_path = "/test/project/file2.lua", position = { line = 2, column = 2 } }
    history_manager.record_jump(from_loc, to_loc, "manual")

    MiniTest.expect.equality(history_manager.determine_exploration_state(), "exploring")
end

return T
