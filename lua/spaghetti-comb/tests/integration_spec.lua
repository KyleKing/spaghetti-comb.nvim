-- Integration tests exercising cross-module flows (child-process isolated)
local MiniTest = require("mini.test")

local child = MiniTest.new_child_neovim()

local child_preamble = [==[
  _G.history_manager = require("spaghetti-comb.history.manager")
  _G.storage = require("spaghetti-comb.history.storage")
  _G.breadcrumbs = require("spaghetti-comb.ui.breadcrumbs")
  _G.jumplist = require("spaghetti-comb.navigation.jumplist")
  _G.events = require("spaghetti-comb.navigation.events")
  _G.statusline = require("spaghetti-comb.ui.statusline")
  _G.lsp = require("spaghetti-comb.navigation.lsp")
  _G.types = require("spaghetti-comb.types")
  _G.debug_utils = require("spaghetti-comb.utils.debug")
]==]

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            child.lua(child_preamble)
        end,
        post_once = child.stop,
    },
})

-- Cross-module: history manager driving trails, breadcrumbs, and performance
T["cross-module"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.lua([==[
              history_manager.reset()
              history_manager.setup({})
              history_manager.clear_all_history()
            ]==])
        end,
    },
})

T["cross-module"]["project separation isolates trails"] = function()
    -- Fabricated paths have no project markers and are unreadable, so
    -- record_jump keeps the explicitly set project instead of auto-detecting.
    child.lua([==[
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
      _G.project1_trail = history_manager.get_or_create_project_trail("/project1")
      _G.project2_trail = history_manager.get_or_create_project_trail("/project2")
    ]==])

    MiniTest.expect.equality(child.lua_get([==[#_G.project1_trail.entries]==]), 1)
    MiniTest.expect.equality(child.lua_get([==[#_G.project2_trail.entries]==]), 1)
    MiniTest.expect.equality(child.lua_get([==[_G.project1_trail.entries[1].position.line]==]), 2)
    MiniTest.expect.equality(child.lua_get([==[_G.project2_trail.entries[1].position.line]==]), 20)

    MiniTest.expect.equality(child.lua_get([==[vim.tbl_count(history_manager.get_all_project_trails())]==]), 2)
end

T["cross-module"]["switching projects preserves per-project state"] = function()
    child.lua([==[
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
    ]==])

    -- Switch back to alpha and confirm its trail is intact and current
    MiniTest.expect.equality(child.lua_get([==[history_manager.switch_to_project("/proj/alpha")]==]), true)
    child.lua([==[_G.trail = history_manager.get_current_trail()]==])
    MiniTest.expect.equality(child.lua_get([==[_G.trail.project_root]==]), "/proj/alpha")
    MiniTest.expect.equality(child.lua_get([==[#_G.trail.entries]==]), 1)
    MiniTest.expect.equality(child.lua_get([==[_G.trail.entries[1].position.line]==]), 5)
end

T["cross-module"]["breadcrumbs render current trail from history manager"] = function()
    child.lua([==[
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
      _G.ok = breadcrumbs.show_on_hotkey()
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.ok]==]), true)
    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.is_visible()]==]), true)

    child.lua([==[
      _G.trail = history_manager.get_current_trail()
      _G.lines = breadcrumbs._build_breadcrumb_lines(_G.trail)
    ]==])
    MiniTest.expect.equality(child.lua_get([==[type(_G.lines)]==]), "table")
    -- The current (last) entry basename and line should appear in the crumb path
    MiniTest.expect.equality(child.lua_get([==[_G.lines[1]:find("three.lua:42", 1, true) ~= nil]==]), true)

    child.lua([==[breadcrumbs.hide()]==])
    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.is_visible()]==]), false)
end

T["cross-module"]["breadcrumbs report empty history gracefully"] = function()
    child.lua([==[
      breadcrumbs.setup({})
      breadcrumbs.reset()
      breadcrumbs.setup({})

      history_manager.set_current_project("/bc/empty")
      _G.res = { breadcrumbs.show_on_hotkey() }
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.res[1]]==]), false)
    MiniTest.expect.equality(child.lua_get([==[_G.res[2]]==]), "No navigation history")
    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.is_visible()]==]), false)
end

