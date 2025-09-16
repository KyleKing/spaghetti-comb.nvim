-- Core history tracking logic
local types = require("spaghetti-comb-v2.types")
local project_utils = require("spaghetti-comb-v2.utils.project")

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
    if not state.current_project then return nil end

    if not state.trails[state.current_project] then
        state.trails[state.current_project] = types.create_navigation_trail({
            project_root = state.current_project,
        })
    end

    return state.trails[state.current_project]
end

-- Set current project context
function M.set_current_project(project_root) state.current_project = project_root end

-- Auto-switch project based on current buffer
function M.auto_switch_project()
    if not state.initialized then return false, "History manager not initialized" end

    local current_file = vim.api.nvim_buf_get_name(0)
    if not current_file or current_file == "" then return false, "No current buffer" end

    local detected_project = project_utils.detect_project_root(current_file)
    if detected_project and detected_project ~= state.current_project then
        M.set_current_project(detected_project)
        return true, detected_project
    end

    return false, "Already in correct project context"
end

-- Get current project
function M.get_current_project() return state.current_project end

-- Core history tracking
function M.record_jump(from_location, to_location, jump_type)
    if not state.initialized then return false, "History manager not initialized" end

    jump_type = jump_type or "manual"
    local current_time = os.time()

    -- Auto-detect project for the destination location
    local detected_project = project_utils.detect_project_root(to_location.file_path)
    if detected_project and detected_project ~= state.current_project then
        -- Switch to the detected project
        M.set_current_project(detected_project)
    end

    local trail = get_current_trail()
    if not trail then return false, "No current project context" end

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

function M.get_current_trail() return get_current_trail() end

function M.navigate_to_index(index)
    if not state.initialized then return false, "History manager not initialized" end

    local trail = get_current_trail()
    if not trail then return false, "No current project context" end

    if index < 1 or index > #trail.entries then return false, "Index out of bounds" end

    trail.current_index = index
    trail.last_accessed = os.time()

    local entry = trail.entries[index]
    return true, entry
end

-- Branch management
function M.create_branch(from_index)
    local trail = get_current_trail()
    if not trail then return nil end

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
    if not trail then return {} end

    local branches = {}
    for branch_id, branch_data in pairs(trail.branches) do
        if branch_id ~= "current" then table.insert(branches, branch_data) end
    end

    -- Sort by most recent access
    table.sort(branches, function(a, b) return a.last_accessed > b.last_accessed end)

    return branches
end

function M.switch_branch(branch_id)
    local trail = get_current_trail()
    if not trail then return false, "No current project context" end

    if not trail.branches[branch_id] then return false, "Branch not found" end

    trail.branches.current = branch_id
    trail.branches[branch_id].last_accessed = os.time()

    return true
end

function M.determine_exploration_state()
    if not state.initialized then return "inactive" end

    local current_time = os.time()
    local time_since_last_jump = current_time - state.last_jump_time

    -- If no jumps recorded yet
    if state.last_jump_time == 0 then return "idle" end

    -- If recent jump activity (within exploration timeout)
    if time_since_last_jump < state.exploration_timeout then
        return "exploring"
    else
        return "idle"
    end
end

-- Intelligent pruning with recovery
local pruning_timer = nil
local PRUNING_DEBOUNCE_MS = 2 * 60 * 1000 -- 2 minutes in milliseconds

function M.schedule_pruning()
    if not state.initialized then return false, "History manager not initialized" end

    -- Cancel existing timer if any
    if pruning_timer then vim.fn.timer_stop(pruning_timer) end

    -- Schedule new pruning operation
    pruning_timer = vim.fn.timer_start(PRUNING_DEBOUNCE_MS, function()
        M.prune_with_recovery()
        pruning_timer = nil
    end)

    return true
end

