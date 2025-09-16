-- Jumplist enhancement and integration
local M = {}

-- Dependencies
local history_manager = require("spaghetti-comb-v2.history.manager")
local debug_utils = require("spaghetti-comb-v2.utils.debug")

-- Module state
local state = {
    config = nil,
    initialized = false,
    original_ctrl_o = nil,
    original_ctrl_i = nil,
    enhanced_mode = true,
}

-- Setup jumplist integration
function M.setup(config)
    state.config = config or {}
    state.initialized = true

    -- Check if jumplist integration is enabled
    if not (config.integration and config.integration.jumplist) then
        debug_utils.info("Jumplist integration disabled")
        return
    end

    -- Store original key mappings
    M.store_original_mappings()

    -- Setup enhanced jumplist commands
    M.setup_enhanced_commands()

    debug_utils.info("Jumplist integration initialized")
end

-- Store original Ctrl-O and Ctrl-I mappings
function M.store_original_mappings()
    -- Get current mappings for normal mode
    local ctrl_o_mapping = vim.fn.maparg("<C-O>", "n", false, true)
    local ctrl_i_mapping = vim.fn.maparg("<C-I>", "n", false, true)

    state.original_ctrl_o = ctrl_o_mapping
    state.original_ctrl_i = ctrl_i_mapping

    debug_utils.debug("Stored original jumplist mappings", {
        ctrl_o = ctrl_o_mapping,
        ctrl_i = ctrl_i_mapping,
    })
end

-- Setup enhanced navigation commands
function M.setup_enhanced_commands()
    -- Enhanced backward navigation (Ctrl-O)
    vim.api.nvim_set_keymap("n", "<C-O>", "", {
        noremap = true,
        silent = true,
        callback = function() M.enhanced_ctrl_o() end,
        desc = "Enhanced backward navigation with breadcrumb tracking",
    })

    -- Enhanced forward navigation (Ctrl-I)
    vim.api.nvim_set_keymap("n", "<C-I>", "", {
        noremap = true,
        silent = true,
        callback = function() M.enhanced_ctrl_i() end,
        desc = "Enhanced forward navigation with breadcrumb tracking",
    })

    -- Additional navigation commands
    vim.api.nvim_create_user_command("SpaghettiCombBack", function(opts) M.go_back(tonumber(opts.args) or 1) end, {
        nargs = "?",
        desc = "Navigate backward in breadcrumb history",
    })

    vim.api.nvim_create_user_command(
        "SpaghettiCombForward",
        function(opts) M.go_forward(tonumber(opts.args) or 1) end,
        {
            nargs = "?",
            desc = "Navigate forward in breadcrumb history",
        }
    )

    vim.api.nvim_create_user_command("SpaghettiCombJumpTo", function(opts) M.jump_to_index(tonumber(opts.args)) end, {
        nargs = 1,
        desc = "Jump to specific breadcrumb index",
    })
end

-- Enhanced Ctrl-O (backward navigation)
function M.enhanced_ctrl_o()
    if not state.initialized then
        -- Fallback to original behavior
        return M.fallback_ctrl_o()
    end

    -- Try breadcrumb navigation first
    local success, entry = history_manager.go_back(1)

    if success and entry then
        -- Navigate to the entry location
        M.navigate_to_entry(entry)

        -- Record this as a jumplist navigation
        M.record_jumplist_navigation("backward", entry)

        debug_utils.debug("Enhanced Ctrl-O navigation", {
            file = entry.file_path,
            position = entry.position,
        })
    else
        -- Fallback to original jumplist behavior
        debug_utils.debug("Breadcrumb navigation failed, using original Ctrl-O")
        M.fallback_ctrl_o()
    end
end

-- Enhanced Ctrl-I (forward navigation)
function M.enhanced_ctrl_i()
    if not state.initialized then
        -- Fallback to original behavior
        return M.fallback_ctrl_i()
    end

    -- Try breadcrumb navigation first
    local success, entry = history_manager.go_forward(1)

    if success and entry then
        -- Navigate to the entry location
        M.navigate_to_entry(entry)

        -- Record this as a jumplist navigation
        M.record_jumplist_navigation("forward", entry)

        debug_utils.debug("Enhanced Ctrl-I navigation", {
            file = entry.file_path,
            position = entry.position,
        })
    else
        -- Fallback to original jumplist behavior
        debug_utils.debug("Breadcrumb navigation failed, using original Ctrl-I")
        M.fallback_ctrl_i()
    end
end

-- Navigate backward in breadcrumb history
function M.go_back(count)
    count = count or 1

    local success, entry = history_manager.go_back(count)

    if success and entry then
        M.navigate_to_entry(entry)
        M.record_jumplist_navigation("backward", entry)

        debug_utils.info(
            string.format(
                "Navigated back %d steps to %s:%d",
                count,
                vim.fn.fnamemodify(entry.file_path, ":t"),
                entry.position.line
            )
        )
    else
        vim.notify("Cannot navigate backward: " .. (entry or "no history"), vim.log.levels.WARN)
    end
end

-- Navigate forward in breadcrumb history
function M.go_forward(count)
    count = count or 1

    local success, entry = history_manager.go_forward(count)

    if success and entry then
        M.navigate_to_entry(entry)
        M.record_jumplist_navigation("forward", entry)

        debug_utils.info(
            string.format(
                "Navigated forward %d steps to %s:%d",
                count,
                vim.fn.fnamemodify(entry.file_path, ":t"),
                entry.position.line
            )
        )
    else
        vim.notify("Cannot navigate forward: " .. (entry or "no history"), vim.log.levels.WARN)
    end
