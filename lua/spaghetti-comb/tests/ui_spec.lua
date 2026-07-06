-- UI component tests
local MiniTest = require("mini.test")
local breadcrumbs = require("spaghetti-comb.ui.breadcrumbs")
local floating_tree = require("spaghetti-comb.ui.floating_tree")
local preview = require("spaghetti-comb.ui.preview")
local picker = require("spaghetti-comb.ui.picker")
local statusline = require("spaghetti-comb.ui.statusline")
local history_manager = require("spaghetti-comb.history.manager")

local T = MiniTest.new_set()

-- Build a synthetic trail without opening any windows
local function make_trail()
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

-- Populate the history manager with a real trail so window-opening
-- functions have data to render
local function seed_history()
    history_manager.reset()
    history_manager.setup({})
    history_manager.set_current_project("/test/project")
    history_manager.record_jump(
        { file_path = "/test/project/alpha.lua", position = { line = 10, column = 1 } },
        { file_path = "/test/project/beta.lua", position = { line = 20, column = 3 } },
        "manual"
    )
end

-- Write a temporary source file for preview extraction tests
local function make_temp_file()
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

-- Breadcrumbs -----------------------------------------------------------------

T["breadcrumbs"] = MiniTest.new_set({
    hooks = {
        pre_case = function() breadcrumbs.setup({}) end,
        post_case = function()
            breadcrumbs.reset()
            history_manager.reset()
        end,
    },
})

T["breadcrumbs"]["setup records config and starts hidden"] = function()
    breadcrumbs.setup({ display = { max_items = 10, hotkey_only = true } })

    local state = breadcrumbs.get_state()
    MiniTest.expect.equality(type(state.config), "table")
    MiniTest.expect.equality(state.initialized, true)
    MiniTest.expect.equality(breadcrumbs.is_visible(), false)
end

T["breadcrumbs"]["show and hide toggles visibility"] = function()
    seed_history()

    local ok = breadcrumbs.show_on_hotkey()
    MiniTest.expect.equality(ok, true)
    MiniTest.expect.equality(breadcrumbs.is_visible(), true)

    local win = breadcrumbs.get_state().window
    MiniTest.expect.equality(vim.api.nvim_win_is_valid(win), true)

    breadcrumbs.hide()
    MiniTest.expect.equality(breadcrumbs.is_visible(), false)
    MiniTest.expect.equality(breadcrumbs.get_state().window, nil)
end

T["breadcrumbs"]["show_on_hotkey fails without history"] = function()
    history_manager.reset()
    history_manager.setup({})

    local ok, msg = breadcrumbs.show_on_hotkey()
    MiniTest.expect.equality(ok, false)
    MiniTest.expect.equality(type(msg), "string")
    MiniTest.expect.equality(breadcrumbs.is_visible(), false)
end

T["breadcrumbs"]["focus_item collapses unfocused entries"] = function()
    seed_history()
    breadcrumbs.configure_display_options({ collapse_unfocused = true })
    breadcrumbs.show_on_hotkey()

    local ok = breadcrumbs.focus_item(1)
    MiniTest.expect.equality(ok, true)
    MiniTest.expect.equality(breadcrumbs.get_state().focused_index, 1)

    -- Out-of-range focus is rejected
    MiniTest.expect.equality(breadcrumbs.focus_item(99), false)
end

T["breadcrumbs"]["build lines renders current marker and position"] = function()
    local lines = breadcrumbs._build_breadcrumb_lines(make_trail())
    MiniTest.expect.equality(type(lines), "table")

    local joined = table.concat(lines, "\n")
    MiniTest.expect.equality(joined:find("▶") ~= nil, true)
    MiniTest.expect.equality(joined:find("%[2/2%]") ~= nil, true)
end

T["breadcrumbs"]["set_highlight_groups defines groups"] = function()
    breadcrumbs.set_highlight_groups()
    local hl = vim.api.nvim_get_hl(0, { name = "SpaghettiCombBreadcrumbCurrent" })
    MiniTest.expect.equality(type(hl), "table")
    MiniTest.expect.equality(hl.bold, true)
