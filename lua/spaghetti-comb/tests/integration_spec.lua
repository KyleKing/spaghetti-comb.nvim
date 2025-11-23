-- Integration tests
local MiniTest = require("mini.test")
local history_manager = require("spaghetti-comb.history.manager")
local lsp_integration = require("spaghetti-comb.navigation.lsp")
local jumplist = require("spaghetti-comb.navigation.jumplist")
local events = require("spaghetti-comb.navigation.events")
local statusline = require("spaghetti-comb.ui.statusline")
local storage = require("spaghetti-comb.history.storage")
local types = require("spaghetti-comb.types")

local T = MiniTest.new_set()

-- Test setup
T["integration"] = MiniTest.new_set()

T["integration"]["lsp integration setup"] = function()
    -- Test LSP integration setup
    local config = {
        integration = {
            lsp = true,
        },
    }

    lsp_integration.setup(config)

    -- Should not error during setup
    MiniTest.expect.no_error(function() lsp_integration.setup(config) end)
end

T["integration"]["jumplist enhancement setup"] = function()
    -- Test jumplist integration setup
    local config = {
        integration = {
            jumplist = true,
        },
    }

    jumplist.setup(config)

    -- Should not error during setup
    MiniTest.expect.no_error(function() jumplist.setup(config) end)
end

T["integration"]["project separation works"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.clear_all_history()

    -- Create separate histories for two projects
    history_manager.set_current_project("/project1")
    local loc1 = { file_path = "/project1/file.lua", position = { line = 1, column = 1 } }
    local loc2 = { file_path = "/project1/file2.lua", position = { line = 2, column = 2 } }
    history_manager.record_jump(loc1, loc2, "manual")

    history_manager.set_current_project("/project2")
    local loc3 = { file_path = "/project2/file.lua", position = { line = 10, column = 10 } }
    local loc4 = { file_path = "/project2/file2.lua", position = { line = 20, column = 20 } }
    history_manager.record_jump(loc3, loc4, "manual")

    -- Verify separate trails
    local project1_trail = history_manager.get_or_create_project_trail("/project1")
    local project2_trail = history_manager.get_or_create_project_trail("/project2")

    MiniTest.expect.equality(#project1_trail.entries, 1)
    MiniTest.expect.equality(#project2_trail.entries, 1)
    MiniTest.expect.equality(project1_trail.entries[1].position.line, 2)
    MiniTest.expect.equality(project2_trail.entries[1].position.line, 20)
end

T["integration"]["statusline integration works"] = function()
    -- Setup
    statusline.setup({})

    -- Get status
    local status = statusline.get_branch_status()

    -- Status should be nil or valid
    if status then
        MiniTest.expect.equality(type(status), "table")
    end
end

T["integration"]["events system setup"] = function()
    -- Test events system setup
    local config = {}
    events.setup(config)

    -- Should not error during setup
    MiniTest.expect.no_error(function() events.setup(config) end)
end

T["integration"]["persistence save and load"] = function()
    -- Create a test trail
    local trail = types.create_navigation_trail({
        project_root = "/test/persist/project",
        entries = {
            types.create_navigation_entry({
                file_path = "/test/persist/project/file.lua",
                position = { line = 42, column = 10 },
                jump_type = "manual",
            }),
        },
        current_index = 1,
    })

    -- Save to storage
    local success, msg = storage.save_history(trail, "/test/persist/project")
    MiniTest.expect.equality(success, true)

    -- Load from storage
    local loaded_trail, err = storage.load_history("/test/persist/project")
    MiniTest.expect.equality(loaded_trail ~= nil, true)
    MiniTest.expect.equality(err, nil)

    -- Verify loaded data matches
    if loaded_trail then
        MiniTest.expect.equality(loaded_trail.project_root, trail.project_root)
        MiniTest.expect.equality(#loaded_trail.entries, #trail.entries)
        MiniTest.expect.equality(loaded_trail.entries[1].position.line, 42)
    end

    -- Clean up
    storage.delete_history("/test/persist/project")
end

T["integration"]["storage statistics"] = function()
    -- Get storage stats
    local stats = storage.get_storage_stats()

    -- Should return valid stats structure
    MiniTest.expect.equality(type(stats), "table")
    MiniTest.expect.equality(type(stats.history_count), "number")
    MiniTest.expect.equality(type(stats.bookmark_count), "number")
    MiniTest.expect.equality(type(stats.total_size), "number")
    MiniTest.expect.equality(type(stats.storage_dir), "string")
end

T["integration"]["type validation"] = function()
    -- Test navigation entry validation
    local entry = types.create_navigation_entry({
        file_path = "/test/file.lua",
        position = { line = 10, column = 5 },
    })

    local valid, err = types.validate_navigation_entry(entry)
    MiniTest.expect.equality(valid, true)
    MiniTest.expect.equality(err, nil)

    -- Test invalid entry
    local invalid_entry = { invalid = "data" }
    valid, err = types.validate_navigation_entry(invalid_entry)
    MiniTest.expect.equality(valid, false)
    MiniTest.expect.equality(err ~= nil, true)

    -- Test trail validation
    local trail = types.create_navigation_trail({
        project_root = "/test/project",
    })

    valid, err = types.validate_navigation_trail(trail)
    MiniTest.expect.equality(valid, true)
    MiniTest.expect.equality(err, nil)
end

T["integration"]["performance basic operations"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.clear_all_history()
    history_manager.set_current_project("/test/performance")

    -- Measure time to record many jumps
    local start_time = os.clock()
    for i = 1, 100 do
        local from_loc = { file_path = "/test/file" .. i .. ".lua", position = { line = i, column = 1 } }
        local to_loc = { file_path = "/test/file" .. (i + 1) .. ".lua", position = { line = i + 1, column = 1 } }
        history_manager.record_jump(from_loc, to_loc, "manual")
    end
    local elapsed = os.clock() - start_time

    -- Should complete in reasonable time (< 1 second for 100 entries)
    MiniTest.expect.equality(elapsed < 1.0, true)

    -- Verify all entries recorded
    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 100)
end

T["integration"]["memory cleanup"] = function()
    -- Setup
    history_manager.setup({})
    history_manager.clear_all_history()

    -- Create multiple project trails
    for i = 1, 10 do
        history_manager.set_current_project("/test/project" .. i)
        for j = 1, 10 do
            local from_loc = { file_path = "/test/file" .. j .. ".lua", position = { line = j, column = 1 } }
            local to_loc = { file_path = "/test/file" .. (j + 1) .. ".lua", position = { line = j + 1, column = 1 } }
            history_manager.record_jump(from_loc, to_loc, "manual")
        end
    end

    -- Clear all history
    local success = history_manager.clear_all_history()
    MiniTest.expect.equality(success, true)

    -- Verify cleanup
    local all_projects = history_manager.get_all_project_trails()
    MiniTest.expect.equality(vim.tbl_count(all_projects), 0)
end

return T
