-- UI component tests (child-process isolated)
local MiniTest = require("mini.test")

local child = MiniTest.new_child_neovim()

local child_preamble = [==[
  _G.breadcrumbs = require("spaghetti-comb.ui.breadcrumbs")
  _G.floating_tree = require("spaghetti-comb.ui.floating_tree")
  _G.preview = require("spaghetti-comb.ui.preview")
  _G.picker = require("spaghetti-comb.ui.picker")
  _G.statusline = require("spaghetti-comb.ui.statusline")
  _G.history_manager = require("spaghetti-comb.history.manager")

  function _G.make_trail()
    return {
      current_index = 2,
      project_root = "/test/project",
      branches = { current = "main-branch-1234" },
      entries = {
        {
          file_path = "/test/project/alpha.lua",
          position = { line = 10, column = 1 },
          jump_type = "manual",
          timestamp = os.time() - 120,
        },
        {
          file_path = "/test/project/beta.lua",
          position = { line = 20, column = 3 },
          jump_type = "lsp_definition",
          timestamp = os.time(),
          is_bookmarked = true,
        },
      },
    }
  end

  function _G.seed_history()
    history_manager.reset()
    history_manager.setup({})
    history_manager.set_current_project("/test/project")
    history_manager.record_jump(
      { file_path = "/test/project/alpha.lua", position = { line = 10, column = 1 } },
      { file_path = "/test/project/beta.lua", position = { line = 20, column = 3 } },
      "manual"
    )
  end

  function _G.make_temp_file()
    local path = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({
      "local M = {}",
      "function M.target()",
      "    return 42",
      "end",
      "return M",
    }, path)
    return path
  end
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

-- Breadcrumbs -----------------------------------------------------------------

T["breadcrumbs"] = MiniTest.new_set({
    hooks = {
        pre_case = function() child.lua([==[breadcrumbs.setup({})]==]) end,
    },
})

T["breadcrumbs"]["setup records config and starts hidden"] = function()
    child.lua([==[breadcrumbs.setup({ display = { max_items = 10, hotkey_only = true } })]==])

    MiniTest.expect.equality(child.lua_get([==[type(breadcrumbs.get_state().config)]==]), "table")
    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.get_state().initialized]==]), true)
    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.is_visible()]==]), false)
end

T["breadcrumbs"]["show and hide toggles visibility"] = function()
    child.lua([==[seed_history()]==])

    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.show_on_hotkey()]==]), true)
    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.is_visible()]==]), true)
    MiniTest.expect.equality(child.lua_get([==[vim.api.nvim_win_is_valid(breadcrumbs.get_state().window)]==]), true)

    child.lua([==[breadcrumbs.hide()]==])
    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.is_visible()]==]), false)
    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.get_state().window]==]), vim.NIL)
end

T["breadcrumbs"]["show_on_hotkey fails without history"] = function()
    child.lua([==[history_manager.reset(); history_manager.setup({}); _G.res = { breadcrumbs.show_on_hotkey() }]==])

    MiniTest.expect.equality(child.lua_get([==[_G.res[1]]==]), false)
    MiniTest.expect.equality(child.lua_get([==[type(_G.res[2])]==]), "string")
    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.is_visible()]==]), false)
end

T["breadcrumbs"]["focus_item collapses unfocused entries"] = function()
    child.lua([==[
      seed_history()
      breadcrumbs.configure_display_options({ collapse_unfocused = true })
      breadcrumbs.show_on_hotkey()
    ]==])

    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.focus_item(1)]==]), true)
    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.get_state().focused_index]==]), 1)

    -- Out-of-range focus is rejected
    MiniTest.expect.equality(child.lua_get([==[breadcrumbs.focus_item(99)]==]), false)
end

T["breadcrumbs"]["build lines renders current marker and position"] = function()
    child.lua([==[_G.lines = breadcrumbs._build_breadcrumb_lines(make_trail())]==])
    MiniTest.expect.equality(child.lua_get([==[type(_G.lines)]==]), "table")

    MiniTest.expect.equality(child.lua_get([==[table.concat(_G.lines, "\n"):find("▶") ~= nil]==]), true)
    MiniTest.expect.equality(child.lua_get([==[table.concat(_G.lines, "\n"):find("%[2/2%]") ~= nil]==]), true)
end

T["breadcrumbs"]["set_highlight_groups defines groups"] = function()
    child.lua([==[breadcrumbs.set_highlight_groups()]==])
    MiniTest.expect.equality(
        child.lua_get([==[type(vim.api.nvim_get_hl(0, { name = "SpaghettiCombBreadcrumbCurrent" }))]==]),
        "table"
    )
    MiniTest.expect.equality(
        child.lua_get([==[vim.api.nvim_get_hl(0, { name = "SpaghettiCombBreadcrumbCurrent" }).bold]==]),
        true
    )
end

-- Floating tree ---------------------------------------------------------------

T["floating tree"] = MiniTest.new_set({
    hooks = {
        pre_case = function() child.lua([==[floating_tree.setup({})]==]) end,
    },
})

