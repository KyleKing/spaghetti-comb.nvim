-- Integration with mini.pick (dual modes)
local M = {}

-- Module state
local state = {
    config = nil,
    initialized = false,
    current_mode = nil, -- "bookmarks" or "navigation"
    mini_pick_available = false,
}

-- Setup picker system
function M.setup(config)
    state.config = config or {}
    state.initialized = true

    -- Check if mini.pick is available
    state.mini_pick_available = M.check_mini_pick_available()
end

-- Task 8.3: Fallback functionality

-- Check if mini.pick is available
function M.check_mini_pick_available()
    local ok, _ = pcall(require, "mini.pick")
    return ok
end

-- Create fallback picker using vim.ui.select
function M.create_fallback_picker(items, opts)
    opts = opts or {}

    vim.ui.select(items, {
        prompt = opts.prompt or "Select:",
        format_item = opts.format_item or function(item) return item.display end,
    }, function(choice)
        if choice and opts.on_choice then opts.on_choice(choice) end
    end)
end

-- Task 8.1: Bookmark management mode

-- Show bookmark management picker
function M.show_bookmark_mode()
    if not state.initialized then return false, "Picker not initialized" end

    state.current_mode = "bookmarks"

    -- Get all bookmarks
    local bookmarks_module = require("spaghetti-comb.history.bookmarks")
    local bookmarks = bookmarks_module.get_all_bookmarks()

    if #bookmarks == 0 then
        vim.notify("No bookmarks available", vim.log.levels.INFO)
        return false, "No bookmarks"
    end

    -- Sort by frecency (manual bookmarks first, then by visit count)
    M.sort_by_frecency(bookmarks)

    -- Show picker
    if state.mini_pick_available then
        M._show_mini_pick_bookmarks(bookmarks)
    else
        M._show_fallback_bookmarks(bookmarks)
    end

    return true, "Bookmark picker displayed"
end

-- List bookmarks with preview (mini.pick integration)
function M._show_mini_pick_bookmarks(bookmarks)
    local MiniPick = require("mini.pick")

    -- Format items for picker
    local items = {}
    for _, bookmark in ipairs(bookmarks) do
        table.insert(items, M._format_bookmark_item(bookmark))
    end

    -- Show picker with preview
    MiniPick.start({
        source = {
            items = items,
            name = "Bookmarks",
            preview = function(buf_id, item)
                if not item or not item.bookmark then return end
                M._show_bookmark_preview(buf_id, item.bookmark)
            end,
        },
        mappings = {
            toggle_bookmark = {
                char = "<C-b>",
                func = function()
                    local current = MiniPick.get_picker_matches().current
                    if current and current.bookmark then M.toggle_bookmark_selection(current.bookmark) end
                end,
            },
        },
    })
end

-- Show fallback bookmark picker
function M._show_fallback_bookmarks(bookmarks)
    local items = {}
    for _, bookmark in ipairs(bookmarks) do
        table.insert(items, {
            display = M._format_bookmark_display(bookmark),
            bookmark = bookmark,
        })
    end

    M.create_fallback_picker(items, {
        prompt = "Select Bookmark:",
        on_choice = function(item) M.jump_to_selected_location(item.bookmark) end,
    })
end

-- Format bookmark item for display
function M._format_bookmark_item(bookmark)
    return {
        text = M._format_bookmark_display(bookmark),
        bookmark = bookmark,
    }
end

-- Format bookmark display string
function M._format_bookmark_display(bookmark)
    local filename = vim.fn.fnamemodify(bookmark.file_path, ":t")
    local location = string.format("%s:%d", filename, bookmark.position.line)
    local bookmark_type = bookmark.is_manual and "⭐" or "🔥"
    local visit_info = string.format("[%d visits]", bookmark.visit_count)

    return string.format("%s %s %s", bookmark_type, location, visit_info)
end

-- Show bookmark preview in picker
function M._show_bookmark_preview(buf_id, bookmark)
    local preview_module = require("spaghetti-comb.ui.preview")
    local context = preview_module.extract_code_context(bookmark, 5)

    if not context then return end

    local lines = {}
    for _, line_info in ipairs(context.lines) do
        table.insert(lines, line_info.content)
    end

    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

    -- Apply filetype for syntax highlighting
    local filetype = vim.filetype.match({ filename = bookmark.file_path })
    if filetype then vim.api.nvim_buf_set_option(buf_id, "filetype", filetype) end
end

-- Toggle bookmark in picker
function M.toggle_bookmark_selection(bookmark)
    if not bookmark then return end

    local bookmarks_module = require("spaghetti-comb.history.bookmarks")
    bookmarks_module.toggle_bookmark(bookmark)

    vim.notify("Bookmark toggled", vim.log.levels.INFO)
end

-- Sort bookmarks by frecency
function M.sort_by_frecency(bookmarks)
    table.sort(bookmarks, function(a, b)
        -- Manual bookmarks first
        if a.is_manual ~= b.is_manual then return a.is_manual end

        -- Then by visit count
        return a.visit_count > b.visit_count
    end)
end

