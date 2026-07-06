-- Integration tests exercising cross-module flows
local MiniTest = require("mini.test")
local history_manager = require("spaghetti-comb.history.manager")
local storage = require("spaghetti-comb.history.storage")
local breadcrumbs = require("spaghetti-comb.ui.breadcrumbs")
local jumplist = require("spaghetti-comb.navigation.jumplist")
local events = require("spaghetti-comb.navigation.events")
local statusline = require("spaghetti-comb.ui.statusline")
local lsp = require("spaghetti-comb.navigation.lsp")
local types = require("spaghetti-comb.types")
local debug_utils = require("spaghetti-comb.utils.debug")

local T = MiniTest.new_set()

-- Cross-module: history manager driving trails, breadcrumbs, and performance
T["cross-module"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            history_manager.reset()
            history_manager.setup({})
            history_manager.clear_all_history()
        end,
    },
})

T["cross-module"]["project separation isolates trails"] = function()
    -- Fabricated paths have no project markers and are unreadable, so
    -- record_jump keeps the explicitly set project instead of auto-detecting.
    history_manager.set_current_project("/project1")
    history_manager.record_jump(
        { file_path = "/project1/file.lua", position = { line = 1, column = 1 } },
        { file_path = "/project1/file2.lua", position = { line = 2, column = 2 } },
        "manual"
    )

    history_manager.set_current_project("/project2")
    history_manager.record_jump(
        { file_path = "/project2/file.lua", position = { line = 10, column = 10 } },
        { file_path = "/project2/file2.lua", position = { line = 20, column = 20 } },
        "manual"
    )

    local project1_trail = history_manager.get_or_create_project_trail("/project1")
    local project2_trail = history_manager.get_or_create_project_trail("/project2")

    MiniTest.expect.equality(#project1_trail.entries, 1)
    MiniTest.expect.equality(#project2_trail.entries, 1)
    MiniTest.expect.equality(project1_trail.entries[1].position.line, 2)
    MiniTest.expect.equality(project2_trail.entries[1].position.line, 20)

    local all_projects = history_manager.get_all_project_trails()
    MiniTest.expect.equality(vim.tbl_count(all_projects), 2)
end

T["cross-module"]["switching projects preserves per-project state"] = function()
    history_manager.set_current_project("/proj/alpha")
    history_manager.record_jump(
        { file_path = "/proj/alpha/a.lua", position = { line = 1, column = 1 } },
        { file_path = "/proj/alpha/b.lua", position = { line = 5, column = 1 } },
        "manual"
    )

    history_manager.set_current_project("/proj/beta")
    history_manager.record_jump(
        { file_path = "/proj/beta/a.lua", position = { line = 1, column = 1 } },
        { file_path = "/proj/beta/b.lua", position = { line = 9, column = 1 } },
        "manual"
    )

    -- Switch back to alpha and confirm its trail is intact and current
    MiniTest.expect.equality(history_manager.switch_to_project("/proj/alpha"), true)
    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail.project_root, "/proj/alpha")
    MiniTest.expect.equality(#trail.entries, 1)
    MiniTest.expect.equality(trail.entries[1].position.line, 5)
end

T["cross-module"]["breadcrumbs render current trail from history manager"] = function()
    breadcrumbs.setup({})
    breadcrumbs.reset()
    breadcrumbs.setup({})

    history_manager.set_current_project("/bc/project")
    history_manager.record_jump(
        { file_path = "/bc/project/one.lua", position = { line = 3, column = 1 } },
        { file_path = "/bc/project/two.lua", position = { line = 7, column = 1 } },
        "manual"
    )
    history_manager.record_jump(
        { file_path = "/bc/project/two.lua", position = { line = 7, column = 1 } },
        { file_path = "/bc/project/three.lua", position = { line = 42, column = 1 } },
        "manual"
    )

    local ok = breadcrumbs.show_on_hotkey()
    MiniTest.expect.equality(ok, true)
    MiniTest.expect.equality(breadcrumbs.is_visible(), true)

    local trail = history_manager.get_current_trail()
    local lines = breadcrumbs._build_breadcrumb_lines(trail)
    MiniTest.expect.equality(type(lines), "table")
    -- The current (last) entry basename and line should appear in the crumb path
    MiniTest.expect.equality(lines[1]:find("three.lua:42", 1, true) ~= nil, true)

    breadcrumbs.hide()
    MiniTest.expect.equality(breadcrumbs.is_visible(), false)
end

T["cross-module"]["breadcrumbs report empty history gracefully"] = function()
    breadcrumbs.setup({})
    breadcrumbs.reset()
    breadcrumbs.setup({})

    history_manager.set_current_project("/bc/empty")
    local ok, err = breadcrumbs.show_on_hotkey()
    MiniTest.expect.equality(ok, false)
    MiniTest.expect.equality(err, "No navigation history")
    MiniTest.expect.equality(breadcrumbs.is_visible(), false)
end

T["cross-module"]["records many jumps within time budget"] = function()
    history_manager.set_current_project("/perf/project")

    local start_time = os.clock()
    for i = 1, 100 do
        history_manager.record_jump(
            { file_path = "/perf/file" .. i .. ".lua", position = { line = i, column = 1 } },
            { file_path = "/perf/file" .. (i + 1) .. ".lua", position = { line = i + 1, column = 1 } },
            "manual"
        )
    end
    local elapsed = os.clock() - start_time

    MiniTest.expect.equality(elapsed < 1.0, true)

    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 100)
end

T["cross-module"]["clear_all_history releases every project trail"] = function()
    for i = 1, 10 do
        history_manager.set_current_project("/mem/project" .. i)
        for j = 1, 10 do
            history_manager.record_jump(
                { file_path = "/mem/p" .. i .. "/file" .. j .. ".lua", position = { line = j, column = 1 } },
                { file_path = "/mem/p" .. i .. "/file" .. (j + 1) .. ".lua", position = { line = j + 1, column = 1 } },
                "manual"
            )
        end
    end

    MiniTest.expect.equality(history_manager.clear_all_history(), true)

    local all_projects = history_manager.get_all_project_trails()
    MiniTest.expect.equality(vim.tbl_count(all_projects), 0)
end

-- Jumplist integration: enhanced navigation built on the history backbone
T["jumplist"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            debug_utils.setup({})
            history_manager.reset()
            history_manager.setup({})
            history_manager.clear_all_history()
        end,
    },
})

