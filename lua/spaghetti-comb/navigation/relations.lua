-- On-demand codanna relation queries (callers/calls/impact) for the symbol
-- under cursor. Results open in ui.relations_tree; choosing a node records a
-- trail jump with a codanna_* jump type.
local codanna = require("spaghetti-comb.substrate.codanna")

local M = {}

local DIRECTIONS = {
    callers = { fn = "find_callers", jump_type = "codanna_callers", title = "Callers" },
    calls = { fn = "get_calls", jump_type = "codanna_calls", title = "Calls" },
    impact = { fn = "analyze_impact", jump_type = "codanna_impact", title = "Impact" },
}

-- Resolve the symbol to query: an explicit argument beats the cursor word.
---@param symbol string|nil
---@return string|nil
function M._resolve_symbol(symbol)
    if symbol and symbol ~= "" then return symbol end
    local word = vim.fn.expand("<cword>")
    if word and word ~= "" then return word end
    return nil
end

-- search_symbols can't take `symbol_id:` refs, and re-rooted items already
-- carry kind/file — only bare-name queries get the extra root-resolution call.
---@param query string Symbol name or `symbol_id:<id>`
---@param root_hint table|nil RelationItem the tree is being re-rooted on
---@param direction RelationDirection
---@param callback fun(items: RelationItem[]|nil, root: table|nil, err: string|nil)
local function gather(query, root_hint, direction, callback)
    local wants_root = root_hint == nil and not query:match("^symbol_id:")
    local pending = wants_root and 2 or 1
    local items, items_err, root = nil, nil, root_hint

    local function done()
        pending = pending - 1
        if pending == 0 then callback(items, root, items_err) end
    end

    codanna[DIRECTIONS[direction].fn](query, function(i, e)
        items = i
        items_err = e
        done()
    end)

    if wants_root then
        codanna.search_symbols(query, { limit = 1 }, function(hits)
            if hits and hits[1] and hits[1].symbol_name == query then root = hits[1] end
            done()
        end)
    end
end

-- Normalize a RelationItem, SearchHit, or nil into the tree's root node shape.
---@param source table|nil
---@param fallback_name string
---@return {name: string, kind: string|nil, file_path: string|nil, line: integer|nil}
function M._root_node(source, fallback_name)
    source = source or {}
    return {
        name = source.name or source.symbol_name or fallback_name,
        kind = source.kind or source.symbol_type,
        file_path = source.file_path,
        line = source.line or source.line_start,
    }
end

-- Group items for display. Impact results carry a graph distance, so they
-- bucket into depth rings; callers/calls form a single labeled group.
---@param direction RelationDirection
---@param items RelationItem[]
---@return {label: string, items: RelationItem[]}[]
function M._group_items(direction, items)
    if direction ~= "impact" then return { { label = DIRECTIONS[direction].title, items = items } } end

    local buckets, order = {}, {}
    for _, item in ipairs(items) do
        local depth = item.depth or 0
        if not buckets[depth] then
            buckets[depth] = {}
            table.insert(order, depth)
        end
        table.insert(buckets[depth], item)
    end
    table.sort(order)

    local groups = {}
    for _, depth in ipairs(order) do
        local label = depth > 0 and ("Depth " .. depth) or DIRECTIONS.impact.title
        table.insert(groups, { label = label, items = buckets[depth] })
    end
    return groups
end

---@param root {name: string, kind: string|nil, file_path: string|nil, line: integer|nil}
---@param direction RelationDirection
---@param items RelationItem[]
function M._show(root, direction, items)
    local dir = DIRECTIONS[direction]
    require("spaghetti-comb.ui.relations_tree").show(root, M._group_items(direction, items), {
        title = string.format(" %s: %s ", dir.title, root.name),
        on_jump = function(item) M.jump_to_item(item, dir.jump_type) end,
        on_reroot = function(item) M._reroot(item, direction) end,
    })
end

---@param direction RelationDirection
---@param symbol_arg string|nil Explicit symbol, or nil/"" for the cursor word
---@param callback fun(items: RelationItem[]|nil, err: string|nil)|nil
function M._query(direction, symbol_arg, callback)
    callback = callback or function() end
    local symbol = M._resolve_symbol(symbol_arg)
    if not symbol then
        local err = "codanna: no symbol under cursor — pass one as an argument"
        vim.notify(err, vim.log.levels.WARN)
        return callback(nil, err)
    end

    gather(symbol, nil, direction, function(items, root, err)
        if err then
            vim.notify(err, vim.log.levels.WARN)
            return callback(nil, err)
        end
        if not items or #items == 0 then
            vim.notify(string.format("codanna: no %s for '%s'", direction, symbol), vim.log.levels.INFO)
            return callback({}, nil)
        end
        M._show(M._root_node(root, symbol), direction, items)
        callback(items, nil)
    end)
end

-- Re-root the tree on a result item: re-queries the same direction.
-- `symbol_id:<id>` sidesteps the ambiguity a bare name can hit.
---@param item RelationItem
---@param direction RelationDirection
function M._reroot(item, direction)
    local query = item.symbol_id and ("symbol_id:" .. item.symbol_id) or item.name
    gather(query, item, direction, function(items, root, err)
        if err then
            vim.notify(err, vim.log.levels.WARN)
            return
        end
        if not items or #items == 0 then
            vim.notify(string.format("codanna: no %s for '%s'", direction, item.name), vim.log.levels.INFO)
            return
        end
        M._show(M._root_node(root, item.name), direction, items)
    end)
end

-- Jump to a relation item (call_line for callers, definition line otherwise)
-- and record it in the trail.
---@param item RelationItem
---@param jump_type string
function M.jump_to_item(item, jump_type)
    if not item or not item.file_path or item.file_path == "" then return end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local from_location = {
        file_path = vim.api.nvim_buf_get_name(0),
        position = { line = cursor[1], column = cursor[2] + 1 },
    }
    local to_location = {
        file_path = require("spaghetti-comb.ui.picker")._resolve_hit_path(item.file_path),
        position = { line = item.line or 1, column = 1 },
        context = { function_name = item.name },
    }

    vim.cmd("edit " .. vim.fn.fnameescape(to_location.file_path))
    vim.api.nvim_win_set_cursor(0, { to_location.position.line, 0 })
    vim.cmd("normal! zz")

    require("spaghetti-comb.history.manager").record_jump(from_location, to_location, jump_type)
end

---@param symbol string|nil Explicit symbol, or nil/"" for the cursor word
---@param callback fun(items: RelationItem[]|nil, err: string|nil)|nil
function M.callers(symbol, callback) M._query("callers", symbol, callback) end

---@param symbol string|nil Explicit symbol, or nil/"" for the cursor word
---@param callback fun(items: RelationItem[]|nil, err: string|nil)|nil
function M.calls(symbol, callback) M._query("calls", symbol, callback) end

---@param symbol string|nil Explicit symbol, or nil/"" for the cursor word
---@param callback fun(items: RelationItem[]|nil, err: string|nil)|nil
function M.impact(symbol, callback) M._query("impact", symbol, callback) end

return M