T["cross-module"]["records many jumps within time budget"] = function()
    child.lua([==[
      history_manager.set_current_project("/perf/project")
      local start_time = os.clock()
      for i = 1, 100 do
        history_manager.record_jump(
          { file_path = "/perf/file" .. i .. ".lua", position = { line = i, column = 1 } },
          { file_path = "/perf/file" .. (i + 1) .. ".lua", position = { line = i + 1, column = 1 } },
          "manual"
        )
      end
      _G.elapsed = os.clock() - start_time
      _G.trail = history_manager.get_current_trail()
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.elapsed < 1.0]==]), true)
    MiniTest.expect.equality(child.lua_get([==[#_G.trail.entries]==]), 100)
end

T["cross-module"]["clear_all_history releases every project trail"] = function()
    child.lua([==[
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
      _G.cleared = history_manager.clear_all_history()
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.cleared]==]), true)
    MiniTest.expect.equality(child.lua_get([==[vim.tbl_count(history_manager.get_all_project_trails())]==]), 0)
end

-- Jumplist integration: enhanced navigation built on the history backbone
T["jumplist"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.lua([==[
              debug_utils.setup({})
              history_manager.reset()
              history_manager.setup({})
              history_manager.clear_all_history()
            ]==])
        end,
    },
})

T["jumplist"]["setup is idempotent and non-erroring"] = function()
    MiniTest.expect.no_error(
        function()
            child.lua([==[
          local config = { integration = { jumplist = true } }
          jumplist.setup(config)
          jumplist.setup(config)
        ]==])
        end
    )
end

T["jumplist"]["exposes compatible jumplist access"] = function()
    MiniTest.expect.equality(child.lua_get([==[jumplist.check_jumplist_compatibility()]==]), true)

    child.lua([==[_G.info = jumplist.get_jumplist_info()]==])
    MiniTest.expect.equality(child.lua_get([==[type(_G.info)]==]), "table")
    MiniTest.expect.equality(child.lua_get([==[type(_G.info.total_entries)]==]), "number")
end

T["jumplist"]["back and forward move through the recorded trail"] = function()
    child.lua([==[
      history_manager.set_current_project("/jl/project")
      for i = 1, 4 do
        history_manager.record_jump(
          { file_path = "/jl/file" .. i .. ".lua", position = { line = i, column = 1 } },
          { file_path = "/jl/file" .. (i + 1) .. ".lua", position = { line = (i + 1) * 10, column = 1 } },
          "manual"
        )
      end
      _G.trail = history_manager.get_current_trail()
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.trail.current_index]==]), 4)

    child.lua([==[_G.back = { history_manager.go_back(2) }]==])
    MiniTest.expect.equality(child.lua_get([==[_G.back[1]]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.back[2].position.line]==]), 30)
    MiniTest.expect.equality(child.lua_get([==[history_manager.get_current_trail().current_index]==]), 2)

    child.lua([==[_G.fwd = { history_manager.go_forward(1) }]==])
    MiniTest.expect.equality(child.lua_get([==[_G.fwd[1]]==]), true)
    MiniTest.expect.equality(child.lua_get([==[history_manager.get_current_trail().current_index]==]), 3)
end

T["jumplist"]["jump_to_index moves the cursor to a real file location"] = function()
    child.lua([==[
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
      _G.cursor = vim.api.nvim_win_get_cursor(0)
      vim.fn.delete(temp_file)
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.cursor[1]]==]), 3)
end

-- Persistence round-trips isolated to a temporary data directory
T["persistence"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.lua([==[
              history_manager.reset()
              history_manager.setup({})
              _G.persistence_original_stdpath = vim.fn.stdpath
              _G.persistence_temp_data_dir = vim.fn.tempname()
              vim.fn.stdpath = function(what)
                if what == "data" then return _G.persistence_temp_data_dir end
                return _G.persistence_original_stdpath(what)
              end
            ]==])
        end,
        post_case = function()
            child.lua([==[
              if _G.persistence_original_stdpath then vim.fn.stdpath = _G.persistence_original_stdpath end
              if _G.persistence_temp_data_dir then vim.fn.delete(_G.persistence_temp_data_dir, "rf") end
              _G.persistence_temp_data_dir = nil
              _G.persistence_original_stdpath = nil
            ]==])
        end,
    },
})

T["persistence"]["save then load round-trips a trail"] = function()
    child.lua([==[
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
      _G.trail = trail
      _G.success = storage.save_history(trail, "/test/persist/project")
      _G.load = { storage.load_history("/test/persist/project") }
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.success]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.load[1] ~= nil]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.load[2]]==]), vim.NIL)
    MiniTest.expect.equality(
        child.lua_get([==[_G.load[1].project_root]==]),
        child.lua_get([==[_G.trail.project_root]==])
    )
    MiniTest.expect.equality(child.lua_get([==[#_G.load[1].entries]==]), 1)
    MiniTest.expect.equality(child.lua_get([==[_G.load[1].entries[1].position.line]==]), 42)
end

T["persistence"]["delete_history removes the saved trail"] = function()
    child.lua([==[
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
      _G.saved = storage.save_history(trail, "/test/persist/delete")
      _G.loaded_before = storage.load_history("/test/persist/delete")
      _G.deleted = storage.delete_history("/test/persist/delete")
      _G.after = { storage.load_history("/test/persist/delete") }
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.saved]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.loaded_before ~= nil]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.deleted]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.after[1]]==]), vim.NIL)
    MiniTest.expect.equality(child.lua_get([==[_G.after[2] ~= nil]==]), true)