T["jumplist"]["setup is idempotent and non-erroring"] = function()
    local config = { integration = { jumplist = true } }
    MiniTest.expect.no_error(function()
        jumplist.setup(config)
        jumplist.setup(config)
    end)
end

T["jumplist"]["exposes compatible jumplist access"] = function()
    MiniTest.expect.equality(jumplist.check_jumplist_compatibility(), true)

    local info = jumplist.get_jumplist_info()
    MiniTest.expect.equality(type(info), "table")
    MiniTest.expect.equality(type(info.total_entries), "number")
end

T["jumplist"]["back and forward move through the recorded trail"] = function()
    history_manager.set_current_project("/jl/project")
    for i = 1, 4 do
        history_manager.record_jump(
            { file_path = "/jl/file" .. i .. ".lua", position = { line = i, column = 1 } },
            { file_path = "/jl/file" .. (i + 1) .. ".lua", position = { line = (i + 1) * 10, column = 1 } },
            "manual"
        )
    end

    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(trail.current_index, 4)

    local ok, entry = history_manager.go_back(2)
    MiniTest.expect.equality(ok, true)
    MiniTest.expect.equality(entry.position.line, 30)
    MiniTest.expect.equality(history_manager.get_current_trail().current_index, 2)

    ok, entry = history_manager.go_forward(1)
    MiniTest.expect.equality(ok, true)
    MiniTest.expect.equality(history_manager.get_current_trail().current_index, 3)
end

T["jumplist"]["jump_to_index moves the cursor to a real file location"] = function()
    jumplist.setup({ integration = { jumplist = true } })

    local temp_file = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "line one", "line two", "line three", "line four" }, temp_file)

    -- Auto-detected project for the readable temp file becomes current on record.
    history_manager.record_jump(
        { file_path = temp_file, position = { line = 1, column = 1 } },
        { file_path = temp_file, position = { line = 3, column = 1 } },
        "manual"
    )

    jumplist.jump_to_index(1)
    local cursor = vim.api.nvim_win_get_cursor(0)
    MiniTest.expect.equality(cursor[1], 3)

    vim.fn.delete(temp_file)
end

-- Persistence round-trips isolated to a temporary data directory
local persistence_original_stdpath
local persistence_temp_data_dir
T["persistence"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            history_manager.reset()
            history_manager.setup({})
            persistence_original_stdpath = vim.fn.stdpath
            persistence_temp_data_dir = vim.fn.tempname()
            vim.fn.stdpath = function(what)
                if what == "data" then return persistence_temp_data_dir end
                return persistence_original_stdpath(what)
            end
        end,
        post_case = function()
            vim.fn.stdpath = persistence_original_stdpath
            if persistence_temp_data_dir then vim.fn.delete(persistence_temp_data_dir, "rf") end
            persistence_temp_data_dir = nil
            persistence_original_stdpath = nil
        end,
    },
})

