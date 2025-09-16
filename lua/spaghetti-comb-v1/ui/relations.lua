local utils = require("spaghetti-comb-v1.utils")
local navigation = require("spaghetti-comb-v1.navigation")

local M = {}

local split_state = {
    relations_win_id = nil,
    relations_buf_id = nil,
    preview_win_id = nil,
    preview_buf_id = nil,
    is_visible = false,
    is_focused = false,
    original_win_id = nil,
    current_data = nil,
    filter_state = {
        search_term = "",
        coupling_filter = "all", -- all, high, medium, low
        file_type_filter = "all",
        show_bookmarked_only = false,
        sort_by = "default", -- default, coupling, file, line
        sort_order = "asc", -- asc, desc
    },
}

local function create_relations_buffer()
    local buf_id = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_option(buf_id, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf_id, "swapfile", false)
    vim.api.nvim_buf_set_option(buf_id, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf_id, "filetype", "spaghetti-comb-v1")
    vim.api.nvim_buf_set_name(buf_id, "SpaghettiComb Relations")

    return buf_id
end

local function get_split_window_config()
    local config = require("spaghetti-comb-v1").get_config()
    local relations_config = config and config.relations

    if not relations_config then
        relations_config = {
            height = 15,
            position = "bottom",
            focus_height = 30,
        }
    end

    return {
        height = relations_config.height or 15,
        focus_height = relations_config.focus_height or 30,
        position = relations_config.position or "bottom",
    }
end

local function setup_split_window_keymaps(buf_id)
    local opts = { buffer = buf_id, silent = true }

    vim.keymap.set("n", "<CR>", function() M.navigate_to_selected() end, opts)

    vim.keymap.set("n", "<C-]>", function() M.explore_selected() end, opts)

    vim.keymap.set("n", "<C-o>", function()
        navigation.navigate_prev()
        M.refresh_content()
    end, opts)

    vim.keymap.set("n", "<Tab>", function() M.toggle_focus_mode() end, opts)

    vim.keymap.set("n", "m", function() M.toggle_bookmark() end, opts)

    vim.keymap.set("n", "c", function() M.show_coupling_metrics() end, opts)

    vim.keymap.set("n", "/", function() M.start_search() end, opts)

    vim.keymap.set("n", "f", function() M.cycle_coupling_filter() end, opts)

    vim.keymap.set("n", "s", function() M.cycle_sort_mode() end, opts)

    vim.keymap.set("n", "b", function() M.toggle_bookmarked_filter() end, opts)

    vim.keymap.set("n", "r", function() M.reset_filters() end, opts)

    vim.keymap.set("n", "q", function() M.close_relations() end, opts)

    vim.keymap.set("n", "<Esc>", function() M.close_relations() end, opts)
end

local function format_location_line(location, show_coupling, include_preview)
    local icon = "📄"
    local coupling_str = ""
    local bookmark_str = ""

    if show_coupling and location.coupling_score then
        coupling_str = string.format(" [C:%.1f]", location.coupling_score)
    end

    if location.bookmarked then bookmark_str = "★ " end

    local base_line = string.format(
        "%s%s %s:%d%s",
        bookmark_str,
        icon,
        location.relative_path or location.path or "unknown",
        location.line,
        coupling_str
    )

    if not include_preview then return base_line end

    local preview = require("spaghetti-comb-v1.ui.preview")
    local item_key = preview.get_item_key(location)
    if not item_key then return base_line end

    local is_expanded = preview.is_item_expanded(item_key)
    if not is_expanded then return base_line end

    local preview_lines = preview.create_expandable_preview_content(location, is_expanded, 3)
    if #preview_lines <= 1 then return base_line end

    local result_lines = { base_line }
    for i = 2, #preview_lines do
        table.insert(result_lines, preview_lines[i])
    end

    return table.concat(result_lines, "\n")
end

