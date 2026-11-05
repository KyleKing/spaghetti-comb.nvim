-- Integration tests exercising cross-module flows (child-process isolated)
local MiniTest = require("mini.test")

local child = MiniTest.new_child_neovim()

local child_preamble = [==[
  _G.history_manager = require("spaghetti-comb.history.manager")
  _G.storage = require("spaghetti-comb.history.storage")
  _G.breadcrumbs = require("spaghetti-comb.ui.breadcrumbs")
  _G.jumplist = require("spaghetti-comb.navigation.jumplist")
  _G.types = require("spaghetti-comb.types")
  _G.debug_utils = require("spaghetti-comb.utils.debug")
  _G.project = require("spaghetti-comb.utils.project")
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

T["cross-module"]["project separation isolates and restores trails"] = function()
    -- Fabricated paths have no project markers, so detection falls back to the
    -- containing directory — which is the explicitly set project here.
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

    -- Switching back restores the first project's trail
    MiniTest.expect.equality(child.lua_get([==[history_manager.switch_to_project("/project1")]==]), true)
    child.lua([==[_G.trail = history_manager.get_current_trail()]==])
    MiniTest.expect.equality(child.lua_get([==[_G.trail.project_root]==]), "/project1")
    MiniTest.expect.equality(child.lua_get([==[#_G.trail.entries]==]), 1)
    MiniTest.expect.equality(child.lua_get([==[_G.trail.entries[1].position.line]==]), 2)
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

T["persistence"]["save, load, and delete round-trip a trail"] = function()
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
      _G.success = storage.save_history(trail, "/test/persist/project")
      _G.load = { storage.load_history("/test/persist/project") }
      _G.deleted = storage.delete_history("/test/persist/project")
      _G.after = { storage.load_history("/test/persist/project") }
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.success]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.load[1] ~= nil]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.load[2]]==]), vim.NIL)
    MiniTest.expect.equality(child.lua_get([==[_G.load[1].project_root]==]), "/test/persist/project")
    MiniTest.expect.equality(child.lua_get([==[#_G.load[1].entries]==]), 1)
    MiniTest.expect.equality(child.lua_get([==[_G.load[1].entries[1].position.line]==]), 42)

    MiniTest.expect.equality(child.lua_get([==[_G.deleted]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.after[1]]==]), vim.NIL)
    MiniTest.expect.equality(child.lua_get([==[_G.after[2] ~= nil]==]), true)
end

T["persistence"]["load drops malformed entries and keeps the valid ones"] = function()
    child.lua([==[
      local trail = types.create_navigation_trail({
        project_root = "/test/persist/corrupt",
        entries = {
          types.create_navigation_entry({ file_path = "/a/one.lua", position = { line = 1, column = 1 } }),
          { id = "bad", file_path = 42, position = { line = 1, column = 1 } },
          types.create_navigation_entry({ file_path = "/a/two.lua", position = { line = 2, column = 2 } }),
          { id = "worse" },
        },
        current_index = 4,
      })
      storage.save_history(trail, "/test/persist/corrupt")
      _G.notifies = {}
      local real_notify = vim.notify
      vim.notify = function(msg, level) table.insert(_G.notifies, { msg = msg, level = level }) end
      _G.loaded = { storage.load_history("/test/persist/corrupt") }
      vim.notify = real_notify
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.loaded[1] ~= nil]==]), true)
    MiniTest.expect.equality(child.lua_get([==[#_G.loaded[1].entries]==]), 2)
    MiniTest.expect.equality(child.lua_get([==[_G.loaded[1].entries[1].file_path]==]), "/a/one.lua")
    MiniTest.expect.equality(child.lua_get([==[_G.loaded[1].entries[2].file_path]==]), "/a/two.lua")
    -- current_index is clamped to the surviving entries
    MiniTest.expect.equality(child.lua_get([==[_G.loaded[1].current_index]==]), 2)

    -- A single WARN notification reports the dropped count
    MiniTest.expect.equality(child.lua_get([==[#_G.notifies]==]), 1)
    MiniTest.expect.equality(child.lua_get([==[_G.notifies[1].level]==]), vim.log.levels.WARN)
    MiniTest.expect.equality(child.lua_get([==[_G.notifies[1].msg:find("2") ~= nil]==]), true)
end

T["persistence"]["corrupt JSON reports a load error instead of a trail"] = function()
    child.lua([==[
      local dir = _G.persistence_temp_data_dir .. "/spaghetti-comb/history"
      vim.fs.mkdir(dir, { parents = true })
      local file = io.open(dir .. "/_test_persist_broken.json", "w")
      file:write("{ this is not json")
      file:close()
      _G.broken = { storage.load_history("/test/persist/broken") }
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.broken[1]]==]), vim.NIL)
    MiniTest.expect.equality(child.lua_get([==[type(_G.broken[2])]==]), "string")
end

T["persistence"]["large trail round-trips through storage"] = function()
    child.lua([==[
      local entries = {}
      for i = 1, 600 do
        entries[i] = types.create_navigation_entry({
          file_path = "/test/big/file" .. (i % 25) .. ".lua",
          position = { line = i, column = (i % 80) + 1 },
          jump_type = "manual",
          timestamp = 1700000000 + i,
          is_bookmarked = i % 100 == 0,
        })
      end
      local trail = types.create_navigation_trail({
        project_root = "/test/big",
        entries = entries,
        current_index = 600,
      })
      _G.saved = storage.save_history(trail, "/test/big")
      _G.loaded = { storage.load_history("/test/big") }
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.saved]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.loaded[1] ~= nil]==]), true)
    MiniTest.expect.equality(child.lua_get([==[#_G.loaded[1].entries]==]), 600)
    MiniTest.expect.equality(child.lua_get([==[_G.loaded[1].current_index]==]), 600)
    MiniTest.expect.equality(child.lua_get([==[_G.loaded[1].entries[1].file_path]==]), "/test/big/file1.lua")
    MiniTest.expect.equality(child.lua_get([==[_G.loaded[1].entries[600].position.line]==]), 600)
    MiniTest.expect.equality(child.lua_get([==[_G.loaded[1].entries[600].is_bookmarked]==]), true)
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

T["project root"] = MiniTest.new_set()

-- Markers rank equally, so the nearest ancestor holding any of them wins.
T["project root"]["picks the nearest marker, not the highest-ranked one"] = function()
    local root = vim.fn.tempname()
    vim.fs.mkdir(root .. "/outer/inner/sub", { parents = true })
    vim.fs.mkdir(root .. "/outer/.git", { parents = true })
    vim.fn.writefile({ "{}" }, root .. "/outer/inner/package.json")
    vim.fn.writefile({ "" }, root .. "/outer/inner/sub/file.lua")

    child.lua("_G.project.clear_cache()")
    local detected = child.lua_get("_G.project.detect_project_root(...)", { root .. "/outer/inner/sub/file.lua" })

    MiniTest.expect.equality(detected, vim.fs.abspath(root .. "/outer/inner"))
    vim.fn.delete(root, "rf")
end

-- With no markers anywhere (plain dir, tarball checkout), the containing
-- directory is the project — detection never errors or returns nil.
T["project root"]["falls back to the containing directory without markers"] = function()
    local root = vim.fn.tempname()
    vim.fs.mkdir(root .. "/plain/sub", { parents = true })
    vim.fn.writefile({ "x = 1" }, root .. "/plain/sub/file.lua")

    child.lua("_G.project.clear_cache()")
    local detected = child.lua_get("_G.project.detect_project_root(...)", { root .. "/plain/sub/file.lua" })
    MiniTest.expect.equality(detected, vim.fs.abspath(root .. "/plain/sub"))

    -- A file not yet written to disk still resolves to its directory
    child.lua("_G.project.clear_cache()")
    detected = child.lua_get("_G.project.detect_project_root(...)", { root .. "/plain/sub/not_written.lua" })
    MiniTest.expect.equality(detected, vim.fs.abspath(root .. "/plain/sub"))

    -- A directory path resolves to itself
    child.lua("_G.project.clear_cache()")
    detected = child.lua_get("_G.project.detect_project_root(...)", { root .. "/plain/sub" })
    MiniTest.expect.equality(detected, vim.fs.abspath(root .. "/plain/sub"))

    vim.fn.delete(root, "rf")
end

return T