function M.prune_with_recovery()
    if not state.initialized then return false, "History manager not initialized" end

    local config = state.config or {}
    local max_age_minutes = (config.history and config.history.max_age_minutes) or 30
    local max_age_seconds = max_age_minutes * 60
    local current_time = os.time()

    local total_pruned = 0
    local total_recovered = 0

    -- Prune each project's trail
    for project_root, trail in pairs(state.trails) do
        local project_pruned, project_recovered = M.prune_project_trail(project_root, max_age_seconds, current_time)
        total_pruned = total_pruned + project_pruned
        total_recovered = total_recovered + project_recovered
    end

    -- Clean up empty trails
    M.cleanup_empty_trails()

    return true,
        {
            total_pruned = total_pruned,
            total_recovered = total_recovered,
            projects_affected = vim.tbl_count(state.trails),
        }
end

-- Clean up empty or invalid trails
function M.cleanup_empty_trails()
    local projects_to_remove = {}

    for project_root, trail in pairs(state.trails) do
        -- Remove trails with no entries
        if not trail.entries or #trail.entries == 0 then table.insert(projects_to_remove, project_root) end
    end

    for _, project_root in ipairs(projects_to_remove) do
        state.trails[project_root] = nil
    end

    return #projects_to_remove
end

-- Prune a specific project's trail
function M.prune_project_trail(project_root, max_age_seconds, current_time)
    local trail = state.trails[project_root]
    if not trail then return 0, 0 end

    local pruned_count = 0
    local recovered_count = 0
    local entries_to_keep = {}

    for _, entry in ipairs(trail.entries) do
        -- Check if entry is too old
        if current_time - entry.timestamp > max_age_seconds then
            -- Try to recover the location before pruning
            local recovered = M.attempt_location_recovery(entry)
            if recovered then
                recovered_count = recovered_count + 1
                entry.last_pruned = current_time
                table.insert(entries_to_keep, entry)
            else
                -- Mark as inactive if recovery failed
                M.mark_unrecoverable(entry)
                pruned_count = pruned_count + 1
            end
        else
            table.insert(entries_to_keep, entry)
        end
    end

    -- Prune inconsequential jumps within the same file
    local final_entries = M.prune_inconsequential_jumps(entries_to_keep)

    -- Update trail with pruned entries
    trail.entries = final_entries
    if trail.current_index > #final_entries then trail.current_index = #final_entries end

    return pruned_count, recovered_count
end

function M.attempt_location_recovery(entry)
    if not entry or not entry.file_path or not vim.fn.filereadable(entry.file_path) then return false end

    -- If the file hasn't changed since last access, no recovery needed
    local file_mtime = vim.fn.getftime(entry.file_path)
    if file_mtime <= entry.timestamp then return true end

    -- Try to find the shifted location
    local new_position = M.find_shifted_location(entry)
    if new_position then
        -- Update the entry with recovered position
        M.update_recovered_position(entry, new_position)
        return true
    end

    return false
end

function M.mark_unrecoverable(entry)
    if not entry then return end

    entry.is_active = false
    entry.last_pruned = os.time()
end

function M.prune_old_entries(max_age)
    -- TODO: Implement in task 2.3
end

function M.prune_inconsequential_jumps(entries)
    if not entries or #entries == 0 then return entries end

    local pruned_entries = {}
    local last_kept_entry = nil

    for _, entry in ipairs(entries) do
        if not last_kept_entry then
            -- Keep the first entry
            table.insert(pruned_entries, entry)
            last_kept_entry = entry
        elseif entry.file_path ~= last_kept_entry.file_path then
            -- Different file, keep this entry
            table.insert(pruned_entries, entry)
            last_kept_entry = entry
        elseif M.is_inconsequential_jump(last_kept_entry, entry) then
            -- Skip inconsequential jumps within the same file
            -- Update the last kept entry's timestamp to the newer one
            last_kept_entry.timestamp = entry.timestamp
        else
            -- Keep significant jumps
            table.insert(pruned_entries, entry)
            last_kept_entry = entry
        end
    end

    return pruned_entries
end

