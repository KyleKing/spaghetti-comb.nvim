local M = {}

function M.get_cursor_symbol()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line = cursor[1] - 1
    local col = cursor[2]
    local bufnr = vim.api.nvim_get_current_buf()

    local node = vim.treesitter.get_node({
        bufnr = bufnr,
        pos = { line, col },
    })

    if not node then return nil end

    local text = vim.treesitter.get_node_text(node, bufnr)
    return {
        text = text,
        node = node,
        line = line,
        col = col,
        bufnr = bufnr,
    }
end

function M.get_buffer_language()
    local bufnr = vim.api.nvim_get_current_buf()
    local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

    local language_map = {
        typescript = "typescript",
        javascript = "javascript",
        python = "python",
        rust = "rust",
        go = "go",
        lua = "lua",
    }

    return language_map[filetype] or filetype
end

function M.normalize_path(path)
    if not path then return nil end
    return vim.fn.fnamemodify(path, ":p")
end

function M.get_relative_path(path)
    if not path then return nil end
    return vim.fn.fnamemodify(path, ":~:.")
end

function M.is_valid_location(loc) return loc ~= nil and loc.uri ~= nil and loc.range ~= nil end

function M.uri_to_path(uri)
    if not uri then return nil end
    return vim.uri_to_fname(uri)
end

function M.path_to_uri(path)
    if not path then return nil end
    return vim.uri_from_fname(path)
end

function M.get_line_text(bufnr, line_num)
    if not vim.api.nvim_buf_is_valid(bufnr) then return nil end

    local lines = vim.api.nvim_buf_get_lines(bufnr, line_num, line_num + 1, false)
    return lines[1] or ""
end

function M.create_location_item(uri, range, text)
    local path = M.uri_to_path(uri)
    local relative_path = M.get_relative_path(path)

    return {
        uri = uri,
        path = path,
        relative_path = relative_path,
        range = range,
        line = range.start.line + 1,
        col = range.start.character + 1,
        text = text or "",
        type = "location",
    }
end

function M.debounce(fn, ms)
    local timer = vim.loop.new_timer()
    return function(...)
        local args = { ... }
        timer:stop()
        timer:start(ms, 0, function()
            vim.schedule(function() fn(unpack(args)) end)
        end)
    end
end

function M.log(level, msg)
    if type(msg) == "table" then msg = vim.inspect(msg) end
    vim.notify("[SpaghettiComb] " .. msg, level)
end

function M.error(msg) M.log(vim.log.levels.ERROR, msg) end

function M.warn(msg) M.log(vim.log.levels.WARN, msg) end

function M.info(msg) M.log(vim.log.levels.INFO, msg) end

return M
