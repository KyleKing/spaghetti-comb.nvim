-- Core history tracking logic
local types = require('nvim-navigation-breadcrumbs.types')

local M = {}

-- Module state
local state = {
  config = nil,
  initialized = false,
  trails = {}, -- Map of project_root to NavigationTrail
  current_project = nil,
  last_jump_time = 0,
  exploration_timeout = 5 * 60, -- 5 minutes in seconds (default)
}

-- Setup the history manager
function M.setup(config)
  state.config = config or {}
  state.exploration_timeout = (config.history and config.history.exploration_timeout_minutes or 5) * 60
  state.initialized = true
end

-- Get or create trail for current project
local function get_current_trail()
  if not state.current_project then
    return nil
  end
  
  if not state.trails[state.current_project] then
    state.trails[state.current_project] = types.create_navigation_trail({
      project_root = state.current_project
    })
  end
  
  return state.trails[state.current_project]
end

-- Set current project context
function M.set_current_project(project_root)
  state.current_project = project_root
end

-- Get current project
function M.get_current_project()
  return state.current_project
end

-- Core history tracking
function M.record_jump(from_location, to_location, jump_type)
  if not state.initialized then
    return false, "History manager not initialized"
  end
  
  local trail = get_current_trail()
  if not trail then
    return false, "No current project context"
  end
  
  jump_type = jump_type or "manual"
  local current_time = os.time()
  
  -- Create navigation entry for the destination
  local entry = types.create_navigation_entry({
    file_path = to_location.file_path,
    position = to_location.position,
    timestamp = current_time,
    jump_type = jump_type,
    context = to_location.context or {},
    project_root = state.current_project,
    branch_id = trail.branches.current or "main",
  })
  
  -- If we're not at the end of the trail, we're creating a new branch
  if trail.current_index > 0 and trail.current_index < #trail.entries then
    -- Create new branch from current position
    local branch_id = M.create_branch(trail.current_index)
    entry.branch_id = branch_id
  end
  
  -- Add entry to trail
  table.insert(trail.entries, entry)
  trail.current_index = #trail.entries
  trail.last_accessed = current_time
  
  -- Update jump timing for exploration state detection
  state.last_jump_time = current_time
  
  return true, entry
end

function M.get_current_trail()
  return get_current_trail()
end

function M.navigate_to_index(index)
  if not state.initialized then
    return false, "History manager not initialized"
  end
  
  local trail = get_current_trail()
  if not trail then
    return false, "No current project context"
  end
  
  if index < 1 or index > #trail.entries then
    return false, "Index out of bounds"
  end
  
  trail.current_index = index
  trail.last_accessed = os.time()
  
  local entry = trail.entries[index]
  return true, entry
end

-- Branch management
function M.create_branch(from_index)
  local trail = get_current_trail()
  if not trail then
    return nil
  end
  
  local branch_id = types.generate_id()
  local timestamp = os.time()
  
  trail.branches[branch_id] = {
    id = branch_id,
    created_at = timestamp,
    from_index = from_index,
    last_accessed = timestamp,
  }
  
  -- Set as current branch
  trail.branches.current = branch_id
  
  return branch_id
end

function M.get_active_branches()
  local trail = get_current_trail()
  if not trail then
    return {}
  end
  
  local branches = {}
  for branch_id, branch_data in pairs(trail.branches) do
    if branch_id ~= "current" then
      table.insert(branches, branch_data)
    end
  end
  
  -- Sort by most recent access
  table.sort(branches, function(a, b)
    return a.last_accessed > b.last_accessed
  end)
  
  return branches
end

function M.switch_branch(branch_id)
  local trail = get_current_trail()
  if not trail then
    return false, "No current project context"
  end
  
  if not trail.branches[branch_id] then
    return false, "Branch not found"
  end
  
  trail.branches.current = branch_id
  trail.branches[branch_id].last_accessed = os.time()
  
  return true
end

function M.determine_exploration_state()
  if not state.initialized then
    return "inactive"
  end
  
  local current_time = os.time()
  local time_since_last_jump = current_time - state.last_jump_time
  
  -- If no jumps recorded yet
  if state.last_jump_time == 0 then
    return "idle"
  end
  
  -- If recent jump activity (within exploration timeout)
  if time_since_last_jump < state.exploration_timeout then
    return "exploring"
  else
    return "idle"
  end
end

-- Intelligent pruning with recovery (placeholder for future implementation)
function M.schedule_pruning()
  -- TODO: Implement in task 2.3
end

function M.prune_with_recovery()
  -- TODO: Implement in task 2.3
end

function M.attempt_location_recovery(entry)
  -- TODO: Implement in task 2.3
end

function M.mark_unrecoverable(entry)
  -- TODO: Implement in task 2.3
end

function M.prune_old_entries(max_age)
  -- TODO: Implement in task 2.3
end

function M.prune_inconsequential_jumps()
  -- TODO: Implement in task 2.3
end

-- Location recovery (placeholder for future implementation)
function M.find_shifted_location(entry)
  -- TODO: Implement in task 2.3
end

function M.update_recovered_position(entry, new_position)
  -- TODO: Implement in task 2.3
end

function M.preserve_original_reference(entry)
  -- TODO: Implement in task 2.3
end

-- Additional utility functions for basic history tracking

-- Get current entry
function M.get_current_entry()
  local trail = get_current_trail()
  if not trail or trail.current_index == 0 or trail.current_index > #trail.entries then
    return nil
  end
  
  return trail.entries[trail.current_index]
end

-- Get all entries for current project
function M.get_all_entries()
  local trail = get_current_trail()
  if not trail then
    return {}
  end
  
  return trail.entries
end

-- Navigate backward in history
function M.go_back(count)
  count = count or 1
  local trail = get_current_trail()
  if not trail then
    return false, "No current project context"
  end
  
  local new_index = math.max(1, trail.current_index - count)
  return M.navigate_to_index(new_index)
end

-- Navigate forward in history
function M.go_forward(count)
  count = count or 1
  local trail = get_current_trail()
  if not trail then
    return false, "No current project context"
  end
  
  local new_index = math.min(#trail.entries, trail.current_index + count)
  return M.navigate_to_index(new_index)
end

-- Get history statistics
function M.get_stats()
  local trail = get_current_trail()
  if not trail then
    return {
      total_entries = 0,
      current_index = 0,
      branches = 0,
      exploration_state = M.determine_exploration_state(),
    }
  end
  
  local branch_count = 0
  for branch_id, _ in pairs(trail.branches) do
    if branch_id ~= "current" then
      branch_count = branch_count + 1
    end
  end
  
  return {
    total_entries = #trail.entries,
    current_index = trail.current_index,
    branches = branch_count,
    exploration_state = M.determine_exploration_state(),
    project_root = trail.project_root,
    created_at = trail.created_at,
    last_accessed = trail.last_accessed,
  }
end

-- Clear history for current project
function M.clear_current_project_history()
  if not state.current_project then
    return false, "No current project context"
  end
  
  state.trails[state.current_project] = nil
  return true
end

-- Clear all history
function M.clear_all_history()
  state.trails = {}
  state.last_jump_time = 0
  return true
end

return M