-- Determine if a jump is inconsequential (small movements within same file)
function M.is_inconsequential_jump(from_entry, to_entry)
    if not from_entry or not to_entry then return false end

    -- Must be in the same file
    if from_entry.file_path ~= to_entry.file_path then return false end

    -- Calculate line distance
    local line_distance = math.abs(to_entry.position.line - from_entry.position.line)

    -- Define inconsequential thresholds
    local MAX_INCONSEQUENTIAL_LINES = 5 -- Within 5 lines is considered inconsequential
    local MAX_INCONSEQUENTIAL_TIME = 30 -- Within 30 seconds is considered part of same exploration

    -- Check line distance
    if line_distance > MAX_INCONSEQUENTIAL_LINES then return false end

    -- Check time between jumps
    local time_diff = to_entry.timestamp - from_entry.timestamp
    if time_diff > MAX_INCONSEQUENTIAL_TIME then return false end

    -- Check if it's a different jump type (navigation vs exploration)
    if from_entry.jump_type ~= to_entry.jump_type then return false end

    -- Check if it's a manual jump type (likely intentional navigation)
    if to_entry.jump_type == "manual" then return false end

    return true
end

-- Location recovery algorithm
function M.find_shifted_location(entry)
    if not entry or not entry.file_path or not vim.fn.filereadable(entry.file_path) then return nil end

    -- Read the file content
    local lines = vim.fn.readfile(entry.file_path)
    if #lines == 0 then return nil end

    local original_line = entry.original_position.line
    local original_col = entry.original_position.column

    -- If original line still exists and has content, check if it's the same
    if original_line <= #lines then
        local current_line_content = lines[original_line]
        if entry.context and entry.context.before_lines then
            -- Try to match context around the original position
            local context_match = M.match_context_around_line(lines, original_line, entry.context)
            if context_match then
                return {
                    line = original_line,
                    column = original_col,
                }
            end
        end
    end

    -- Try to find the location by searching for nearby context
    if entry.context and entry.context.function_name then
        -- Search for function name in the file
        local function_line = M.find_function_line(lines, entry.context.function_name)
        if function_line then
            -- Try to find the relative position within the function
            local relative_position =
                M.find_relative_position_in_function(lines, function_line, entry.context, original_line - function_line)
            if relative_position then return relative_position end
        end
    end

    -- Fallback: search for unique context strings
    if entry.context and entry.context.before_lines and #entry.context.before_lines > 0 then
        local context_line = M.find_context_line(lines, entry.context.before_lines[1])
        if context_line then return {
            line = context_line,
            column = original_col,
        } end
    end

    return nil
end

function M.update_recovered_position(entry, new_position)
    if not entry or not new_position then return end

    -- Preserve original position for reference
    if not entry.original_position then
        entry.original_position = {
            line = entry.position.line,
            column = entry.position.column,
        }
    end

    -- Update current position
    entry.position = new_position
    entry.line_shifted = true
    entry.last_pruned = os.time()
end

function M.preserve_original_reference(entry)
    if not entry then return end

    -- Ensure original position is preserved
    if not entry.original_position then
        entry.original_position = {
            line = entry.position.line,
            column = entry.position.column,
        }
    end
end

-- Helper functions for location recovery

