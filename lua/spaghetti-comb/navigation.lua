local utils = require("spaghetti-comb.utils")

local M = {}

local navigation_stack = {
    current_index = 0,
    entries = {},
}

function M.init(stack)
    if stack then
        navigation_stack = stack
        if not navigation_stack.current_index then navigation_stack.current_index = 0 end
        if not navigation_stack.entries then navigation_stack.entries = {} end
    end
end

function M.create_entry(symbol_info)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local bufnr = vim.api.nvim_get_current_buf()
    local file_path = vim.api.nvim_buf_get_name(bufnr)

    return {
        symbol = symbol_info.text or "",
        file = utils.normalize_path(file_path),
        line = cursor[1],
        col = cursor[2] + 1,
        type = symbol_info.type or "unknown",
        language = utils.get_buffer_language(),
        references = {},
        definitions = {},
        coupling_score = 0.0,
        timestamp = os.time(),
        bookmarked = false,
        context = {
            win_id = vim.api.nvim_get_current_win(),
            buf_id = bufnr,
            view = vim.fn.winsaveview(),
            win_config = vim.api.nvim_win_get_config(0),
            buffer_modified = vim.api.nvim_buf_get_option(bufnr, "modified"),
            working_dir = vim.fn.getcwd(),
        },
    }
end

function M.push(symbol_info)
    if not symbol_info then
        utils.error("Cannot push nil symbol to navigation stack")
        return false
    end

    local entry = M.create_entry(symbol_info)

    navigation_stack.current_index = navigation_stack.current_index + 1

    if navigation_stack.current_index <= #navigation_stack.entries then
        for i = navigation_stack.current_index, #navigation_stack.entries do
            navigation_stack.entries[i] = nil
        end
    end

    navigation_stack.entries[navigation_stack.current_index] = entry

    utils.info(string.format("Pushed %s to navigation stack (index: %d)", entry.symbol, navigation_stack.current_index))

    return true
end

function M.pop()
    if navigation_stack.current_index <= 1 then
        utils.warn("Already at the beginning of navigation stack")
        return nil
    end

    navigation_stack.current_index = navigation_stack.current_index - 1
    local entry = navigation_stack.entries[navigation_stack.current_index]

    if entry then
        utils.info(string.format("Popped to %s (index: %d)", entry.symbol, navigation_stack.current_index))
    end

    return entry
end

function M.peek()
    if navigation_stack.current_index == 0 then return nil end

    return navigation_stack.entries[navigation_stack.current_index]
end

function M.navigate_next()
    if navigation_stack.current_index >= #navigation_stack.entries then
        utils.warn("Already at the end of navigation stack")
        return nil
    end

    navigation_stack.current_index = navigation_stack.current_index + 1
    local entry = navigation_stack.entries[navigation_stack.current_index]

    if entry then
        M.jump_to_entry(entry)
        utils.info(string.format("Navigated forward to %s (index: %d)", entry.symbol, navigation_stack.current_index))
    end

    return entry
end

function M.navigate_prev()
    local entry = M.pop()
    if entry then M.jump_to_entry(entry) end
    return entry
end

function M.jump_to_entry(entry)
    if not entry or not entry.file then
        utils.error("Invalid entry for navigation")
        return false
    end

    if not vim.fn.filereadable(entry.file) then
        utils.error(string.format("File not found: %s", entry.file))
        return false
    end

    local success, err = pcall(function()
        if entry.context and entry.context.working_dir then
            vim.cmd("cd " .. vim.fn.fnameescape(entry.context.working_dir))
        end

        vim.cmd("edit " .. vim.fn.fnameescape(entry.file))

        vim.api.nvim_win_set_cursor(0, { entry.line, entry.col - 1 })

        if entry.context and entry.context.view then
            vim.fn.winrestview(entry.context.view)
        else
            vim.cmd("normal! zz")
        end

        if entry.context and entry.context.win_config then
            local current_win = vim.api.nvim_get_current_win()
            local config = entry.context.win_config
            if config.relative and config.relative ~= "" then
                pcall(vim.api.nvim_win_set_config, current_win, config)
            end
        end
    end)

    if not success then
        utils.error(string.format("Failed to navigate to entry: %s", err))
        return false
    end

    return true
