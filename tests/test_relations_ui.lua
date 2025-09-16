local MiniTest = require("mini.test")
local new_set = MiniTest.new_set

local T = new_set({
    hooks = {
        pre_case = function()
            vim.cmd("silent! %bwipeout!")
            require("spaghetti-comb-v1").setup({})
        end,
        post_case = function()
            vim.cmd("silent! %bwipeout!")
            local floating = require("spaghetti-comb-v1.ui.relations")
            if floating.is_visible() then floating.close_relations() end
        end,
    },
})

local floating = require("spaghetti-comb-v1.ui.relations")
local navigation = require("spaghetti-comb-v1.navigation")

T["floating_ui"] = new_set()

T["floating_ui"]["create_split_window"] = function()
    local win_id, buf_id = floating.create_split_window()

    MiniTest.expect.equality(type(win_id), "number")
    MiniTest.expect.equality(type(buf_id), "number")
    MiniTest.expect.equality(vim.api.nvim_win_is_valid(win_id), true)
    MiniTest.expect.equality(vim.api.nvim_buf_is_valid(buf_id), true)
    MiniTest.expect.equality(floating.is_visible(), true)
end

T["floating_ui"]["show_relations with data"] = function()
    local mock_data = {
        method = "textDocument/references",
        locations = {
            {
                uri = "file:///test.lua",
                path = "/test.lua",
                relative_path = "test.lua",
                line = 1,
                col = 1,
                text = "test function",
                type = "location",
                range = {
                    start = { line = 0, character = 0 },
                    ["end"] = { line = 0, character = 10 },
                },
            },
        },
    }

    navigation.push({
        text = "test_symbol",
        line = 0,
        col = 0,
        bufnr = vim.api.nvim_get_current_buf(),
    })

    navigation.update_current_entry({ references = mock_data.locations })

    MiniTest.expect.no_error(function() floating.show_relations(mock_data) end)

    MiniTest.expect.equality(floating.is_visible(), true)
end

T["floating_ui"]["close_relations"] = function()
    floating.create_split_window()
    MiniTest.expect.equality(floating.is_visible(), true)

    floating.close_relations()
    MiniTest.expect.equality(floating.is_visible(), false)
end

T["floating_ui"]["toggle_relations"] = function()
    MiniTest.expect.equality(floating.is_visible(), false)

    local temp_file = vim.fn.tempname() .. ".lua"
    vim.cmd("edit " .. temp_file)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "function test() end" })
    vim.api.nvim_win_set_cursor(0, { 1, 10 })

    MiniTest.expect.no_error(function() floating.toggle_relations() end)
end

T["floating_ui"]["get_selected_item"] = function()
    local mock_locations = {
        {
            uri = "file:///test.lua",
            path = "/test.lua",
            relative_path = "test.lua",
            line = 1,
            col = 1,
            text = "test function",
            type = "location",
        },
    }

    navigation.push({
        text = "test_symbol",
        line = 0,
        col = 0,
        bufnr = vim.api.nvim_get_current_buf(),
    })

    navigation.update_current_entry({ references = mock_locations })

    floating.show_relations({ locations = mock_locations })

    vim.api.nvim_win_set_cursor(floating.create_split_window(), { 3, 0 })

    local item = floating.get_selected_item()
end

T["floating_ui"]["navigate_to_selected"] = function()
    local temp_file = vim.fn.tempname() .. ".lua"
    vim.fn.writefile({ "function test() end" }, temp_file)

    local mock_locations = {
        {
            uri = "file://" .. temp_file,
            path = temp_file,
            relative_path = vim.fn.fnamemodify(temp_file, ":t"),
            line = 1,
            col = 1,
            text = "test function",
            type = "location",
        },
    }

    navigation.push({
        text = "test_symbol",
        line = 0,
        col = 0,
        bufnr = vim.api.nvim_get_current_buf(),
    })

    navigation.update_current_entry({ references = mock_locations })

    floating.show_relations({ locations = mock_locations })

    MiniTest.expect.no_error(function() floating.navigate_to_selected() end)

    vim.fn.delete(temp_file)
end

T["floating_ui"]["toggle_bookmark"] = function()
    local mock_locations = {
        {
            uri = "file:///test.lua",
            path = "/test.lua",
            relative_path = "test.lua",
            line = 1,
            col = 1,
            text = "test function",
            type = "location",
            bookmarked = false,
        },
    }

    navigation.push({
        text = "test_symbol",
        line = 0,
        col = 0,
        bufnr = vim.api.nvim_get_current_buf(),
    })

    navigation.update_current_entry({ references = mock_locations })

    floating.show_relations({ locations = mock_locations })

    MiniTest.expect.no_error(function() floating.toggle_bookmark() end)
end

T["floating_ui"]["show_coupling_metrics"] = function()
    local mock_locations = {
        {
            uri = "file:///test.lua",
            path = "/test.lua",
            relative_path = "test.lua",
            line = 1,
            col = 1,
            text = "test function",
            type = "location",
            coupling_score = 0.75,
        },
    }

    navigation.push({
        text = "test_symbol",
        line = 0,
        col = 0,
        bufnr = vim.api.nvim_get_current_buf(),
    })

    navigation.update_current_entry({ references = mock_locations })

    floating.show_relations({ locations = mock_locations })

    MiniTest.expect.no_error(function() floating.show_coupling_metrics() end)
end

T["floating_ui"]["refresh_content"] = function()
    floating.create_split_window()

    MiniTest.expect.no_error(function() floating.refresh_content() end)
end

T["floating_ui"]["toggle_focus_mode"] = function()
    floating.create_split_window()
    MiniTest.expect.equality(floating.is_focused(), false)

    MiniTest.expect.no_error(function() floating.toggle_focus_mode() end)
    MiniTest.expect.equality(floating.is_focused(), true)

    MiniTest.expect.no_error(function() floating.toggle_focus_mode() end)
    MiniTest.expect.equality(floating.is_focused(), false)
end

T["floating_ui"]["enter_focus_mode"] = function()
    floating.create_split_window()
    MiniTest.expect.equality(floating.is_focused(), false)

    MiniTest.expect.no_error(function() floating.enter_focus_mode() end)
    MiniTest.expect.equality(floating.is_focused(), true)
end

T["floating_ui"]["exit_focus_mode"] = function()
    floating.create_split_window()
    floating.enter_focus_mode()
    MiniTest.expect.equality(floating.is_focused(), true)

    MiniTest.expect.no_error(function() floating.exit_focus_mode() end)
    MiniTest.expect.equality(floating.is_focused(), false)
end

T["floating_ui"]["update_preview_content"] = function()
    local mock_locations = {
        {
            uri = "file:///test.lua",
            path = "/test.lua",
            relative_path = "test.lua",
            line = 1,
            col = 1,
            text = "test function",
            type = "location",
        },
    }

    navigation.push({
        text = "test_symbol",
        line = 0,
        col = 0,
        bufnr = vim.api.nvim_get_current_buf(),
    })

    navigation.update_current_entry({ references = mock_locations })
    floating.show_relations({ locations = mock_locations })
    floating.enter_focus_mode()

    MiniTest.expect.no_error(function() floating.update_preview_content() end)
end

return T
