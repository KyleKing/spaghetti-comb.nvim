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

    -- Calculate coupling score when we have enough data
    if current.references or current.definitions or current.incoming_calls or current.outgoing_calls then
        local coupling_metrics = require("spaghetti-comb.coupling.metrics")
        local symbol_info = {
            text = current.symbol,
            file = current.file,
            line = current.line,
            type = current.type,
            context = current.context,
        }

        local coupling_score = coupling_metrics.calculate_coupling_score(
            symbol_info,
            current.references,
            current.definitions,
            current.incoming_calls,
            current.outgoing_calls
        )

        current.coupling_score = coupling_score
        current.coupling_metrics = coupling_metrics.get_coupling_metrics(
            symbol_info,
            current.references,
            current.definitions,
            current.incoming_calls,
            current.outgoing_calls
        )
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

function M.get_bidirectional_context(max_back, max_forward)
    max_back = max_back or 10
    max_forward = max_forward or 10

    local current_entry = M.peek()
    local back_entries = {}
    local forward_entries = {}

    local start_back = math.max(1, navigation_stack.current_index - max_back)
    for i = navigation_stack.current_index - 1, start_back, -1 do
        local entry = navigation_stack.entries[i]
        if entry then
            table.insert(back_entries, {
                index = i,
                symbol = entry.symbol,
                file = entry.file,
                relative_path = utils.get_relative_path(entry.file),
                line = entry.line,
                timestamp = entry.timestamp,
                bookmarked = entry.bookmarked or false,
                distance = navigation_stack.current_index - i,
            })
        end
    end

    local end_forward = math.min(#navigation_stack.entries, navigation_stack.current_index + max_forward)
    for i = navigation_stack.current_index + 1, end_forward do
        local entry = navigation_stack.entries[i]
        if entry then
            table.insert(forward_entries, {
                index = i,
                symbol = entry.symbol,
                file = entry.file,
                relative_path = utils.get_relative_path(entry.file),
                line = entry.line,
                timestamp = entry.timestamp,
                bookmarked = entry.bookmarked or false,
                distance = i - navigation_stack.current_index,
            })
        end
    end

    return {
        current = current_entry and {
            index = navigation_stack.current_index,
            symbol = current_entry.symbol,
            file = current_entry.file,
            relative_path = utils.get_relative_path(current_entry.file),
            line = current_entry.line,
            timestamp = current_entry.timestamp,
            bookmarked = current_entry.bookmarked or false,
        } or nil,
        back_entries = back_entries,
        forward_entries = forward_entries,
        can_go_back = M.can_navigate_back(),
        can_go_forward = M.can_navigate_forward(),
        total_back = navigation_stack.current_index - 1,
        total_forward = #navigation_stack.entries - navigation_stack.current_index,
    }
end

function M.navigate_by_offset(offset)
    local target_index = navigation_stack.current_index + offset
    if target_index < 1 or target_index > #navigation_stack.entries then
        utils.warn(string.format("Cannot navigate %d steps from current position", offset))
        return nil
    end

    return M.jump_to_index(target_index)
end

function M.navigate_to_relative_position(direction, steps)
    steps = steps or 1

    if direction == "back" then
        return M.navigate_by_offset(-steps)
    elseif direction == "forward" then
        return M.navigate_by_offset(steps)
    else
        utils.error(string.format("Invalid navigation direction: %s", direction))
        return nil
    end
end

return M
