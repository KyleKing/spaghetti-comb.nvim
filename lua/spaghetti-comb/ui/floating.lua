local utils = require("spaghetti-comb.utils")
local navigation = require("spaghetti-comb.navigation")

local M = {}

local floating_state = {
    win_id = nil,
    buf_id = nil,
    is_visible = false,
    current_data = nil,
}

local function create_floating_buffer()
    local buf_id = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_option(buf_id, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf_id, "swapfile", false)
    vim.api.nvim_buf_set_option(buf_id, "bufhidden", "wipe")
    vim.api.nvim_buf_set_option(buf_id, "filetype", "spaghetti-comb")
    vim.api.nvim_buf_set_name(buf_id, "SpaghettiComb Relations")

    return buf_id
end

local function get_floating_window_config()
    local config = require("spaghetti-comb").get_config()
    local relations_config = config and config.relations

    if not relations_config then relations_config = { width = 50, height = 20, position = "right" } end

    local width = relations_config.width
    local height = relations_config.height

    local uis = vim.api.nvim_list_uis()
    local ui = uis[1]

    if not ui then
        return {
            relative = "editor",
            width = 50,
            height = 20,
            row = 5,
            col = 5,
            style = "minimal",
            border = "rounded",
            title = " Relations Panel ",
            title_pos = "center",
        }
    end

    local screen_width = ui.width
    local screen_height = ui.height

    local win_width = math.min(width, screen_width - 4)
    local win_height = math.min(height, screen_height - 4)

    local row, col
    if relations_config.position == "right" then
        row = math.floor((screen_height - win_height) / 2)
        col = screen_width - win_width - 2
    elseif relations_config.position == "left" then
        row = math.floor((screen_height - win_height) / 2)
        col = 2
    else
        row = math.floor((screen_height - win_height) / 2)
        col = math.floor((screen_width - win_width) / 2)
    end

    return {
        relative = "editor",
        width = win_width,
        height = win_height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
        title = " Relations Panel ",
        title_pos = "center",
    }
end

local function setup_floating_window_keymaps(buf_id)
    local opts = { buffer = buf_id, silent = true }

    vim.keymap.set("n", "<CR>", function() M.navigate_to_selected() end, opts)

    vim.keymap.set("n", "<C-]>", function() M.explore_selected() end, opts)

    vim.keymap.set("n", "<C-o>", function()
        navigation.navigate_prev()
        M.refresh_content()
    end, opts)

    vim.keymap.set("n", "<Tab>", function() M.toggle_preview() end, opts)

    vim.keymap.set("n", "m", function() M.toggle_bookmark() end, opts)

    vim.keymap.set("n", "c", function() M.show_coupling_metrics() end, opts)

    vim.keymap.set("n", "q", function() M.close_relations() end, opts)

    vim.keymap.set("n", "<Esc>", function() M.close_relations() end, opts)
end

local function format_location_line(location, index, show_coupling)
    local icon = "📄"
    local coupling_str = ""

    if show_coupling and location.coupling_score then
        coupling_str = string.format(" [C:%.1f]", location.coupling_score)
    end

    return string.format(
        "%s %s:%d%s",
        icon,
        location.relative_path or location.path or "unknown",
        location.line,
        coupling_str
    )
end