end

-- Floating tree ---------------------------------------------------------------

T["floating tree"] = MiniTest.new_set({
    hooks = {
        pre_case = function() floating_tree.setup({}) end,
        post_case = function()
            floating_tree.reset()
            history_manager.reset()
        end,
    },
})

T["floating tree"]["setup starts hidden"] = function()
    floating_tree.setup({ visual = { use_unicode_tree = true } })
    MiniTest.expect.equality(floating_tree.is_visible(), false)
end

T["floating tree"]["renders unicode tree from trail"] = function()
    local lines = floating_tree.render_unicode_tree(make_trail())
    MiniTest.expect.equality(#lines, 2)

    local joined = table.concat(lines, "\n")
    -- Current entry marker and last-branch box char
    MiniTest.expect.equality(joined:find("▶") ~= nil, true)
    MiniTest.expect.equality(joined:find("└") ~= nil, true)
    -- Non-manual jump type is annotated
    MiniTest.expect.equality(joined:find("lsp_definition") ~= nil, true)
end

T["floating tree"]["render handles empty trail"] = function()
    local lines = floating_tree.render_unicode_tree({ entries = {}, current_index = 0 })
    MiniTest.expect.equality(lines, { "No navigation history" })
end

T["floating tree"]["show and hide toggles visibility"] = function()
    seed_history()

    local ok = floating_tree.show_branch_history()
    MiniTest.expect.equality(ok, true)
    MiniTest.expect.equality(floating_tree.is_visible(), true)

    local win = floating_tree.get_state().tree_window
    MiniTest.expect.equality(vim.api.nvim_win_is_valid(win), true)

    floating_tree.hide()
    MiniTest.expect.equality(floating_tree.is_visible(), false)
end

T["floating tree"]["vim motion selection clamps to range"] = function()
    seed_history()
    history_manager.record_jump(
        { file_path = "/test/project/beta.lua", position = { line = 20, column = 3 } },
        { file_path = "/test/project/gamma.lua", position = { line = 30, column = 1 } },
        "manual"
    )
    floating_tree.show_branch_history()

    -- Moving up past the top clamps at index 1
    floating_tree._move_selection(-10)
    MiniTest.expect.equality(floating_tree.get_state().selected_index, 1)

    -- Moving down past the end clamps at the last entry
    floating_tree._move_selection(10)
    MiniTest.expect.equality(floating_tree.get_state().selected_index, 2)

    floating_tree.hide()
end

-- Preview ---------------------------------------------------------------------

T["preview"] = MiniTest.new_set({
    hooks = {
        pre_case = function() preview.setup({}) end,
        post_case = function() preview.reset() end,
    },
})

T["preview"]["setup does not error"] = function()
    MiniTest.expect.no_error(function() preview.setup({}) end)
    MiniTest.expect.equality(preview.is_visible(), false)
end

T["preview"]["extracts code context around a line"] = function()
    local path = make_temp_file()
    local location = { file_path = path, position = { line = 3, column = 1 } }

    local context, err = preview.extract_code_context(location, 2)
    MiniTest.expect.equality(err, nil)
    MiniTest.expect.equality(context.target_line, 3)
    MiniTest.expect.equality(context.start_line, 1)
    MiniTest.expect.equality(context.end_line, 5)

    -- The target line is flagged
    local target
    for _, info in ipairs(context.lines) do
        if info.is_target then target = info end
    end
    MiniTest.expect.equality(target.line_num, 3)
    MiniTest.expect.equality(target.content, "    return 42")

    vim.fn.delete(path)
end

T["preview"]["extract fails for unreadable file"] = function()
    local context, err = preview.extract_code_context({ file_path = "/no/such/file.lua", position = { line = 1 } })
    MiniTest.expect.equality(context, nil)
    MiniTest.expect.equality(type(err), "string")
end

T["preview"]["show_preview opens a window with context"] = function()
    local path = make_temp_file()
    local ok, ctx = preview.show_preview(
        { file_path = path, position = { line = 3, column = 1 } },
        { context_lines = 2 }
    )

    MiniTest.expect.equality(ok, true)
    MiniTest.expect.equality(ctx.target_line, 3)
    MiniTest.expect.equality(preview.is_visible(), true)

    preview.hide_preview()
    MiniTest.expect.equality(preview.is_visible(), false)

    vim.fn.delete(path)
end

-- Picker ----------------------------------------------------------------------

T["picker"] = MiniTest.new_set({
    hooks = {
        pre_case = function() picker.setup({}) end,
        post_case = function()
            picker.reset()
            history_manager.reset()
        end,
    },
})

T["picker"]["setup detects mini.pick availability"] = function()
    picker.setup({ integration = { mini_pick = true } })
    MiniTest.expect.equality(type(picker.is_using_mini_pick()), "boolean")
end

T["picker"]["sort_by_frecency orders manual before frequent"] = function()
    local bookmarks = {
        { is_manual = false, visit_count = 5 },
        { is_manual = true, visit_count = 1 },
        { is_manual = false, visit_count = 9 },
    }
    picker.sort_by_frecency(bookmarks)

    -- Manual bookmark floats to the top
    MiniTest.expect.equality(bookmarks[1].is_manual, true)
    -- Remaining sorted by descending visit count
    MiniTest.expect.equality(bookmarks[2].visit_count, 9)
    MiniTest.expect.equality(bookmarks[3].visit_count, 5)
end

T["picker"]["sort_by_recency orders newest first"] = function()
    local entries = {
        { timestamp = 100 },
        { timestamp = 300 },
        { timestamp = 200 },
    }
    local sorted = picker.sort_by_recency(entries)
    MiniTest.expect.equality(sorted[1].timestamp, 300)
    MiniTest.expect.equality(sorted[3].timestamp, 100)
end

T["picker"]["filter_navigation_entries matches filename"] = function()
    local entries = {
        { file_path = "/a/alpha.lua", position = { line = 1 } },
        { file_path = "/a/beta.lua", position = { line = 1 } },
    }
    local filtered = picker.filter_navigation_entries(entries, "alpha")
    MiniTest.expect.equality(#filtered, 1)
    MiniTest.expect.equality(filtered[1].file_path, "/a/alpha.lua")

    -- Empty query returns all entries
    MiniTest.expect.equality(#picker.filter_navigation_entries(entries, ""), 2)
end

T["picker"]["navigation mode fails without history"] = function()
    history_manager.reset()
    history_manager.setup({})

    local ok, msg = picker.show_navigation_mode()
    MiniTest.expect.equality(ok, false)
    MiniTest.expect.equality(type(msg), "string")
    MiniTest.expect.equality(picker.get_current_mode(), "navigation")
end

-- Statusline ------------------------------------------------------------------

T["statusline"] = MiniTest.new_set({
    hooks = {
        pre_case = function() statusline.setup({}) end,
        post_case = function()
            statusline.reset()
            history_manager.reset()
        end,
    },
})

T["statusline"]["setup does not error"] = function()
    MiniTest.expect.no_error(function() statusline.setup({ integration = { statusline = true } }) end)
end

T["statusline"]["branch status is nil without navigation"] = function()
    history_manager.reset()
    history_manager.setup({})
    MiniTest.expect.equality(statusline.get_branch_status(), nil)
end

T["statusline"]["branch status reports depth and total"] = function()
    seed_history()
    local status = statusline.get_branch_status()
    MiniTest.expect.equality(type(status), "table")
    MiniTest.expect.equality(status.total, 1)
    MiniTest.expect.equality(status.depth, 1)
end

T["statusline"]["format helpers produce indicators"] = function()
    local active = statusline.format_active_exploration("abcdef1234567890", 2, 5)
    MiniTest.expect.equality(active:find("abcdef12") ~= nil, true)
    MiniTest.expect.equality(active:find("2/5") ~= nil, true)

    MiniTest.expect.equality(type(statusline.format_idle_indicator()), "string")
end

T["statusline"]["minimal display empty when integration disabled"] = function()
    statusline.setup({})
    MiniTest.expect.equality(statusline.get_minimal_display_string(), "")
end

return T