T["floating tree"]["setup starts hidden"] = function()
    child.lua([==[floating_tree.setup({ visual = { use_unicode_tree = true } })]==])
    MiniTest.expect.equality(child.lua_get([==[floating_tree.is_visible()]==]), false)
end

T["floating tree"]["renders unicode tree from trail"] = function()
    child.lua([==[_G.lines = floating_tree.render_unicode_tree(make_trail())]==])
    MiniTest.expect.equality(child.lua_get([==[#_G.lines]==]), 2)

    -- Current entry marker and last-branch box char
    MiniTest.expect.equality(child.lua_get([==[table.concat(_G.lines, "\n"):find("▶") ~= nil]==]), true)
    MiniTest.expect.equality(child.lua_get([==[table.concat(_G.lines, "\n"):find("└") ~= nil]==]), true)
    -- Non-manual jump type is annotated
    MiniTest.expect.equality(child.lua_get([==[table.concat(_G.lines, "\n"):find("lsp_definition") ~= nil]==]), true)
end

T["floating tree"]["render handles empty trail"] = function()
    local lines = child.lua_get([==[floating_tree.render_unicode_tree({ entries = {}, current_index = 0 })]==])
    MiniTest.expect.equality(lines, { "No navigation history" })
end

T["floating tree"]["show and hide toggles visibility"] = function()
    child.lua([==[seed_history()]==])

    MiniTest.expect.equality(child.lua_get([==[floating_tree.show_branch_history()]==]), true)
    MiniTest.expect.equality(child.lua_get([==[floating_tree.is_visible()]==]), true)
    MiniTest.expect.equality(
        child.lua_get([==[vim.api.nvim_win_is_valid(floating_tree.get_state().tree_window)]==]),
        true
    )

    child.lua([==[floating_tree.hide()]==])
    MiniTest.expect.equality(child.lua_get([==[floating_tree.is_visible()]==]), false)
end

T["floating tree"]["vim motion selection clamps to range"] = function()
    child.lua([==[
      seed_history()
      history_manager.record_jump(
        { file_path = "/test/project/beta.lua", position = { line = 20, column = 3 } },
        { file_path = "/test/project/gamma.lua", position = { line = 30, column = 1 } },
        "manual"
      )
      floating_tree.show_branch_history()
    ]==])

    -- Moving up past the top clamps at index 1
    child.lua([==[floating_tree._move_selection(-10)]==])
    MiniTest.expect.equality(child.lua_get([==[floating_tree.get_state().selected_index]==]), 1)

    -- Moving down past the end clamps at the last entry
    child.lua([==[floating_tree._move_selection(10)]==])
    MiniTest.expect.equality(child.lua_get([==[floating_tree.get_state().selected_index]==]), 2)

    child.lua([==[floating_tree.hide()]==])
end

-- Preview ---------------------------------------------------------------------

T["preview"] = MiniTest.new_set({
    hooks = {
        pre_case = function() child.lua([==[preview.setup({})]==]) end,
    },
})

T["preview"]["setup does not error"] = function()
    MiniTest.expect.no_error(function() child.lua([==[preview.setup({})]==]) end)
    MiniTest.expect.equality(child.lua_get([==[preview.is_visible()]==]), false)
end

T["preview"]["extracts code context around a line"] = function()
    child.lua([==[
      _G.path = make_temp_file()
      _G.res = { preview.extract_code_context({ file_path = _G.path, position = { line = 3, column = 1 } }, 2) }
      _G.context = _G.res[1]
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.res[2]]==]), vim.NIL)
    MiniTest.expect.equality(child.lua_get([==[_G.context.target_line]==]), 3)
    MiniTest.expect.equality(child.lua_get([==[_G.context.start_line]==]), 1)
    MiniTest.expect.equality(child.lua_get([==[_G.context.end_line]==]), 5)

    -- The target line is flagged
    child.lua([==[
      _G.target = nil
      for _, info in ipairs(_G.context.lines) do
        if info.is_target then _G.target = info end
      end
    ]==])
    MiniTest.expect.equality(child.lua_get([==[_G.target.line_num]==]), 3)
    MiniTest.expect.equality(child.lua_get([==[_G.target.content]==]), "    return 42")

    child.lua([==[vim.fn.delete(_G.path)]==])
end

T["preview"]["extract fails for unreadable file"] = function()
    child.lua([==[
      _G.res = { preview.extract_code_context({ file_path = "/no/such/file.lua", position = { line = 1 } }) }
    ]==])
    MiniTest.expect.equality(child.lua_get([==[_G.res[1]]==]), vim.NIL)
    MiniTest.expect.equality(child.lua_get([==[type(_G.res[2])]==]), "string")
end

T["preview"]["show_preview opens a window with context"] = function()
    child.lua([==[
      _G.path = make_temp_file()
      _G.res = { preview.show_preview(
        { file_path = _G.path, position = { line = 3, column = 1 } },
        { context_lines = 2 }
      ) }
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.res[1]]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.res[2].target_line]==]), 3)
    MiniTest.expect.equality(child.lua_get([==[preview.is_visible()]==]), true)

    child.lua([==[preview.hide_preview()]==])
    MiniTest.expect.equality(child.lua_get([==[preview.is_visible()]==]), false)

    child.lua([==[vim.fn.delete(_G.path)]==])
end

-- Picker ----------------------------------------------------------------------

T["picker"] = MiniTest.new_set({
    hooks = {
        pre_case = function() child.lua([==[picker.setup({})]==]) end,
    },
})

T["picker"]["setup detects mini.pick availability"] = function()
    child.lua([==[picker.setup({ integration = { mini_pick = true } })]==])
    MiniTest.expect.equality(child.lua_get([==[type(picker.is_using_mini_pick())]==]), "boolean")
end

T["picker"]["sort_by_frecency orders manual before frequent"] = function()
    child.lua([==[
      _G.bookmarks = {
        { is_manual = false, visit_count = 5 },
        { is_manual = true, visit_count = 1 },
        { is_manual = false, visit_count = 9 },
      }
      picker.sort_by_frecency(_G.bookmarks)
    ]==])

    -- Manual bookmark floats to the top
    MiniTest.expect.equality(child.lua_get([==[_G.bookmarks[1].is_manual]==]), true)
    -- Remaining sorted by descending visit count
    MiniTest.expect.equality(child.lua_get([==[_G.bookmarks[2].visit_count]==]), 9)
    MiniTest.expect.equality(child.lua_get([==[_G.bookmarks[3].visit_count]==]), 5)
end

T["picker"]["sort_by_recency orders newest first"] = function()
    child.lua([==[
      _G.sorted = picker.sort_by_recency({ { timestamp = 100 }, { timestamp = 300 }, { timestamp = 200 } })
    ]==])
    MiniTest.expect.equality(child.lua_get([==[_G.sorted[1].timestamp]==]), 300)
    MiniTest.expect.equality(child.lua_get([==[_G.sorted[3].timestamp]==]), 100)
end

T["picker"]["filter_navigation_entries matches filename"] = function()
    child.lua([==[
      _G.entries = {
        { file_path = "/a/alpha.lua", position = { line = 1 } },
        { file_path = "/a/beta.lua", position = { line = 1 } },
      }
      _G.filtered = picker.filter_navigation_entries(_G.entries, "alpha")
    ]==])
    MiniTest.expect.equality(child.lua_get([==[#_G.filtered]==]), 1)
    MiniTest.expect.equality(child.lua_get([==[_G.filtered[1].file_path]==]), "/a/alpha.lua")

    -- Empty query returns all entries
    MiniTest.expect.equality(child.lua_get([==[#picker.filter_navigation_entries(_G.entries, "")]==]), 2)
end

T["picker"]["navigation mode fails without history"] = function()
    child.lua([==[
      history_manager.reset()
      history_manager.setup({})
      _G.res = { picker.show_navigation_mode() }
    ]==])

    MiniTest.expect.equality(child.lua_get([==[_G.res[1]]==]), false)
    MiniTest.expect.equality(child.lua_get([==[type(_G.res[2])]==]), "string")
    MiniTest.expect.equality(child.lua_get([==[picker.get_current_mode()]==]), "navigation")
end

-- Statusline ------------------------------------------------------------------

T["statusline"] = MiniTest.new_set({
    hooks = {
        pre_case = function() child.lua([==[statusline.setup({})]==]) end,
    },
})

T["statusline"]["setup does not error"] = function()
    MiniTest.expect.no_error(
        function() child.lua([==[statusline.setup({ integration = { statusline = true } })]==]) end
    )
end

T["statusline"]["branch status is nil without navigation"] = function()
    child.lua([==[history_manager.reset(); history_manager.setup({})]==])
    MiniTest.expect.equality(child.lua_get([==[statusline.get_branch_status()]==]), vim.NIL)
end

T["statusline"]["branch status reports depth and total"] = function()
    child.lua([==[seed_history()]==])
    MiniTest.expect.equality(child.lua_get([==[type(statusline.get_branch_status())]==]), "table")
    MiniTest.expect.equality(child.lua_get([==[statusline.get_branch_status().total]==]), 1)
    MiniTest.expect.equality(child.lua_get([==[statusline.get_branch_status().depth]==]), 1)
end

T["statusline"]["format helpers produce indicators"] = function()
    child.lua([==[_G.active = statusline.format_active_exploration("abcdef1234567890", 2, 5)]==])
    MiniTest.expect.equality(child.lua_get([==[_G.active:find("abcdef12") ~= nil]==]), true)
    MiniTest.expect.equality(child.lua_get([==[_G.active:find("2/5") ~= nil]==]), true)

    MiniTest.expect.equality(child.lua_get([==[type(statusline.format_idle_indicator())]==]), "string")
end

T["statusline"]["minimal display empty when integration disabled"] = function()
    child.lua([==[statusline.setup({})]==])
    MiniTest.expect.equality(child.lua_get([==[statusline.get_minimal_display_string()]==]), "")
end

return T