local function render_relations_content(data)
    local lines = {}
    local current_entry = navigation.peek()

    if current_entry then
        table.insert(lines, string.format("Relations for '%s':", current_entry.symbol))
        table.insert(lines, "")
    end

    if data and data.locations then
        if data.method == "textDocument/references" then
            table.insert(lines, string.format("References (%d):", #data.locations))
            for i, location in ipairs(data.locations) do
                table.insert(lines, "├─ " .. format_location_line(location, i, true))
            end
        elseif data.method == "textDocument/definition" then
            table.insert(lines, string.format("Definitions (%d):", #data.locations))
            for i, location in ipairs(data.locations) do
                table.insert(lines, "└─ " .. format_location_line(location, i, false))
            end
        end
        table.insert(lines, "")
    end

    if current_entry then
        if current_entry.references and #current_entry.references > 0 then
            table.insert(lines, string.format("References (%d):", #current_entry.references))
            for i, ref in ipairs(current_entry.references) do
                table.insert(lines, "├─ " .. format_location_line(ref, i, true))
            end
            table.insert(lines, "")
        end

        if current_entry.definitions and #current_entry.definitions > 0 then
            table.insert(lines, string.format("Definitions (%d):", #current_entry.definitions))
            for i, def in ipairs(current_entry.definitions) do
                table.insert(lines, "└─ " .. format_location_line(def, i, false))
            end
            table.insert(lines, "")
        end

        if current_entry.incoming_calls and #current_entry.incoming_calls > 0 then
            table.insert(lines, string.format("Incoming Calls (%d):", #current_entry.incoming_calls))
            for i, call in ipairs(current_entry.incoming_calls) do
                table.insert(lines, "├─ " .. format_location_line(call, i, true))
            end
            table.insert(lines, "")
        end

        if current_entry.outgoing_calls and #current_entry.outgoing_calls > 0 then
            table.insert(lines, string.format("Outgoing Calls (%d):", #current_entry.outgoing_calls))
            for i, call in ipairs(current_entry.outgoing_calls) do
                table.insert(lines, "├─ " .. format_location_line(call, i, true))
            end
            table.insert(lines, "")
        end
    end

    if #lines == 0 then
        table.insert(lines, "No relations found")
        table.insert(lines, "")
        table.insert(lines, "Try positioning cursor on a symbol and running :SpaghettiCombShow")
    end

    return lines
end

function M.create_floating_window()
    if floating_state.is_visible then return floating_state.win_id, floating_state.buf_id end

    local buf_id = create_floating_buffer()
    local win_config = get_floating_window_config()
    local win_id = vim.api.nvim_open_win(buf_id, false, win_config)

    vim.api.nvim_win_set_option(win_id, "wrap", false)
    vim.api.nvim_win_set_option(win_id, "cursorline", true)
    vim.api.nvim_win_set_option(win_id, "number", false)
    vim.api.nvim_win_set_option(win_id, "relativenumber", false)

    setup_floating_window_keymaps(buf_id)

    floating_state.win_id = win_id
    floating_state.buf_id = buf_id
    floating_state.is_visible = true

    vim.api.nvim_create_autocmd({ "WinClosed" }, {
        pattern = tostring(win_id),
        callback = function() M.close_relations() end,
        once = true,
    })

    return win_id, buf_id
end

function M.show_relations(data)
    local win_id, buf_id = M.create_floating_window()

    floating_state.current_data = data

    local lines = render_relations_content(data)

    vim.api.nvim_buf_set_option(buf_id, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf_id, "modifiable", false)

    require("spaghetti-comb.ui.highlights").apply_highlights(buf_id)

    utils.info("Relations panel opened")
end

function M.close_relations()
    if floating_state.win_id and vim.api.nvim_win_is_valid(floating_state.win_id) then
        vim.api.nvim_win_close(floating_state.win_id, true)
    end

    floating_state.win_id = nil
    floating_state.buf_id = nil
    floating_state.is_visible = false
    floating_state.current_data = nil

    utils.info("Relations panel closed")
end

function M.toggle_relations()
    if floating_state.is_visible then
        M.close_relations()
    else
        require("spaghetti-comb.analyzer").analyze_current_symbol()
    end
end

function M.refresh_content()
    if not floating_state.is_visible then return end

    local lines = render_relations_content(floating_state.current_data)

    vim.api.nvim_buf_set_option(floating_state.buf_id, "modifiable", true)
    vim.api.nvim_buf_set_lines(floating_state.buf_id, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(floating_state.buf_id, "modifiable", false)

    require("spaghetti-comb.ui.highlights").apply_highlights(floating_state.buf_id)
end

function M.get_selected_item()
    if not floating_state.is_visible or not floating_state.buf_id then return nil end

    local cursor = vim.api.nvim_win_get_cursor(floating_state.win_id)
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
    local lines = vim.api.nvim_buf_get_lines(floating_state.buf_id, 0, -1, false)

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
        utils.warn("No item selected or no valid location found")
        return
    end

    if not item.path or not item.line then
        utils.warn("Invalid location data")
        return
    end

    vim.cmd("edit " .. vim.fn.fnameescape(item.path))
    vim.api.nvim_win_set_cursor(0, { item.line, item.col - 1 })
    vim.cmd("normal! zz")

    utils.info(string.format("Navigated to %s:%d", item.relative_path or item.path, item.line))
end

function M.explore_selected()
    local item = M.get_selected_item()
    if not item then
        utils.warn("No item selected or no valid location found")
        return
    end

    if not item.path or not item.line then
        utils.warn("Invalid location data")
        return
    end

    vim.cmd("edit " .. vim.fn.fnameescape(item.path))
    vim.api.nvim_win_set_cursor(0, { item.line, item.col - 1 })
    vim.cmd("normal! zz")

    vim.schedule(function() require("spaghetti-comb.analyzer").analyze_current_symbol() end)

    utils.info(string.format("Exploring symbol at %s:%d", item.relative_path or item.path, item.line))
end

function M.toggle_preview()
    local item = M.get_selected_item()
    if not item then
        utils.warn("No item selected")
        return
    end

    utils.info("Code preview expansion not yet implemented")
end

function M.toggle_bookmark()
    local item = M.get_selected_item()
    if not item then
        utils.warn("No item selected")
        return
    end

    item.bookmarked = not item.bookmarked

    local status = item.bookmarked and "added" or "removed"
    utils.info(string.format("Bookmark %s for %s", status, item.relative_path or item.path))

    M.refresh_content()
end

function M.show_coupling_metrics()
    local item = M.get_selected_item()
    if not item then
        utils.warn("No item selected")
        return
    end

    local coupling_score = item.coupling_score or 0.0
    local coupling_level = "low"

    if coupling_score > 0.7 then
        coupling_level = "high"
    elseif coupling_score > 0.4 then
        coupling_level = "medium"
    end

    utils.info(
        string.format("Coupling: %.2f (%s) for %s", coupling_score, coupling_level, item.relative_path or item.path)
    )
end

function M.is_visible() return floating_state.is_visible end

return M
