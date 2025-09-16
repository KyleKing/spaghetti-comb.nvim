-- History manager tests
local MiniTest = require("mini.test")
local history_manager = require("spaghetti-comb-v2.history.manager")

local T = MiniTest.new_set()

-- Test setup
T["history manager"] = MiniTest.new_set()

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
    -- TODO: Implement in task 13.1
end

T["history manager"]["prunes inconsequential jumps"] = function()
    -- TODO: Implement in task 13.1
end

T["history manager"]["recovers shifted locations"] = function()
    -- TODO: Implement in task 13.1
end

T["history manager"]["debounces pruning operations"] = function()
    -- TODO: Implement in task 13.1
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