-- Match context around a specific line
function M.match_context_around_line(lines, line_num, context)
    if not context or not context.before_lines or not context.after_lines then return false end

    local start_line = math.max(1, line_num - #context.before_lines)
    local end_line = math.min(#lines, line_num + #context.after_lines)

    -- Check before lines
    for i, expected_line in ipairs(context.before_lines) do
        local check_line = start_line + i - 1
        if check_line >= line_num or lines[check_line] ~= expected_line then return false end
    end

    -- Check after lines
    for i, expected_line in ipairs(context.after_lines) do
        local check_line = line_num + i
        if check_line <= end_line and lines[check_line] ~= expected_line then return false end
    end

    return true
end

-- Find function definition line by name
function M.find_function_line(lines, function_name)
    if not function_name then return nil end

    -- Common function definition patterns
    local patterns = {
        "function%s+" .. vim.pesc(function_name) .. "%s*%(",
        "def%s+" .. vim.pesc(function_name) .. "%s*%(",
        "fn%s+" .. vim.pesc(function_name) .. "%s*%(",
        "func%s+" .. vim.pesc(function_name) .. "%s*%(",
        function_name .. "%s*%(",
    }

    for i, line in ipairs(lines) do
        for _, pattern in ipairs(patterns) do
            if line:match(pattern) then return i end
        end
    end

    return nil
end

-- Find relative position within a function
function M.find_relative_position_in_function(lines, function_line, context, relative_offset)
    if not context or not context.before_lines then return nil end

    -- Look for the context within a reasonable range around the function
    local search_start = math.max(1, function_line - 50)
    local search_end = math.min(#lines, function_line + 200)

    for i = search_start, search_end do
        if M.match_context_around_line(lines, i, context) then
            return {
                line = i,
                column = 1, -- Default to start of line
            }
        end
    end

    return nil
end

-- Find line containing specific context string
function M.find_context_line(lines, context_string)
    if not context_string or context_string == "" then return nil end

    for i, line in ipairs(lines) do
        if line:find(vim.pesc(context_string), 1, true) then return i end
    end

    return nil
end

-- Additional utility functions for basic history tracking

-- Get current entry
function M.get_current_entry()
    local trail = get_current_trail()
    if not trail or trail.current_index == 0 or trail.current_index > #trail.entries then return nil end

    return trail.entries[trail.current_index]
end

-- Get all entries for current project
function M.get_all_entries()
    local trail = get_current_trail()
    if not trail then return {} end

    return trail.entries
end

-- Navigate backward in history
function M.go_back(count)
    count = count or 1
    local trail = get_current_trail()
    if not trail then return false, "No current project context" end

    local new_index = math.max(1, trail.current_index - count)
    return M.navigate_to_index(new_index)
end

-- Navigate forward in history
function M.go_forward(count)
    count = count or 1
    local trail = get_current_trail()
    if not trail then return false, "No current project context" end

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
        if branch_id ~= "current" then branch_count = branch_count + 1 end
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
    if not state.current_project then return false, "No current project context" end

    state.trails[state.current_project] = nil
    return true
end

-- Clear all history
function M.clear_all_history()
    state.trails = {}
    state.last_jump_time = 0
    return true
end

-- Get all project trails
function M.get_all_project_trails()
    local projects = {}
    for project_root, trail in pairs(state.trails) do
        projects[project_root] = {
            trail = trail,
            stats = M.get_stats_for_project(project_root),
        }
    end
    return projects
end

-- Get stats for a specific project
function M.get_stats_for_project(project_root)
    if not state.trails[project_root] then return nil end

    local trail = state.trails[project_root]
    local branch_count = 0
    for branch_id, _ in pairs(trail.branches) do
        if branch_id ~= "current" then branch_count = branch_count + 1 end
    end

    return {
        total_entries = #trail.entries,
        current_index = trail.current_index,
        branches = branch_count,
        project_root = trail.project_root,
        created_at = trail.created_at,
        last_accessed = trail.last_accessed,
    }
end

-- Switch to a different project
function M.switch_to_project(project_root)
    if not state.trails[project_root] then return false, "Project not found" end

    state.current_project = project_root
    return true
end

-- Create a new project trail if it doesn't exist
function M.ensure_project_trail(project_root)
    if not project_root then return false, "Invalid project root" end

    if not state.trails[project_root] then
        state.trails[project_root] = types.create_navigation_trail({
            project_root = project_root,
        })
    end

    return true
end

-- Get project trail (create if doesn't exist)
function M.get_or_create_project_trail(project_root)
    if not project_root then return nil end

    M.ensure_project_trail(project_root)
    return state.trails[project_root]
end

return M