end

-- Jump to specific index in breadcrumb history
function M.jump_to_index(index)
    if type(index) ~= "number" or index < 1 then
        vim.notify("Invalid index: " .. tostring(index), vim.log.levels.ERROR)
        return
    end

    local success, entry = history_manager.navigate_to_index(index)

    if success and entry then
        M.navigate_to_entry(entry)
        M.record_jumplist_navigation("jump", entry)

        debug_utils.info(
            string.format(
                "Jumped to breadcrumb %d: %s:%d",
                index,
                vim.fn.fnamemodify(entry.file_path, ":t"),
                entry.position.line
            )
        )
    else
        vim.notify("Cannot jump to index " .. index .. ": " .. (entry or "invalid index"), vim.log.levels.WARN)
    end
end

-- Navigate to a specific entry location
function M.navigate_to_entry(entry)
    if not entry or not entry.file_path then return false end

    -- Check if file exists and is readable
    if not vim.fn.filereadable(entry.file_path) then
        debug_utils.warn("Cannot navigate to entry: file not readable", {
            file = entry.file_path,
            position = entry.position,
        })
        return false
    end

    -- Switch to the buffer/file
    local buf_nr = vim.fn.bufnr(entry.file_path)
    if buf_nr == -1 then
        -- File not in buffer list, open it
        vim.cmd("edit " .. vim.fn.fnameescape(entry.file_path))
    else
        -- Switch to existing buffer
        vim.api.nvim_set_current_buf(buf_nr)
    end

    -- Move cursor to the position
    local position = entry.position
    if entry.line_shifted and entry.original_position then
        -- Use original position if available and line was shifted
        position = entry.original_position
        debug_utils.debug("Using original position for shifted line", {
            original = entry.original_position,
            current = entry.position,
        })
    end

    -- Set cursor position (convert to 0-based indexing for nvim_win_set_cursor)
    vim.api.nvim_win_set_cursor(0, { position.line, position.column - 1 })

    -- Center the cursor if configured
    if state.config and state.config.navigation and state.config.navigation.center_on_jump then
        vim.cmd("normal! zz")
    end

    return true
end

-- Record jumplist navigation for tracking purposes
function M.record_jumplist_navigation(direction, entry)
    -- This could be used for analytics or additional tracking
    -- For now, just log it
    debug_utils.debug("Jumplist navigation recorded", {
        direction = direction,
        file = entry.file_path,
        position = entry.position,
        jump_type = entry.jump_type,
    })
end

-- Fallback to original Ctrl-O behavior
function M.fallback_ctrl_o()
    if state.original_ctrl_o and state.original_ctrl_o.callback then
        -- If there was a custom mapping, call it
        state.original_ctrl_o.callback()
    else
        -- Use Neovim's built-in jumplist
        vim.cmd("normal! <C-O>")
    end
end

-- Fallback to original Ctrl-I behavior
function M.fallback_ctrl_i()
    if state.original_ctrl_i and state.original_ctrl_i.callback then
        -- If there was a custom mapping, call it
        state.original_ctrl_i.callback()
    else
        -- Use Neovim's built-in jumplist
        vim.cmd("normal! <C-I>")
    end
end

-- Get jumplist information for debugging
function M.get_jumplist_info()
    local jumplist = vim.fn.getjumplist()
    return {
        current_index = jumplist[2],
        total_entries = #jumplist[1],
        entries = jumplist[1],
    }
end

-- Check compatibility with Neovim's jumplist
function M.check_jumplist_compatibility()
    -- Test if we can access jumplist
    local jumplist_success, jumplist = pcall(vim.fn.getjumplist)
    if not jumplist_success then
        debug_utils.warn("Cannot access Neovim jumplist", { error = jumplist })
        return false
    end

    -- Test if we can set cursor position
    local cursor_success, _ = pcall(vim.api.nvim_win_set_cursor, 0, { 1, 0 })
    if not cursor_success then
        debug_utils.warn("Cannot set cursor position")
        return false
    end

    return true
end

-- Toggle enhanced mode on/off
function M.toggle_enhanced_mode()
    state.enhanced_mode = not state.enhanced_mode

    if state.enhanced_mode then
        debug_utils.info("Enhanced jumplist mode enabled")
    else
        debug_utils.info("Enhanced jumplist mode disabled - using original behavior")
    end

    return state.enhanced_mode
end

-- Get current enhanced mode status
function M.is_enhanced_mode() return state.enhanced_mode end

-- Cleanup function
function M.cleanup()
    -- Restore original mappings if they existed
    if state.original_ctrl_o then
        if state.original_ctrl_o.rhs then
            vim.api.nvim_set_keymap("n", "<C-O>", state.original_ctrl_o.rhs, {
                noremap = state.original_ctrl_o.noremap,
                silent = state.original_ctrl_o.silent,
            })
        end
    end

    if state.original_ctrl_i then
        if state.original_ctrl_i.rhs then
            vim.api.nvim_set_keymap("n", "<C-I>", state.original_ctrl_i.rhs, {
                noremap = state.original_ctrl_i.noremap,
                silent = state.original_ctrl_i.silent,
            })
        end
    end

    state.initialized = false
end

return M