local function filter_locations(locations)
    local filter = split_state.filter_state
    local filtered = {}

    for _, location in ipairs(locations) do
        local include = true

        -- Search term filter
        if filter.search_term ~= "" then
            local searchable_text = table
                .concat({
                    location.text or "",
                    location.path or "",
                    location.relative_path or "",
                }, " ")
                :lower()

            if not searchable_text:find(filter.search_term:lower(), 1, true) then include = false end
        end

        -- Coupling filter
        if include and filter.coupling_filter ~= "all" then
            local coupling = location.coupling_score or 0.0
            local coupling_match = false

            if filter.coupling_filter == "high" then
                coupling_match = coupling >= 0.7
            elseif filter.coupling_filter == "medium" then
                coupling_match = coupling >= 0.4 and coupling < 0.7
            elseif filter.coupling_filter == "low" then
                coupling_match = coupling < 0.4
            end

            if not coupling_match then include = false end
        end

        -- Bookmarked filter
        if include and filter.show_bookmarked_only and not location.bookmarked then include = false end

        -- File type filter
        if include and filter.file_type_filter ~= "all" then
            local file_ext = location.path and location.path:match("%.([^.]+)$") or ""
            if file_ext ~= filter.file_type_filter then include = false end
        end

        if include then table.insert(filtered, location) end
    end

    -- Sort filtered results
    if filter.sort_by == "coupling" then
        table.sort(filtered, function(a, b)
            local a_coupling = a.coupling_score or 0.0
            local b_coupling = b.coupling_score or 0.0
            if filter.sort_order == "desc" then
                return a_coupling > b_coupling
            else
                return a_coupling < b_coupling
            end
        end)
    elseif filter.sort_by == "file" then
        table.sort(filtered, function(a, b)
            local a_file = a.relative_path or a.path or ""
            local b_file = b.relative_path or b.path or ""
            if filter.sort_order == "desc" then
                return a_file > b_file
            else
                return a_file < b_file
            end
        end)
    elseif filter.sort_by == "line" then
        table.sort(filtered, function(a, b)
            local a_line = a.line or 0
            local b_line = b.line or 0
            if filter.sort_order == "desc" then
                return a_line > b_line
            else
                return a_line < b_line
            end
        end)
    end

    return filtered
end

local function get_filter_status_line()
    local filter = split_state.filter_state
    local status_parts = {}

    if filter.search_term ~= "" then table.insert(status_parts, "search: " .. filter.search_term) end

    if filter.coupling_filter ~= "all" then table.insert(status_parts, "coupling: " .. filter.coupling_filter) end

    if filter.show_bookmarked_only then table.insert(status_parts, "bookmarked only") end

    if filter.file_type_filter ~= "all" then table.insert(status_parts, "filetype: " .. filter.file_type_filter) end

    if filter.sort_by ~= "default" then
        table.insert(status_parts, "sort: " .. filter.sort_by .. " (" .. filter.sort_order .. ")")
    end

    if #status_parts > 0 then return "Filters: " .. table.concat(status_parts, ", ") end

    return ""
end

