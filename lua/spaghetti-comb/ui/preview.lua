local utils = require("spaghetti-comb.utils")

local M = {}

local preview_state = {
    expanded_items = {},
    preview_cache = {},
}

function M.get_code_context(location, context_lines)
    context_lines = context_lines or 5

    if not location or not location.path then return nil end

    local cache_key = string.format("%s:%d:%d", location.path, location.line, context_lines)
    if preview_state.preview_cache[cache_key] then return preview_state.preview_cache[cache_key] end

    if not vim.fn.filereadable(location.path) then return nil end

    local start_line = math.max(1, location.line - context_lines)
    local end_line = location.line + context_lines

    local lines = {}
    local file_lines = vim.fn.readfile(location.path)

    for i = start_line, math.min(end_line, #file_lines) do
        local line_content = file_lines[i] or ""
        local is_target = (i == location.line)

        table.insert(lines, {
            line_num = i,
            content = line_content,
            is_target = is_target,
        })
    end

    local context = {
        location = location,
        lines = lines,
        start_line = start_line,
        end_line = math.min(end_line, #file_lines),
        total_lines = #file_lines,
    }

    preview_state.preview_cache[cache_key] = context
    return context
end

function M.format_preview_lines(context)
    if not context or not context.lines then return {} end

    local formatted_lines = {}
    local max_line_num_width = string.len(tostring(context.end_line))

    for _, line_info in ipairs(context.lines) do
        local line_num_str = string.format("%" .. max_line_num_width .. "d", line_info.line_num)
        local marker = line_info.is_target and "▶" or " "
        local formatted_line = string.format("%s%s │ %s", marker, line_num_str, line_info.content)
        table.insert(formatted_lines, formatted_line)
    end

    return formatted_lines
end

function M.is_item_expanded(item_key) return preview_state.expanded_items[item_key] or false end

function M.toggle_item_expansion(item_key)
    preview_state.expanded_items[item_key] = not M.is_item_expanded(item_key)
    return preview_state.expanded_items[item_key]
end

function M.expand_item(item_key) preview_state.expanded_items[item_key] = true end

function M.collapse_item(item_key) preview_state.expanded_items[item_key] = false end

function M.clear_expanded_items() preview_state.expanded_items = {} end

function M.clear_preview_cache() preview_state.preview_cache = {} end

function M.get_item_key(location)
    if not location or not location.path then return nil end
    return string.format("%s:%d", location.path, location.line)
end

function M.create_preview_content(location, context_lines)
    local context = M.get_code_context(location, context_lines)
    if not context then return { "[Preview not available]" } end

    local preview_lines = M.format_preview_lines(context)

    table.insert(
        preview_lines,
        1,
        string.format("[Preview: %s]", utils.get_relative_path(location.path) or location.path)
    )
    table.insert(preview_lines, "")

    return preview_lines
end

return M
