local utils = require("spaghetti-comb-v1.utils")

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

function M.create_expandable_preview_content(location, is_expanded, context_lines)
    context_lines = context_lines or 3

    if not location or not location.path then return { "[Invalid location]" } end

    local relative_path = utils.get_relative_path(location.path) or location.path
    local expand_indicator = is_expanded and "▼" or "▶"
    local header = string.format("  %s [Preview: %s:%d]", expand_indicator, relative_path, location.line)

    if not is_expanded then return { header } end

    local context = M.get_code_context(location, context_lines)
    if not context then return { header, "    [Preview not available]" } end

    local preview_lines = { header }
    local formatted_lines = M.format_preview_lines(context)

    for _, line in ipairs(formatted_lines) do
        table.insert(preview_lines, "    " .. line)
    end

    table.insert(preview_lines, "")

    return preview_lines
end

function M.create_multi_level_preview(location, max_depth, current_depth)
    max_depth = max_depth or 2
    current_depth = current_depth or 0

    if current_depth >= max_depth then return M.create_preview_content(location, 3) end

    local preview_lines = M.create_preview_content(location, 5)

    local nested_calls = M.extract_nested_function_calls(location)
    if #nested_calls > 0 then
        table.insert(preview_lines, "  Nested calls:")
        for _, call_location in ipairs(nested_calls) do
            local nested_preview = M.create_multi_level_preview(call_location, max_depth, current_depth + 1)
            for _, line in ipairs(nested_preview) do
                table.insert(preview_lines, "  " .. line)
            end
        end
    end

    return preview_lines
end

function M.extract_nested_function_calls(location)
    if not location or not location.path or not vim.fn.filereadable(location.path) then return {} end

    local bufnr = vim.fn.bufnr(location.path, true)
    if bufnr == -1 then return {} end

    local parser = vim.treesitter.get_parser(bufnr)
    if not parser then return {} end

    local tree = parser:parse()[1]
    if not tree then return {} end

    local nested_calls = {}
    local language = utils.get_buffer_language()

    local query_strings = {
        typescript = "(call_expression function: (identifier) @call)",
        javascript = "(call_expression function: (identifier) @call)",
        python = "(call function: (identifier) @call)",
        rust = "(call_expression function: (identifier) @call)",
        go = "(call_expression function: (identifier) @call)",
    }

    local query_string = query_strings[language]
    if not query_string then return {} end

    local ok, query = pcall(vim.treesitter.query.parse, language, query_string)
    if not ok then return {} end

    local root = tree:root()
    local target_line = location.line - 1

    for id, node in query:iter_captures(root, bufnr, target_line, target_line + 1) do
        local start_row, start_col, end_row, end_col = node:range()
        if start_row == target_line then
            local text = vim.treesitter.get_node_text(node, bufnr)
            table.insert(nested_calls, {
                path = location.path,
                line = start_row + 1,
                col = start_col + 1,
                text = text,
                relative_path = utils.get_relative_path(location.path),
            })
        end
    end

    return nested_calls
end

function M.create_diff_preview(location1, location2)
    if not location1 or not location2 then return { "[Cannot create diff: missing locations]" } end

    local context1 = M.get_code_context(location1, 5)
    local context2 = M.get_code_context(location2, 5)

    if not context1 or not context2 then return { "[Cannot create diff: preview unavailable]" } end

    local diff_lines = {
        string.format(
            "[Diff Preview: %s vs %s]",
            utils.get_relative_path(location1.path) or location1.path,
            utils.get_relative_path(location2.path) or location2.path
        ),
        "",
    }

    table.insert(diff_lines, "--- " .. (utils.get_relative_path(location1.path) or location1.path))
    for _, line_info in ipairs(context1.lines) do
        table.insert(diff_lines, string.format("- %d │ %s", line_info.line_num, line_info.content))
    end

    table.insert(diff_lines, "")
    table.insert(diff_lines, "+++ " .. (utils.get_relative_path(location2.path) or location2.path))
    for _, line_info in ipairs(context2.lines) do
        table.insert(diff_lines, string.format("+ %d │ %s", line_info.line_num, line_info.content))
    end

    return diff_lines
end

function M.get_preview_state()
    return {
        expanded_items = vim.deepcopy(preview_state.expanded_items),
        cache_size = vim.tbl_count(preview_state.preview_cache),
    }
end

function M.set_preview_context_lines(lines)
    if type(lines) == "number" and lines > 0 and lines <= 20 then
        M.default_context_lines = lines
        M.clear_preview_cache() -- Clear cache to use new context lines
        return true
    end
    return false
end

M.default_context_lines = 5

return M