local function render_relations_content(data)
    local lines = {}
    local current_entry = navigation.peek()
    local config = require("spaghetti-comb-v1").get_config()
    local show_previews = config and config.relations and config.relations.auto_preview

    if current_entry then
        table.insert(lines, string.format("Relations for '%s':", current_entry.symbol))

        -- Add filter status line
        local filter_status = get_filter_status_line()
        if filter_status ~= "" then table.insert(lines, filter_status) end

        table.insert(lines, "")
    end

    local function add_location_with_previews(location_list, prefix, show_coupling)
        local filtered_locations = filter_locations(location_list)
        for _, location in ipairs(filtered_locations) do
            local formatted = format_location_line(location, show_coupling, show_previews)
            local location_lines = vim.split(formatted, "\n", { plain = true })

            for j, line in ipairs(location_lines) do
                if j == 1 then
                    table.insert(lines, prefix .. line)
                else
                    table.insert(lines, line)
                end
            end
        end
    end

    if data and data.locations then
        local filtered_locations = filter_locations(data.locations)
        if data.method == "textDocument/references" then
            table.insert(lines, string.format("References (%d/%d):", #filtered_locations, #data.locations))
            add_location_with_previews(data.locations, "├─ ", true)
        elseif data.method == "textDocument/definition" then
            table.insert(lines, string.format("Definitions (%d/%d):", #filtered_locations, #data.locations))
            add_location_with_previews(data.locations, "└─ ", false)
        elseif data.method == "callHierarchy/incomingCalls" then
            table.insert(lines, string.format("Incoming Calls (%d/%d):", #filtered_locations, #data.locations))
            add_location_with_previews(data.locations, "├─ ", true)
        elseif data.method == "callHierarchy/outgoingCalls" then
            table.insert(lines, string.format("Outgoing Calls (%d/%d):", #filtered_locations, #data.locations))
            add_location_with_previews(data.locations, "├─ ", true)
        end
        table.insert(lines, "")
    end

    if current_entry then
        if current_entry.references and #current_entry.references > 0 then
            local filtered_refs = filter_locations(current_entry.references)
            table.insert(lines, string.format("References (%d/%d):", #filtered_refs, #current_entry.references))
            add_location_with_previews(current_entry.references, "├─ ", true)
            table.insert(lines, "")
        end

        if current_entry.definitions and #current_entry.definitions > 0 then
            local filtered_defs = filter_locations(current_entry.definitions)
            table.insert(lines, string.format("Definitions (%d/%d):", #filtered_defs, #current_entry.definitions))
            add_location_with_previews(current_entry.definitions, "└─ ", false)
            table.insert(lines, "")
        end

        if current_entry.incoming_calls and #current_entry.incoming_calls > 0 then
            local filtered_incoming = filter_locations(current_entry.incoming_calls)
            table.insert(
                lines,
                string.format("Incoming Calls (%d/%d):", #filtered_incoming, #current_entry.incoming_calls)
            )
            add_location_with_previews(current_entry.incoming_calls, "├─ ", true)
            table.insert(lines, "")
        end

        if current_entry.outgoing_calls and #current_entry.outgoing_calls > 0 then
            local filtered_outgoing = filter_locations(current_entry.outgoing_calls)
            table.insert(
                lines,
                string.format("Outgoing Calls (%d/%d):", #filtered_outgoing, #current_entry.outgoing_calls)
            )
            add_location_with_previews(current_entry.outgoing_calls, "├─ ", true)
            table.insert(lines, "")
        end
    end

    if #lines <= 2 then
        table.insert(lines, "No relations found")
        table.insert(lines, "")
        table.insert(lines, "Try positioning cursor on a symbol and running :SpaghettiCombShow")
        table.insert(lines, "")
        table.insert(lines, "Keybindings:")
        table.insert(lines, "  <Enter> - Navigate to location")
        table.insert(lines, "  <C-]>   - Explore symbol at location")
        table.insert(lines, "  <Tab>   - Toggle focus mode (expand window + preview)")
        table.insert(lines, "  m       - Toggle bookmark")
        table.insert(lines, "  c       - Show coupling metrics")
        table.insert(lines, "  /       - Search relations")
        table.insert(lines, "  f       - Cycle coupling filter (all/high/medium/low)")
        table.insert(lines, "  s       - Cycle sort mode (default/coupling/file/line)")
        table.insert(lines, "  b       - Toggle bookmarked only")
        table.insert(lines, "  r       - Reset all filters")
        table.insert(lines, "  q/<Esc> - Close panel")
    end

    return lines
end

function M.create_split_window()
    if split_state.is_visible then return split_state.relations_win_id, split_state.relations_buf_id end

    split_state.original_win_id = vim.api.nvim_get_current_win()
    local buf_id = create_relations_buffer()
    local config = get_split_window_config()

    -- Create horizontal split at bottom
    vim.cmd("botright " .. config.height .. "split")
    local win_id = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win_id, buf_id)

    vim.api.nvim_win_set_option(win_id, "wrap", false)
    vim.api.nvim_win_set_option(win_id, "cursorline", true)
    vim.api.nvim_win_set_option(win_id, "number", false)
    vim.api.nvim_win_set_option(win_id, "relativenumber", false)
    vim.api.nvim_win_set_option(win_id, "winfixheight", true)

    setup_split_window_keymaps(buf_id)

    split_state.relations_win_id = win_id
    split_state.relations_buf_id = buf_id
    split_state.is_visible = true

    vim.api.nvim_create_autocmd({ "WinClosed" }, {
        pattern = tostring(win_id),
        callback = function() M.close_relations() end,
        once = true,
    })

    -- Auto-update preview when cursor moves in relations window
    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
        buffer = buf_id,
        callback = function() M.update_preview_content() end,
    })

    -- Return to original window
    if split_state.original_win_id and vim.api.nvim_win_is_valid(split_state.original_win_id) then
        vim.api.nvim_set_current_win(split_state.original_win_id)
    end

    return win_id, buf_id
end

function M.show_relations(data)
    local _, buf_id = M.create_split_window()

    split_state.current_data = data

    local lines = render_relations_content(data)

    vim.api.nvim_buf_set_option(buf_id, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf_id, "modifiable", false)

    require("spaghetti-comb-v1.ui.highlights").apply_highlights(buf_id)

    utils.log_ui_change("Relations panel opened")
end

function M.close_relations()
    local was_visible = split_state.is_visible
    
    -- First set visibility to false to prevent autocommand callbacks
    split_state.is_visible = false
    split_state.is_focused = false
    
    -- Clear navigation-related state immediately
    split_state.current_data = nil
    
    -- Close preview window safely with pcall
    if split_state.preview_win_id then
        if vim.api.nvim_win_is_valid(split_state.preview_win_id) then
            pcall(vim.api.nvim_win_close, split_state.preview_win_id, true)
        end
        split_state.preview_win_id = nil
    end
    
    if split_state.preview_buf_id and vim.api.nvim_buf_is_valid(split_state.preview_buf_id) then
        pcall(vim.api.nvim_buf_delete, split_state.preview_buf_id, { force = true })
        split_state.preview_buf_id = nil
    end
    
    -- Close relations window safely
    if split_state.relations_win_id then
        if vim.api.nvim_win_is_valid(split_state.relations_win_id) then
            local windows = vim.api.nvim_list_wins()
            if #windows > 1 then
                pcall(vim.api.nvim_win_close, split_state.relations_win_id, true)
            end
        end
        split_state.relations_win_id = nil
    end
    
    if split_state.relations_buf_id and vim.api.nvim_buf_is_valid(split_state.relations_buf_id) then
        pcall(vim.api.nvim_buf_delete, split_state.relations_buf_id, { force = true })
        split_state.relations_buf_id = nil
    end
    
    -- Ensure autocmds are cleaned up by restoring original window
    if split_state.original_win_id and vim.api.nvim_win_is_valid(split_state.original_win_id) then
        vim.api.nvim_set_current_win(split_state.original_win_id)
    end
    
    if was_visible then
        utils.log_ui_change("Relations panel closed")
    end
end

function M.toggle_relations()
    if split_state.is_visible then
        M.close_relations()
    else
        require("spaghetti-comb-v1.analyzer").analyze_current_symbol()
    end
end

function M.refresh_content()
    if not split_state.is_visible then return end

    local lines = render_relations_content(split_state.current_data)

    vim.api.nvim_buf_set_option(split_state.relations_buf_id, "modifiable", true)
    vim.api.nvim_buf_set_lines(split_state.relations_buf_id, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(split_state.relations_buf_id, "modifiable", false)

    require("spaghetti-comb-v1.ui.highlights").apply_highlights(split_state.relations_buf_id)
end

function M.get_selected_item()
    if not split_state.is_visible or not split_state.buf_id then return nil end

    local cursor = vim.api.nvim_win_get_cursor(split_state.win_id)
    local line_num = cursor[1]

    local current_entry = navigation.peek()
    if not current_entry then return nil end

    local all_items = {}

    if current_entry.references then
        for _, ref in ipairs(current_entry.references) do
            table.insert(all_items, ref)
        end
    end

    if current_entry.definitions then
        for _, def in ipairs(current_entry.definitions) do
            table.insert(all_items, def)
        end
    end

    if current_entry.incoming_calls then
        for _, call in ipairs(current_entry.incoming_calls) do
            table.insert(all_items, call)
        end
    end

    if current_entry.outgoing_calls then
        for _, call in ipairs(current_entry.outgoing_calls) do
            table.insert(all_items, call)
        end
    end

    local item_index = 0
    local lines = vim.api.nvim_buf_get_lines(split_state.buf_id, 0, -1, false)

    for i = 1, line_num do
        local line = lines[i] or ""
        if line:match("^[├└]─ 📄") then
            item_index = item_index + 1
            if i == line_num then return all_items[item_index] end
        end
    end

    return nil
end

function M.navigate_to_selected()
    local item = M.get_selected_item()
    if not item then
        utils.debug("No item selected or no valid location found")
        return
    end

    if not item.path or not item.line then
        utils.debug("Invalid location data")
        return
    end

    vim.cmd("edit " .. vim.fn.fnameescape(item.path))
    vim.api.nvim_win_set_cursor(0, { item.line, item.col - 1 })
    vim.cmd("normal! zz")

    utils.log_navigation(string.format("Navigated to %s:%d", item.relative_path or item.path, item.line))
end

function M.explore_selected()
    local item = M.get_selected_item()
    if not item then
        utils.debug("No item selected or no valid location found")
        return
    end

    if not item.path or not item.line then
        utils.debug("Invalid location data")
        return
    end

    vim.cmd("edit " .. vim.fn.fnameescape(item.path))
    vim.api.nvim_win_set_cursor(0, { item.line, item.col - 1 })
    vim.cmd("normal! zz")

    vim.schedule(function() require("spaghetti-comb-v1.analyzer").analyze_current_symbol() end)

    utils.log_navigation(string.format("Exploring symbol at %s:%d", item.relative_path or item.path, item.line))
end

function M.toggle_focus_mode()
    if not split_state.is_visible then
        utils.debug("Relations window is not visible")
        return
    end

    if split_state.is_focused then
        M.exit_focus_mode()
    else
        M.enter_focus_mode()
    end
end

function M.enter_focus_mode()
    if not split_state.is_visible or split_state.is_focused then return end

    local config = get_split_window_config()

    -- Resize relations window to focus height
    vim.api.nvim_win_set_height(split_state.relations_win_id, config.focus_height)

    -- Create preview window to the right of relations window
    vim.api.nvim_set_current_win(split_state.relations_win_id)
    vim.cmd("vertical botright 60split")

    local preview_win_id = vim.api.nvim_get_current_win()
    local preview_buf_id = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_win_set_buf(preview_win_id, preview_buf_id)
    vim.api.nvim_buf_set_option(preview_buf_id, "buftype", "nofile")
    vim.api.nvim_buf_set_option(preview_buf_id, "swapfile", false)
    vim.api.nvim_buf_set_option(preview_buf_id, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(preview_buf_id, "filetype", "spaghetti-comb-v1-preview")
    vim.api.nvim_buf_set_name(preview_buf_id, "SpaghettiComb Preview")

    vim.api.nvim_win_set_option(preview_win_id, "wrap", false)
    vim.api.nvim_win_set_option(preview_win_id, "number", true)
    vim.api.nvim_win_set_option(preview_win_id, "relativenumber", false)

    split_state.preview_win_id = preview_win_id
    split_state.preview_buf_id = preview_buf_id
    split_state.is_focused = true

    -- Set cursor back to relations window
    vim.api.nvim_set_current_win(split_state.relations_win_id)

    -- Update preview content for current selection
    M.update_preview_content()

    utils.log_ui_change("Focus mode enabled - relations window expanded with preview")
end

function M.exit_focus_mode()
    if not split_state.is_focused then return end

    -- Close preview window
    if split_state.preview_win_id and vim.api.nvim_win_is_valid(split_state.preview_win_id) then
        pcall(vim.api.nvim_win_close, split_state.preview_win_id, true)
    end

    -- Resize relations window back to normal height
    if split_state.relations_win_id and vim.api.nvim_win_is_valid(split_state.relations_win_id) then
        local config = get_split_window_config()
        pcall(vim.api.nvim_win_set_height, split_state.relations_win_id, config.height)
    end

    split_state.preview_win_id = nil
    split_state.preview_buf_id = nil
    split_state.is_focused = false

    utils.log_ui_change("Focus mode disabled - relations window restored to normal size")
end

function M.update_preview_content()
    if not split_state.is_focused or not split_state.preview_buf_id then return end

    -- Check if preview buffer is still valid
    if not vim.api.nvim_buf_is_valid(split_state.preview_buf_id) then return end

    local item = M.get_selected_item()
    if not item then
        local placeholder_lines = {
            "No item selected",
            "",
            "Use arrow keys or j/k to navigate in the relations window",
            "Press <Tab> to exit focus mode",
        }
        pcall(vim.api.nvim_buf_set_option, split_state.preview_buf_id, "modifiable", true)
        pcall(vim.api.nvim_buf_set_lines, split_state.preview_buf_id, 0, -1, false, placeholder_lines)
        pcall(vim.api.nvim_buf_set_option, split_state.preview_buf_id, "modifiable", false)
        return
    end

    local preview_lines = require("spaghetti-comb-v1.ui.preview").create_preview_content(item, 10)

    pcall(vim.api.nvim_buf_set_option, split_state.preview_buf_id, "modifiable", true)
    pcall(vim.api.nvim_buf_set_lines, split_state.preview_buf_id, 0, -1, false, preview_lines)
    pcall(vim.api.nvim_buf_set_option, split_state.preview_buf_id, "modifiable", false)
end

function M.toggle_bookmark()
    local item = M.get_selected_item()
    if not item then
        utils.debug("No item selected")
        return
    end

    local bookmarks = require("spaghetti-comb-v1.persistence.bookmarks")
    local existing_bookmark_id = bookmarks.find_bookmark_by_location(item)

    if existing_bookmark_id then
        -- Remove existing bookmark
        if bookmarks.remove_bookmark(existing_bookmark_id) then
            item.bookmarked = false
            utils.log_action("bookmark_removed", item.relative_path or item.path)
        end
    else
        -- Add new bookmark
        local bookmark_id = bookmarks.add_bookmark(item)
        if bookmark_id then
            item.bookmarked = true
            utils.log_action("bookmark_added", item.relative_path or item.path)
        end
    end

    M.refresh_content()
end

function M.start_search()
    vim.ui.input({ prompt = "Search relations: " }, function(input)
        if input then
            split_state.filter_state.search_term = input
            M.refresh_content()
            utils.log_action("search_filter_applied", input)
        end
    end)
end

function M.cycle_coupling_filter()
    local filters = { "all", "high", "medium", "low" }
    local current = split_state.filter_state.coupling_filter
    local current_index = 1

    for i, filter in ipairs(filters) do
        if filter == current then
            current_index = i
            break
        end
    end

    local next_index = (current_index % #filters) + 1
    split_state.filter_state.coupling_filter = filters[next_index]

    M.refresh_content()
    utils.log_action("coupling_filter_changed", filters[next_index])
end

function M.cycle_sort_mode()
    local sorts = { "default", "coupling", "file", "line" }
    local current = split_state.filter_state.sort_by
    local current_index = 1

    for i, sort in ipairs(sorts) do
        if sort == current then
            current_index = i
            break
        end
    end

    local next_index = (current_index % #sorts) + 1
    local new_sort = sorts[next_index]

    -- Toggle sort order if we're on the same sort mode
    if new_sort == current and new_sort ~= "default" then
        split_state.filter_state.sort_order = split_state.filter_state.sort_order == "asc" and "desc" or "asc"
    else
        split_state.filter_state.sort_by = new_sort
        split_state.filter_state.sort_order = "asc"
    end

    M.refresh_content()

    if new_sort == "default" then
        utils.log_action("sort_mode_changed", "default")
    else
        utils.log_action("sort_mode_changed", new_sort .. " (" .. split_state.filter_state.sort_order .. ")")
    end
end

function M.toggle_bookmarked_filter()
    split_state.filter_state.show_bookmarked_only = not split_state.filter_state.show_bookmarked_only
    M.refresh_content()

    local status = split_state.filter_state.show_bookmarked_only and "enabled" or "disabled"
    utils.log_action("bookmark_filter_toggled", status)
end

function M.reset_filters()
    split_state.filter_state = {
        search_term = "",
        coupling_filter = "all",
        file_type_filter = "all",
        show_bookmarked_only = false,
        sort_by = "default",
        sort_order = "asc",
    }

    M.refresh_content()
    utils.log_action("filters_reset", "all")
end

function M.show_coupling_metrics()
    local item = M.get_selected_item()
    if not item then
        utils.debug("No item selected")
        return
    end

    local coupling_score = item.coupling_score or 0.0
    local coupling_level = "low"

    if coupling_score > 0.7 then
        coupling_level = "high"
    elseif coupling_score > 0.4 then
        coupling_level = "medium"
    end

    utils.log_action(
        "coupling_metrics_shown",
        string.format("%.2f (%s) for %s", coupling_score, coupling_level, item.relative_path or item.path)
    )
end

function M.is_visible() return split_state.is_visible end

function M.is_focused() return split_state.is_focused end

function M.get_filter_state() return vim.deepcopy(split_state.filter_state) end

function M.set_filter_state(new_filter_state)
    split_state.filter_state = vim.tbl_extend("force", split_state.filter_state, new_filter_state)
    if split_state.is_visible then M.refresh_content() end
end

function M.get_filtered_item_count()
    if not split_state.current_data then return 0 end

    local total_count = 0
    local current_entry = navigation.peek()

    if split_state.current_data.locations then
        total_count = total_count + #filter_locations(split_state.current_data.locations)
    end

    if current_entry then
        if current_entry.references then total_count = total_count + #filter_locations(current_entry.references) end
        if current_entry.definitions then total_count = total_count + #filter_locations(current_entry.definitions) end
        if current_entry.incoming_calls then
            total_count = total_count + #filter_locations(current_entry.incoming_calls)
        end
        if current_entry.outgoing_calls then
            total_count = total_count + #filter_locations(current_entry.outgoing_calls)
        end
    end

    return total_count
end

return M
