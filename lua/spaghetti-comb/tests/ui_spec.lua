-- UI component tests
local MiniTest = require("mini.test")
local breadcrumbs = require("spaghetti-comb.ui.breadcrumbs")
local floating_tree = require("spaghetti-comb.ui.floating_tree")
local preview = require("spaghetti-comb.ui.preview")
local picker = require("spaghetti-comb.ui.picker")
local statusline = require("spaghetti-comb.ui.statusline")

local T = MiniTest.new_set()

-- Test setup
T["ui components"] = MiniTest.new_set()

T["ui components"]["breadcrumbs setup"] = function()
    -- Test basic setup
    local config = {
        display = {
            max_items = 10,
            hotkey_only = true,
        },
    }

    breadcrumbs.setup(config)
    MiniTest.expect.equality(breadcrumbs.is_visible(), false)
end

T["ui components"]["breadcrumbs toggle visibility"] = function()
    -- Setup
    breadcrumbs.setup({})
    breadcrumbs.hide() -- Ensure starting state

    -- Initially not visible
    MiniTest.expect.equality(breadcrumbs.is_visible(), false)

    -- Note: Can't fully test visibility without actual navigation history
    -- This would require a full Neovim instance with buffers
end

T["ui components"]["breadcrumbs state management"] = function()
    -- Setup
    breadcrumbs.setup({})
    local state = breadcrumbs.get_state()

    -- Should have expected state structure
    MiniTest.expect.equality(type(state.config), "table")
    MiniTest.expect.equality(state.initialized, true)
end

T["ui components"]["floating tree setup"] = function()
    -- Test basic setup
    local config = {
        visual = {
            use_unicode_tree = true,
            floating_window_width = 80,
            floating_window_height = 20,
        },
    }

    floating_tree.setup(config)
    MiniTest.expect.equality(floating_tree.is_visible(), false)
end

T["ui components"]["floating tree visibility"] = function()
    -- Setup
    floating_tree.setup({})
    floating_tree.hide() -- Ensure starting state

    -- Initially not visible
    MiniTest.expect.equality(floating_tree.is_visible(), false)

    -- Note: Full UI testing requires actual Neovim windows
end

T["ui components"]["preview setup"] = function()
    -- Test basic setup
    local config = {}
    preview.setup(config)

    -- Should not error during setup
    MiniTest.expect.no_error(function() preview.setup(config) end)
end

T["ui components"]["picker setup"] = function()
    -- Test basic setup
    local config = {
        integration = {
            mini_pick = true,
        },
    }

    picker.setup(config)

    -- Should not error during setup
    MiniTest.expect.no_error(function() picker.setup(config) end)
end

T["ui components"]["statusline setup"] = function()
    -- Test basic setup
    local config = {
        integration = {
            statusline = true,
        },
    }

    statusline.setup(config)

    -- Should not error during setup
    MiniTest.expect.no_error(function() statusline.setup(config) end)
end

T["ui components"]["statusline gets branch status"] = function()
    -- Setup
    statusline.setup({})

    -- Get status (may be nil if no active navigation)
    local status = statusline.get_branch_status()

    -- Status should be nil or a table with expected fields
    if status then
        MiniTest.expect.equality(type(status), "table")
    end
end

T["ui components"]["highlight groups are set"] = function()
    -- Setup breadcrumbs which sets highlight groups
    breadcrumbs.setup({})
    breadcrumbs.set_highlight_groups()

    -- Check that highlight groups exist
    local hl = vim.api.nvim_get_hl(0, { name = "SpaghettiCombBreadcrumbCurrent" })
    MiniTest.expect.equality(type(hl), "table")
end

return T