-- Filter bookmarks by filename or code content
function M.filter_by_filename_or_code(bookmarks, query)
    if not query or query == "" then return bookmarks end

    local filtered = {}
    query = query:lower()

    for _, bookmark in ipairs(bookmarks) do
        local filename = vim.fn.fnamemodify(bookmark.file_path, ":t"):lower()
        local has_context = bookmark.context and bookmark.context.function_name

        if filename:find(query, 1, true) or (has_context and bookmark.context.function_name:lower():find(query, 1, true)) then
            table.insert(filtered, bookmark)
        end
    end

    return filtered
end

-- Task 8.2: Navigation mode

-- Show navigation history picker
function M.show_navigation_mode()
    if not state.initialized then return false, "Picker not initialized" end

    state.current_mode = "navigation"

    -- Get navigation history
    local history_manager = require("spaghetti-comb.history.manager")
    local trail = history_manager.get_current_trail()

    if not trail or #trail.entries == 0 then
        vim.notify("No navigation history available", vim.log.levels.INFO)
        return false, "No navigation history"
    end

    -- Sort by recency (reverse order)
    local entries = M.sort_by_recency(trail.entries)

    -- Show picker
    if state.mini_pick_available then
        M._show_mini_pick_navigation(entries)
    else
        M._show_fallback_navigation(entries)
    end

    return true, "Navigation picker displayed"
end

-- List navigation history (mini.pick integration)
function M._show_mini_pick_navigation(entries)
    local MiniPick = require("mini.pick")

    -- Format items for picker
    local items = {}
    for _, entry in ipairs(entries) do
        table.insert(items, M._format_navigation_item(entry))
    end

    -- Show picker with preview
    MiniPick.start({
        source = {
            items = items,
            name = "Navigation History",
            preview = function(buf_id, item)
                if not item or not item.entry then return end
                M._show_navigation_preview(buf_id, item.entry)
            end,
        },
    })
end

-- Show fallback navigation picker
function M._show_fallback_navigation(entries)
    local items = {}
    for _, entry in ipairs(entries) do
        table.insert(items, {
            display = M._format_navigation_display(entry),
            entry = entry,
        })
    end

    M.create_fallback_picker(items, {
        prompt = "Select Location:",
        on_choice = function(item) M.jump_to_selected_location(item.entry) end,
    })
end

-- Format navigation item for display
function M._format_navigation_item(entry)
    return {
        text = M._format_navigation_display(entry),
        entry = entry,
    }
end

-- Format navigation display string
function M._format_navigation_display(entry)
    local filename = vim.fn.fnamemodify(entry.file_path, ":t")
    local location = string.format("%s:%d", filename, entry.position.line)
    local jump_type = entry.jump_type ~= "manual" and string.format(" (%s)", entry.jump_type) or ""
    local time_ago = M._format_time_ago(entry.timestamp)

    return string.format("%s%s - %s", location, jump_type, time_ago)
end

-- Format time ago string
function M._format_time_ago(timestamp)
    local diff = os.time() - timestamp
    if diff < 60 then
        return "just now"
    elseif diff < 3600 then
        return string.format("%dm ago", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("%dh ago", math.floor(diff / 3600))
    else
        return string.format("%dd ago", math.floor(diff / 86400))
    end
end

-- Show navigation preview in picker
function M._show_navigation_preview(buf_id, entry)
    local preview_module = require("spaghetti-comb.ui.preview")
    local context = preview_module.extract_code_context(entry, 5)

    if not context then return end

    local lines = {}
    for _, line_info in ipairs(context.lines) do
        table.insert(lines, line_info.content)
    end

    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)

    -- Apply filetype for syntax highlighting
    local filetype = vim.filetype.match({ filename = entry.file_path })
    if filetype then vim.api.nvim_buf_set_option(buf_id, "filetype", filetype) end
end

-- Sort navigation entries by recency
function M.sort_by_recency(entries)
    local sorted = {}
    for _, entry in ipairs(entries) do
        table.insert(sorted, entry)
    end

    table.sort(sorted, function(a, b) return a.timestamp > b.timestamp end)

    return sorted
end

-- Filter navigation entries
function M.filter_navigation_entries(entries, query)
    if not query or query == "" then return entries end

    local filtered = {}
    query = query:lower()

    for _, entry in ipairs(entries) do
        local filename = vim.fn.fnamemodify(entry.file_path, ":t"):lower()
        if filename:find(query, 1, true) then table.insert(filtered, entry) end
    end

    return filtered
end

-- Jump to selected location
function M.jump_to_selected_location(location)
    if not location or not location.file_path then return end

    vim.cmd(string.format("edit +%d %s", location.position.line, location.file_path))
    vim.api.nvim_win_set_cursor(0, { location.position.line, location.position.column - 1 })
end

-- Switch between picker modes
function M.switch_mode()
    if state.current_mode == "bookmarks" then
        M.show_navigation_mode()
    else
        M.show_bookmark_mode()
    end
end

-- Get current mode
function M.get_current_mode() return state.current_mode end

-- Check if picker is using mini.pick
function M.is_using_mini_pick() return state.mini_pick_available end

-- Get current state (for testing)
function M.get_state() return state end

-- Reset state (for testing)
function M.reset()
    state = {
        config = state.config,
        initialized = state.initialized,
        current_mode = nil,
        mini_pick_available = state.mini_pick_available,
    }
end

return M