T["persistence"]["save then load round-trips a trail"] = function()
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

    local success = storage.save_history(trail, "/test/persist/project")
    MiniTest.expect.equality(success, true)

    local loaded_trail, err = storage.load_history("/test/persist/project")
    MiniTest.expect.equality(loaded_trail ~= nil, true)
    MiniTest.expect.equality(err, nil)
    MiniTest.expect.equality(loaded_trail.project_root, trail.project_root)
    MiniTest.expect.equality(#loaded_trail.entries, 1)
    MiniTest.expect.equality(loaded_trail.entries[1].position.line, 42)
end

T["persistence"]["delete_history removes the saved trail"] = function()
    local trail = types.create_navigation_trail({
        project_root = "/test/persist/delete",
        entries = {
            types.create_navigation_entry({
                file_path = "/test/persist/delete/file.lua",
                position = { line = 5, column = 1 },
            }),
        },
        current_index = 1,
    })

    MiniTest.expect.equality(storage.save_history(trail, "/test/persist/delete"), true)
    MiniTest.expect.equality((storage.load_history("/test/persist/delete")) ~= nil, true)

    MiniTest.expect.equality(storage.delete_history("/test/persist/delete"), true)

    local loaded, err = storage.load_history("/test/persist/delete")
    MiniTest.expect.equality(loaded, nil)
    MiniTest.expect.equality(err ~= nil, true)
end

T["persistence"]["manager save_current and load round-trip through storage"] = function()
    history_manager.set_current_project("/test/persist/manager")
    history_manager.record_jump(
        { file_path = "/test/persist/manager/a.lua", position = { line = 1, column = 1 } },
        { file_path = "/test/persist/manager/b.lua", position = { line = 30, column = 4 } },
        "manual"
    )

    local saved = history_manager.save_current_project_history()
    MiniTest.expect.equality(saved, true)

    -- Drop in-memory state and reload from disk
    history_manager.clear_all_history()
    local loaded = history_manager.load_project_history("/test/persist/manager")
    MiniTest.expect.equality(loaded, true)

    MiniTest.expect.equality(history_manager.switch_to_project("/test/persist/manager"), true)
    local trail = history_manager.get_current_trail()
    MiniTest.expect.equality(#trail.entries, 1)
    MiniTest.expect.equality(trail.entries[1].position.line, 30)

    storage.delete_history("/test/persist/manager")
end

T["persistence"]["get_storage_stats reports the temporary directory"] = function()
    local stats = storage.get_storage_stats()
    MiniTest.expect.equality(type(stats), "table")
    MiniTest.expect.equality(type(stats.history_count), "number")
    MiniTest.expect.equality(type(stats.bookmark_count), "number")
    MiniTest.expect.equality(type(stats.total_size), "number")
    MiniTest.expect.equality(type(stats.storage_dir), "string")
    MiniTest.expect.equality(stats.storage_dir:find(persistence_temp_data_dir, 1, true) ~= nil, true)
end

-- Type layer validation shared across persistence and history modules
T["types"] = MiniTest.new_set()

T["types"]["navigation entry validation accepts and rejects"] = function()
    local entry = types.create_navigation_entry({
        file_path = "/test/file.lua",
        position = { line = 10, column = 5 },
    })
    local valid, err = types.validate_navigation_entry(entry)
    MiniTest.expect.equality(valid, true)
    MiniTest.expect.equality(err, nil)

    valid, err = types.validate_navigation_entry({ invalid = "data" })
    MiniTest.expect.equality(valid, false)
    MiniTest.expect.equality(err ~= nil, true)
end

T["types"]["navigation trail validation"] = function()
    local trail = types.create_navigation_trail({ project_root = "/test/project" })
    local valid, err = types.validate_navigation_trail(trail)
    MiniTest.expect.equality(valid, true)
    MiniTest.expect.equality(err, nil)
end

-- Setup wiring for the remaining integration modules should not error
T["module setup"] = MiniTest.new_set({
    hooks = {
        post_case = function() lsp.teardown() end,
    },
})

T["module setup"]["lsp integration setup is idempotent"] = function()
    local config = { integration = { lsp = true } }
    MiniTest.expect.no_error(function()
        lsp.setup(config)
        lsp.setup(config)
    end)
end

T["module setup"]["events system setup is idempotent"] = function()
    local config = {}
    MiniTest.expect.no_error(function()
        events.setup(config)
        events.setup(config)
    end)
end

T["module setup"]["statusline exposes branch status"] = function()
    statusline.setup({})
    local status = statusline.get_branch_status()
    if status ~= nil then MiniTest.expect.equality(type(status), "table") end
end

return T
