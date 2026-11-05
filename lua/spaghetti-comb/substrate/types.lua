-- Normalized result types shared by substrate adapters (Vera, codanna, trail)
local M = {}

---@alias SearchSource "vera"|"codanna"|"trail"

-- A single semantic/lexical search result
---@class SearchHit
---@field file_path string Absolute or index-relative file path
---@field line_start number First line of the hit (1-indexed)
---@field line_end number Last line of the hit (1-indexed)
---@field symbol_name string|nil Symbol name when the hit maps to one
---@field symbol_type string|nil Symbol kind ("function", "Function", "block", ...)
---@field content string|nil Snippet or signature text for preview
---@field score number|nil Rank score when the substrate reports one
---@field source SearchSource Which substrate produced the hit

-- A node in a verified relation graph (callers / calls / impact)
---@class RelationItem
---@field name string Symbol name
---@field kind string|nil Symbol kind
---@field file_path string File containing the symbol
---@field line number Line to jump to (call site for callers, definition otherwise)
---@field signature string|nil Symbol signature
---@field doc_comment string|nil Docstring when the index captured one
---@field direction RelationDirection Which query produced this item
---@field depth number|nil Distance from the queried symbol (impact graphs)
---@field symbol_id integer|nil Substrate-side stable symbol id (for symbol_id: re-queries)

---@alias RelationDirection "callers"|"calls"|"impact"

-- A node in a file/directory skeleton outline
---@class SkeletonNode
---@field name string Symbol or section name
---@field kind string Symbol kind
---@field file_path string File containing the node
---@field line number Definition line (1-indexed)
---@field children SkeletonNode[]|nil Nested nodes

-- Health summary for a substrate's index
---@class IndexHealth
---@field tool string Substrate name ("vera", "codanna")
---@field indexed_files integer|nil Files in the index
---@field symbol_count integer|nil Symbols in the index
---@field edge_count integer|nil Relation edges in the index
---@field index_age_seconds number|nil Age of the index when knowable
---@field healthy boolean Whether the index is usable
---@field message string|nil Human-readable detail (failing checks, hints)

-- Create a SearchHit with defaults
---@param fields table
---@return SearchHit
function M.search_hit(fields)
    local hit = fields or {}
    hit.line_start = hit.line_start or 1
    hit.line_end = hit.line_end or hit.line_start
    hit.source = hit.source or "vera"
    return hit
end

-- Create a RelationItem with defaults
---@param fields table
---@return RelationItem
function M.relation_item(fields)
    local item = fields or {}
    item.line = item.line or 1
    return item
end

-- Create a SkeletonNode
---@param fields table
---@return SkeletonNode
function M.skeleton_node(fields)
    local node = fields or {}
    node.line = node.line or 1
    node.children = node.children or {}
    return node
end

-- Create an IndexHealth with defaults
---@param fields table
---@return IndexHealth
function M.index_health(fields)
    local health = fields or {}
    if health.healthy == nil then health.healthy = true end
    return health
end

return M
