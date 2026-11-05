-- Integration with mini.pick (dual modes)
local M = {}

-- mini.pick lowers stritems and the query before calling `source.match`; the
-- parallel search-text arrays must fold the same way to stay comparable.
local function query_is_ignorecase(query)
    if not vim.o.ignorecase then return false end
    if not vim.o.smartcase then return true end
    local prompt = table.concat(query)
    return prompt == vim.fn.tolower(prompt)
end

-- Rebuild the parallel stritem arrays a search matcher matches against.
local function set_search_items(search_ctx, items)
    search_ctx.stritems = {}
    search_ctx.stritems_lower = {}
    for _, item in ipairs(items) do
        local text = item.search_text or item.text or ""
        table.insert(search_ctx.stritems, text)
        table.insert(search_ctx.stritems_lower, vim.fn.tolower(text))
    end
end

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
    if filetype then vim.bo[buf_id].filetype = filetype end
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

        if
            filename:find(query, 1, true)
            or (has_context and bookmark.context.function_name:lower():find(query, 1, true))
        then
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

    -- Format items for picker; search_ctx indexes into the same item order and
    -- is swapped wholesale when <C-o> widens the source to codebase hits
    local items = {}
    local search_ctx = {}
    for _, entry in ipairs(entries) do
        table.insert(items, M._format_navigation_item(entry))
    end
    set_search_items(search_ctx, items)

    -- Show picker with preview
    MiniPick.start({
        source = {
            items = items,
            name = "Navigation History",
            match = M._make_search_matcher(search_ctx),
            preview = function(buf_id, item)
                if not item then return end
                if item.entry then return M._show_navigation_preview(buf_id, item.entry) end
                if item.hit then return M._show_hit_preview(buf_id, item.hit) end
            end,
            choose = function(item)
                M._in_target_window(function()
                    if item.entry then return M.jump_to_selected_location(item.entry) end
                    if item.hit then return M.jump_to_hit(item.hit, "vera_seek") end
                end)
            end,
        },
        mappings = {
            widen_to_codebase = {
                char = "<C-o>",
                func = function() M._widen_to_codebase(search_ctx) end,
            },
        },
    })
end

-- Widen the navigation picker to codebase search with the current query
function M._widen_to_codebase(search_ctx)
    local MiniPick = require("mini.pick")
    if not MiniPick.is_picker_active() then return end

    local query = table.concat(MiniPick.get_picker_query() or {})
    if query == "" then
        vim.notify("Type a query first, then <C-o> widens to codebase search", vim.log.levels.INFO)
        return
    end

    require("spaghetti-comb.substrate.vera").search(query, { limit = 20 }, function(hits, err)
        if err then
            vim.notify(err, vim.log.levels.WARN)
            return
        end
        if not hits or #hits == 0 then
            vim.notify("No codebase matches for: " .. query, vim.log.levels.INFO)
            return
        end

        local items = {}
        for _, hit in ipairs(hits) do
            table.insert(items, M._format_hit_item(hit))
        end
        set_search_items(search_ctx, items)
        MiniPick.set_picker_items(items)
    end)
end

-- Match against search_ctx.stritems (item.search_text) instead of item.text
---@param search_ctx table Mutable stritem state shared with the active picker
---@return function match Callable for mini.pick `source.match`
function M._make_search_matcher(search_ctx)
    return function(_, inds, query)
        local MiniPick = require("mini.pick")
        local stritems = query_is_ignorecase(query) and search_ctx.stritems_lower or search_ctx.stritems
        return MiniPick.default_match(stritems, inds, query)
    end
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
        search_text = M._build_search_text(entry),
        entry = entry,
    }
end

-- Everything an entry can be re-found by, beyond the displayed label
function M._build_search_text(entry)
    local parts = {}
    for _, key in ipairs({ "file_path", "jump_type", "branch_id" }) do
        if entry[key] then table.insert(parts, entry[key]) end
    end

    local context = entry.context or {}
    if context.function_name then table.insert(parts, context.function_name) end
    for _, key in ipairs({ "before_lines", "after_lines" }) do
        if type(context[key]) == "table" then
            for _, line in ipairs(context[key]) do
                table.insert(parts, line)
            end
        end
    end

    return table.concat(parts, "\n")
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
    if filetype then vim.bo[buf_id].filetype = filetype end
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

-- Filter navigation entries by anything in their search text
function M.filter_navigation_entries(entries, query)
    if not query or query == "" then return entries end

    local filtered = {}
    query = query:lower()

    for _, entry in ipairs(entries) do
        if M._build_search_text(entry):lower():find(query, 1, true) then table.insert(filtered, entry) end
    end

    return filtered
end

-- Substrate search results (Seek, Related, widened trail search)

-- Format a SearchHit item for display; content joins the matchable text
---@param hit SearchHit
---@return table
function M._format_hit_item(hit)
    local text = string.format("%s:%d", hit.file_path, hit.line_start)
    if hit.symbol_name then text = string.format("%s — %s", text, hit.symbol_name) end

    local search_text = text
    if hit.content and hit.content ~= "" then search_text = search_text .. "\n" .. hit.content end

    return {
        text = text,
        search_text = search_text,
        hit = hit,
    }
