-- Cursor-symbol resolution backed by treesitter. When the cursor sits on an
-- identifier the identifier is the query; when it sits on a keyword, operator,
-- or punctuation the useful query is the enclosing definition's name.
local M = {}

local NAME_NODE_TYPES = {
    identifier = true,
    property_identifier = true,
    field_identifier = true,
    shorthand_property_identifier = true,
    type_identifier = true,
}

local DEF_NODE_TYPES = {
    function_definition = true,
    function_declaration = true,
    function_item = true,
    method_definition = true,
    method_declaration = true,
    class_definition = true,
    class_declaration = true,
    impl_item = true,
    decorated_definition = true,
    type_declaration = true,
    interface_declaration = true,
    variable_declarator = true,
}

-- The name a definition node declares. `decorated_definition` delegates to its
-- `definition` child; everything else exposes a `name` field.
---@param node TSNode
---@return string|nil
local function def_name(node)
    if node:type() == "decorated_definition" then
        local inner = node:field("definition")[1]
        return inner and def_name(inner) or nil
    end
    local name = node:field("name")[1]
    if not name then return nil end
    return vim.treesitter.get_node_text(name, 0)
end

-- Resolve the symbol the relations commands should query at the cursor.
-- Explicit arguments win; then the cursor word when it lands on an identifier;
-- then the enclosing definition's name; then the cursor word as a last resort.
-- Uses get_parser rather than get_node so no treesitter highlighting is
-- enabled on the user's behalf.
---@param explicit string|nil Symbol passed on the command line
---@return string|nil
function M.resolve(explicit)
    if explicit and explicit ~= "" then return explicit end

    local cword = vim.fn.expand("<cword>")
    local fallback = cword ~= "" and cword or nil

    local ok, parser = pcall(vim.treesitter.get_parser, 0)
    if not ok or not parser then return fallback end
    local tree = parser:parse()[1]
    if not tree then return fallback end

    local pos = vim.api.nvim_win_get_cursor(0)
    local row, col = pos[1] - 1, pos[2]
    -- A cursor left of the line's first token (col 0 on an indented `def`)
    -- lands outside every sibling node's range and resolves to the outer
    -- scope instead of the definition the line actually starts.
    local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
    local first_token = (line:find("%S") or 1) - 1
    local node = tree:root()
        :named_descendant_for_range(row, math.max(col, first_token), row, math.max(col, first_token))
    if not node then return fallback end
    if NAME_NODE_TYPES[node:type()] then
        if fallback then return fallback end
        return vim.treesitter.get_node_text(node, 0)
    end

    while node do
        if DEF_NODE_TYPES[node:type()] then
            local name = def_name(node)
            if name and name ~= "" then return name end
        end
        node = node:parent()
    end

    return fallback
end

return M