end

T["persistence"]["manager save_current and load round-trip through storage"] = function()
    child.lua([==[
      history_manager.set_current_project("/test/persist/manager")
      history_manager.record_jump(
        { file_path = "/test/persist/manager/a.lua", position = { line = 1, column = 1 } },
        { file_path = "/test/persist/manager/b.lua", position = { line = 30, column = 4 } },
        "manual"
      )

      _G.saved = history_manager.save_current_project_history()

      -- Drop in-memory state and reload from disk
      history_manager.clear_all_history()
      _G.loaded = history_manager.load_project_history("/test/persist/manager")
      _G.switched = history_manager.switch_to_project("/test/persist/manager")
      _G.trail = history_manager.get_current_trail()
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.saved]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.loaded]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.switched]==]), true)
    MiniTest.expect.equality(child.lua_get([==[#_G.trail.entries]==]), 1)
    MiniTest.expect.equality(child.lua_get([==[_G.trail.entries[1].position.line]==]), 30)

    child.lua([==[storage.delete_history("/test/persist/manager")]==])
end

T["persistence"]["get_storage_stats reports the temporary directory"] = function()
    child.lua([==[_G.stats = storage.get_storage_stats()]==])

    MiniTest.expect.equality(child.lua_get([==[type(_G.stats)]==]), "table")
    MiniTest.expect.equality(child.lua_get([==[type(_G.stats.history_count)]==]), "number")
    MiniTest.expect.equality(child.lua_get([==[type(_G.stats.bookmark_count)]==]), "number")
    MiniTest.expect.equality(child.lua_get([==[type(_G.stats.total_size)]==]), "number")
    MiniTest.expect.equality(child.lua_get([==[type(_G.stats.storage_dir)]==]), "string")
    MiniTest.expect.equality(
        child.lua_get([==[_G.stats.storage_dir:find(_G.persistence_temp_data_dir, 1, true) ~= nil]==]),
        true
    )
end

-- Type layer validation shared across persistence and history modules
T["types"] = MiniTest.new_set()

T["types"]["navigation entry validation accepts and rejects"] = function()
    child.lua([==[
      local entry = types.create_navigation_entry({
        file_path = "/test/file.lua",
        position = { line = 10, column = 5 },
      })
      _G.valid_ok = { types.validate_navigation_entry(entry) }
      _G.valid_bad = { types.validate_navigation_entry({ invalid = "data" }) }
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.valid_ok[1]]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.valid_ok[2]]==]), vim.NIL)
    MiniTest.expect.equality(child.lua_get([==[_G.valid_bad[1]]==]), false)
    MiniTest.expect.equality(child.lua_get([==[_G.valid_bad[2] ~= nil]==]), true)
end

T["types"]["navigation trail validation"] = function()
    child.lua([==[
      local trail = types.create_navigation_trail({ project_root = "/test/project" })
      _G.valid = { types.validate_navigation_trail(trail) }
    ]==])
    MiniTest.expect.equality(child.lua_get([==[_G.valid[1]]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.valid[2]]==]), vim.NIL)
end

-- Setup wiring for the remaining integration modules should not error
T["module setup"] = MiniTest.new_set()

T["module setup"]["lsp integration setup is idempotent"] = function()
    MiniTest.expect.no_error(
        function()
            child.lua([==[
          local config = { integration = { lsp = true } }
          lsp.setup(config)
          lsp.setup(config)
        ]==])
        end
    )
end

T["module setup"]["events system setup is idempotent"] = function()
    MiniTest.expect.no_error(
        function()
            child.lua([==[
          local config = {}
          events.setup(config)
          events.setup(config)
        ]==])
        end
    )
end

T["module setup"]["statusline exposes branch status"] = function()
    child.lua([==[
      statusline.setup({})
      _G.status = statusline.get_branch_status()
    ]==])
    local status_type = child.lua_get([==[type(_G.status)]==])
    if status_type ~= "nil" then MiniTest.expect.equality(status_type, "table") end
end

return T