end

-- Resolve an index-relative hit path against the current project root
---@param file_path string
---@return string
function M._resolve_hit_path(file_path)
    if file_path:match("^/") or file_path:match("^%a:[/\\]") then return file_path end
    local root = require("spaghetti-comb.utils.project").get_current_project_root()
    return root and (root .. "/" .. file_path) or file_path
end

-- Show a picker over SearchHit results; choosing jumps and records a trail entry
---@param hits SearchHit[]
---@param opts {name: string|nil, jump_type: string|nil}|nil
---@return boolean success
---@return string message
function M.show_search_hits(hits, opts)
    if not state.initialized then return false, "Picker not initialized" end
    opts = opts or {}

    if not hits or #hits == 0 then
        vim.notify("No results", vim.log.levels.INFO)
        return false, "No results"
    end

    local jump_type = opts.jump_type or "vera_seek"

    if state.mini_pick_available then
        local MiniPick = require("mini.pick")
        local items = {}
        for _, hit in ipairs(hits) do
            table.insert(items, M._format_hit_item(hit))
        end
        local search_ctx = {}
        set_search_items(search_ctx, items)

        MiniPick.start({
            source = {
                items = items,
                name = opts.name or "Codebase Search",
                match = M._make_search_matcher(search_ctx),
                preview = function(buf_id, item)
                    if item and item.hit then M._show_hit_preview(buf_id, item.hit) end
                end,
                choose = function(item) M._in_target_window(function() M.jump_to_hit(item.hit, jump_type) end) end,
            },
        })
    else
        local items = {}
        for _, hit in ipairs(hits) do
            table.insert(items, { display = M._format_hit_item(hit).text, hit = hit })
        end
        M.create_fallback_picker(items, {
            prompt = (opts.name or "Codebase Search") .. ":",
            on_choice = function(item) M.jump_to_hit(item.hit, jump_type) end,
        })
    end

    return true, "Search results picker displayed"
end

-- mini.pick calls `choose` with the picker window current and closes it right
-- after; a jump that edits there is lost. Run the jump in the target window.
---@param fn function
function M._in_target_window(fn)
    local ok, MiniPick = pcall(require, "mini.pick")
    local target
    if ok then
        local picker_state = MiniPick.get_picker_state()
        target = picker_state and picker_state.windows and picker_state.windows.target
    end
    if target and vim.api.nvim_win_is_valid(target) then
        vim.api.nvim_win_call(target, fn)
    else
        fn()
    end
end

-- Jump to a search hit and record it as a trail entry
---@param hit SearchHit
---@param jump_type string|nil
function M.jump_to_hit(hit, jump_type)
    if not hit or not hit.file_path or hit.file_path == "" then return end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local from_location = {
        file_path = vim.api.nvim_buf_get_name(0),
        position = { line = cursor[1], column = cursor[2] + 1 },
    }
    local to_location = {
        file_path = M._resolve_hit_path(hit.file_path),
        position = { line = hit.line_start or 1, column = 1 },
        context = { function_name = hit.symbol_name },
    }

    vim.cmd("edit " .. vim.fn.fnameescape(to_location.file_path))
    local line = math.min(to_location.position.line, vim.api.nvim_buf_line_count(0))
    vim.api.nvim_win_set_cursor(0, { line, 0 })
    vim.cmd("normal! zz")

    require("spaghetti-comb.history.manager").record_jump(from_location, to_location, jump_type or "vera_seek")
end

-- Preview a hit's captured snippet, falling back to file context
function M._show_hit_preview(buf_id, hit)
    if hit.content and hit.content ~= "" then
        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, vim.split(hit.content, "\n"))
    else
        local context = require("spaghetti-comb.ui.preview").extract_code_context(
            { file_path = M._resolve_hit_path(hit.file_path), position = { line = hit.line_start } },
            5
        )
        if not context then return end

        local lines = {}
        for _, line_info in ipairs(context.lines) do
            table.insert(lines, line_info.content)
        end
        vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
    end

    local filetype = vim.filetype.match({ filename = hit.file_path })
    if filetype then vim.bo[buf_id].filetype = filetype end
end

-- Jump to selected location. Positions recorded against stale files (deleted,
-- shifted, non-file buffers) can be out of range, so line and column are
-- clamped rather than trusted.
function M.jump_to_selected_location(location)
    if not location or not location.file_path then return end

    vim.cmd("edit " .. vim.fn.fnameescape(location.file_path))
    local line = math.min(math.max(1, location.position.line or 1), vim.api.nvim_buf_line_count(0))
    local line_text = vim.api.nvim_buf_get_lines(0, line - 1, line, false)[1] or ""
    local col = math.min(math.max(0, (location.position.column or 1) - 1), #line_text)
    vim.api.nvim_win_set_cursor(0, { line, col })
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