end

function M.update_current_entry(updates)
    local current = M.peek()
    if not current then
        utils.warn("No current entry to update")
        return false
    end

    for key, value in pairs(updates) do
        current[key] = value
    end

    return true
end

function M.get_stack_info()
    return {
        current_index = navigation_stack.current_index,
        total_entries = #navigation_stack.entries,
        current_entry = M.peek(),
    }
end

function M.clear_stack()
    navigation_stack.current_index = 0
    navigation_stack.entries = {}
    utils.info("Navigation stack cleared")
end

function M.get_stack_entries() return vim.deepcopy(navigation_stack.entries) end

function M.can_navigate_back() return navigation_stack.current_index > 1 end

function M.can_navigate_forward() return navigation_stack.current_index < #navigation_stack.entries end

function M.get_history_context()
    local back_entries = {}
    local forward_entries = {}

    for i = navigation_stack.current_index - 1, 1, -1 do
        local entry = navigation_stack.entries[i]
        if entry then
            table.insert(back_entries, {
                symbol = entry.symbol,
                file = entry.file,
                line = entry.line,
                relative_path = utils.get_relative_path(entry.file),
                timestamp = entry.timestamp,
            })
        end
    end

    for i = navigation_stack.current_index + 1, #navigation_stack.entries do
        local entry = navigation_stack.entries[i]
        if entry then
            table.insert(forward_entries, {
                symbol = entry.symbol,
                file = entry.file,
                line = entry.line,
                relative_path = utils.get_relative_path(entry.file),
                timestamp = entry.timestamp,
            })
        end
    end

    return {
        back_count = #back_entries,
        forward_count = #forward_entries,
        back_entries = back_entries,
        forward_entries = forward_entries,
        current_index = navigation_stack.current_index,
        total_entries = #navigation_stack.entries,
    }
end

function M.jump_to_index(index)
    if index < 1 or index > #navigation_stack.entries then
        utils.warn(string.format("Invalid navigation index: %d", index))
        return nil
    end

    navigation_stack.current_index = index
    local entry = navigation_stack.entries[index]

    if entry then
        M.jump_to_entry(entry)
        utils.info(string.format("Jumped to %s (index: %d)", entry.symbol, index))
    end

    return entry
end

function M.preserve_current_context()
    local current = M.peek()
    if not current then return end

    local bufnr = vim.api.nvim_get_current_buf()
    current.context = vim.tbl_extend("force", current.context or {}, {
        win_id = vim.api.nvim_get_current_win(),
        buf_id = bufnr,
        view = vim.fn.winsaveview(),
        win_config = vim.api.nvim_win_get_config(0),
        buffer_modified = vim.api.nvim_buf_get_option(bufnr, "modified"),
        working_dir = vim.fn.getcwd(),
        cursor_line = vim.api.nvim_win_get_cursor(0)[1],
        cursor_col = vim.api.nvim_win_get_cursor(0)[2],
        timestamp_updated = os.time(),
    })
end

function M.get_navigation_summary()
    local entries = {}
    for i, entry in ipairs(navigation_stack.entries) do
        table.insert(entries, {
            index = i,
            symbol = entry.symbol,
            file = entry.file,
            relative_path = utils.get_relative_path(entry.file),
            line = entry.line,
            timestamp = entry.timestamp,
            is_current = (i == navigation_stack.current_index),
            bookmarked = entry.bookmarked or false,
        })
    end

    return {
        entries = entries,
        current_index = navigation_stack.current_index,
        total = #navigation_stack.entries,
        can_go_back = M.can_navigate_back(),
        can_go_forward = M.can_navigate_forward(),
    }
end

return M
