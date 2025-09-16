-- Core data model interfaces and types
local M = {}

-- Navigation Entry data structure
---@class NavigationEntry
---@field id string Unique identifier
---@field file_path string Absolute file path
---@field position table Cursor position {line, column}
---@field original_position table Original position before line shifts {line, column}
---@field timestamp number Unix timestamp
---@field jump_type string Type of jump ("manual", "lsp_definition", "lsp_reference", etc.)
---@field context table Surrounding code context
---@field project_root string Project root directory
---@field branch_id string Branch identifier for navigation paths
---@field visit_count number Number of times visited (for frequency tracking)
---@field is_bookmarked boolean Manual bookmark flag
---@field is_frequent boolean Auto-detected frequent location
---@field is_active boolean False if location is unrecoverable after pruning
---@field line_shifted boolean True if position was recovered after line shift
---@field last_pruned number Timestamp of last pruning attempt

-- Navigation Trail data structure
---@class NavigationTrail
---@field entries table Array of NavigationEntry
---@field current_index number Current position in trail
---@field branches table Map of branch_id to branch metadata
---@field project_root string Associated project root
---@field created_at number Trail creation timestamp
---@field last_accessed number Last access timestamp

-- Bookmark Entry data structure
---@class BookmarkEntry
---@field id string Unique identifier
---@field file_path string Absolute file path
---@field position table Cursor position {line, column}
---@field timestamp number Creation timestamp
---@field is_manual boolean Manual vs automatic bookmark
---@field visit_count number Number of visits
---@field context table Code context for preview
---@field project_root string Associated project

-- Create a new NavigationEntry
function M.create_navigation_entry(opts)
  opts = opts or {}
  
  return {
    id = opts.id or M.generate_id(),
    file_path = opts.file_path or "",
    position = opts.position or {line = 1, column = 1},
    original_position = opts.original_position or opts.position or {line = 1, column = 1},
    timestamp = opts.timestamp or os.time(),
    jump_type = opts.jump_type or "manual",
    context = opts.context or {
      before_lines = {},
      after_lines = {},
      function_name = nil,
    },
    project_root = opts.project_root or "",
    branch_id = opts.branch_id or "main",
    visit_count = opts.visit_count or 1,
    is_bookmarked = opts.is_bookmarked or false,
    is_frequent = opts.is_frequent or false,
    is_active = opts.is_active ~= false,  -- Default to true
    line_shifted = opts.line_shifted or false,
    last_pruned = opts.last_pruned or 0,
  }
end

-- Create a new NavigationTrail
function M.create_navigation_trail(opts)
  opts = opts or {}
  
  return {
    entries = opts.entries or {},
    current_index = opts.current_index or 0,
    branches = opts.branches or {},
    project_root = opts.project_root or "",
    created_at = opts.created_at or os.time(),
    last_accessed = opts.last_accessed or os.time(),
  }
end

-- Create a new BookmarkEntry
function M.create_bookmark_entry(opts)
  opts = opts or {}
  
  return {
    id = opts.id or M.generate_id(),
    file_path = opts.file_path or "",
    position = opts.position or {line = 1, column = 1},
    timestamp = opts.timestamp or os.time(),
    is_manual = opts.is_manual or false,
    visit_count = opts.visit_count or 1,
    context = opts.context or {
      before_lines = {},
      after_lines = {},
      function_name = nil,
    },
    project_root = opts.project_root or "",
  }
end

-- Generate unique ID
function M.generate_id()
  return string.format("%d_%d", os.time(), math.random(1000, 9999))
end

-- Validate NavigationEntry
function M.validate_navigation_entry(entry)
  if type(entry) ~= "table" then
    return false, "Entry must be a table"
  end
  
  if not entry.id or type(entry.id) ~= "string" then
    return false, "Entry must have a string id"
  end
  
  if not entry.file_path or type(entry.file_path) ~= "string" then
    return false, "Entry must have a string file_path"
  end
  
  if not entry.position or type(entry.position) ~= "table" then
    return false, "Entry must have a position table"
  end
  
  if not entry.position.line or type(entry.position.line) ~= "number" then
    return false, "Entry position must have a numeric line"
  end
  
  if not entry.position.column or type(entry.position.column) ~= "number" then
    return false, "Entry position must have a numeric column"
  end
  
  return true, nil
end

-- Validate NavigationTrail
function M.validate_navigation_trail(trail)
  if type(trail) ~= "table" then
    return false, "Trail must be a table"
  end
  
  if not trail.entries or type(trail.entries) ~= "table" then
    return false, "Trail must have an entries array"
  end
  
  if trail.current_index and (type(trail.current_index) ~= "number" or trail.current_index < 0) then
    return false, "Trail current_index must be a non-negative number"
  end
  
  return true, nil
end

-- Validate BookmarkEntry
function M.validate_bookmark_entry(entry)
  if type(entry) ~= "table" then
    return false, "Bookmark entry must be a table"
  end
  
  if not entry.id or type(entry.id) ~= "string" then
    return false, "Bookmark entry must have a string id"
  end
  
  if not entry.file_path or type(entry.file_path) ~= "string" then
    return false, "Bookmark entry must have a string file_path"
  end
  
  if not entry.position or type(entry.position) ~= "table" then
    return false, "Bookmark entry must have a position table"
  end
  
  return true, nil
end

return M