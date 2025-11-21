-- Sticky bookmarks and frequent locations
local types = require("spaghetti-comb-v2.types")
local project_utils = require("spaghetti-comb-v2.utils.project")

local M = {}

-- Module state
local state = {
    config = nil,
    initialized = false,
    bookmarks = {}, -- Map of project_root to bookmark arrays
    visit_counts = {}, -- Map of location_key to visit count
    current_project = nil,
}

-- Setup the bookmark manager
function M.setup(config)
    state.config = config or {}
    state.initialized = true
end

-- Generate unique location key for tracking
local function get_location_key(file_path, position)
    return string.format("%s:%d:%d", file_path, position.line, position.column)
end

-- Get or create bookmark array for current project
local function get_project_bookmarks(project_root)
    project_root = project_root or state.current_project
    if not project_root then return nil end

    if not state.bookmarks[project_root] then state.bookmarks[project_root] = {} end

    return state.bookmarks[project_root]
end

-- Set current project context
function M.set_current_project(project_root) state.current_project = project_root end

-- Find bookmark by location
local function find_bookmark(location, bookmarks)
    local location_key = get_location_key(location.file_path, location.position)

    for i, bookmark in ipairs(bookmarks) do
        local bookmark_key = get_location_key(bookmark.file_path, bookmark.position)
        if bookmark_key == location_key then return i, bookmark end
    end

    return nil, nil
end

-- Task 5.1: Bookmark management

-- Toggle bookmark at location
function M.toggle_bookmark(location)
    if not state.initialized then return false, "Bookmark manager not initialized" end
    if not location or not location.file_path then return false, "Invalid location" end
    if not location.position or not location.position.line or not location.position.column then
        return false, "Invalid position"
    end

    -- Auto-detect project if not set, fallback to current project context
    local project_root = project_utils.detect_project_root(location.file_path) or state.current_project
    if not project_root then return false, "Could not detect project root" end

    M.set_current_project(project_root)
    local bookmarks = get_project_bookmarks()
    if not bookmarks then return false, "Could not get project bookmarks" end

    local idx, existing = find_bookmark(location, bookmarks)

    if idx then
        -- Remove existing bookmark
        table.remove(bookmarks, idx)
        return true, "removed"
    else
        -- Add new bookmark
        local bookmark = types.create_bookmark_entry({
            file_path = location.file_path,
            position = location.position,
            is_manual = true,
            context = location.context or {},
            project_root = project_root,
            visit_count = state.visit_counts[get_location_key(location.file_path, location.position)] or 1,
        })

        table.insert(bookmarks, bookmark)
        return true, "added"
    end
end

-- Add bookmark at location
function M.add_bookmark(location, manual)
    if not state.initialized then return false, "Bookmark manager not initialized" end
    if not location or not location.file_path then return false, "Invalid location" end

    manual = manual ~= false -- Default to true

    -- Auto-detect project if not set, fallback to current project context
    local project_root = project_utils.detect_project_root(location.file_path) or state.current_project
    if not project_root then return false, "Could not detect project root" end

    M.set_current_project(project_root)
    local bookmarks = get_project_bookmarks()
    if not bookmarks then return false, "Could not get project bookmarks" end

    -- Check if already bookmarked
    local idx, existing = find_bookmark(location, bookmarks)
    if idx then
        -- Update existing bookmark
        existing.is_manual = manual or existing.is_manual
        existing.timestamp = os.time()
        return true, "updated"
    end

    -- Create new bookmark
    local bookmark = types.create_bookmark_entry({
        file_path = location.file_path,
        position = location.position,
        is_manual = manual,
        context = location.context or {},
        project_root = project_root,
        visit_count = state.visit_counts[get_location_key(location.file_path, location.position)] or 1,
    })

    table.insert(bookmarks, bookmark)
    return true, "added"
end

-- Remove bookmark at location
function M.remove_bookmark(location)
    if not state.initialized then return false, "Bookmark manager not initialized" end
    if not location or not location.file_path then return false, "Invalid location" end

    -- Auto-detect project if not set, fallback to current project context
    local project_root = project_utils.detect_project_root(location.file_path) or state.current_project
    if not project_root then return false, "Could not detect project root" end

    M.set_current_project(project_root)
    local bookmarks = get_project_bookmarks()
    if not bookmarks then return false, "Could not get project bookmarks" end

    local idx, _ = find_bookmark(location, bookmarks)
    if idx then
        table.remove(bookmarks, idx)
        return true, "removed"
    end

    return false, "Bookmark not found"
end

-- Clear all bookmarks for current project or globally
function M.clear_all_bookmarks(global)
    if not state.initialized then return false, "Bookmark manager not initialized" end

    if global then
        -- Clear all bookmarks globally
        state.bookmarks = {}
        return true, "All bookmarks cleared globally"
    else
        -- Clear bookmarks for current project only
        if not state.current_project then return false, "No current project context" end

        state.bookmarks[state.current_project] = {}
        return true, string.format("Bookmarks cleared for project: %s", state.current_project)
    end
end

-- Get all bookmarks for current project or all projects
function M.get_all_bookmarks(project_root)
    if not state.initialized then return {} end

    if project_root then
        -- Return bookmarks for specific project
        return state.bookmarks[project_root] or {}
    elseif state.current_project then
        -- Return bookmarks for current project
        return get_project_bookmarks() or {}
    else
        -- Return all bookmarks from all projects
        local all_bookmarks = {}
        for _, bookmarks in pairs(state.bookmarks) do
            for _, bookmark in ipairs(bookmarks) do
                table.insert(all_bookmarks, bookmark)
            end
        end
        return all_bookmarks
    end
end

-- Check if location is bookmarked
function M.is_bookmarked(location)
    if not state.initialized then return false end
    if not location or not location.file_path then return false end

    local project_root = project_utils.detect_project_root(location.file_path) or state.current_project
    if not project_root then return false end

    local bookmarks = state.bookmarks[project_root] or {}
    local _, bookmark = find_bookmark(location, bookmarks)

    return bookmark ~= nil, bookmark
end

-- Task 5.2: Frequent location tracking

-- Increment visit count for a location
function M.increment_visit_count(location)
    if not state.initialized then return false, "Bookmark manager not initialized" end
    if not location or not location.file_path then return false, "Invalid location" end

    local location_key = get_location_key(location.file_path, location.position)
    state.visit_counts[location_key] = (state.visit_counts[location_key] or 0) + 1

    return true, state.visit_counts[location_key]
end

-- Update frequent locations based on visit threshold
function M.update_frequent_locations()
    if not state.initialized then return false, "Bookmark manager not initialized" end

    local threshold = (state.config.bookmarks and state.config.bookmarks.frequent_threshold ~= nil)
        and state.config.bookmarks.frequent_threshold or 3
    local auto_bookmark = (state.config.bookmarks and state.config.bookmarks.auto_bookmark_frequent ~= nil)
        and state.config.bookmarks.auto_bookmark_frequent or true

    if not auto_bookmark then return true, "Auto-bookmark disabled" end

    local promoted_count = 0

    -- Check all visit counts and create automatic bookmarks for frequent locations
    for location_key, count in pairs(state.visit_counts) do
        if count >= threshold then
            -- Parse location key back to components
            local file_path, line, col = location_key:match("^(.+):(%d+):(%d+)$")
            if file_path and line and col then
                local location = {
                    file_path = file_path,
                    position = { line = tonumber(line), column = tonumber(col) },
                }

                -- Check if already bookmarked
                local is_marked, _ = M.is_bookmarked(location)
                if not is_marked then
                    -- Add automatic bookmark
                    local success, msg = M.add_bookmark(location, false) -- false = automatic
                    if success then promoted_count = promoted_count + 1 end
                end
            end
        end
    end

    return true, string.format("Promoted %d locations to frequent bookmarks", promoted_count)
end

-- Get all frequent locations (locations with visit count >= threshold)
function M.get_frequent_locations()
    if not state.initialized then return {} end

    local threshold = (state.config.bookmarks and state.config.bookmarks.frequent_threshold ~= nil)
        and state.config.bookmarks.frequent_threshold or 3
    local frequent = {}

    for location_key, count in pairs(state.visit_counts) do
        if count >= threshold then
            -- Parse location key back to components
            local file_path, line, col = location_key:match("^(.+):(%d+):(%d+)$")
            if file_path and line and col then
                table.insert(frequent, {
                    file_path = file_path,
                    position = { line = tonumber(line), column = tonumber(col) },
                    visit_count = count,
                })
            end
        end
    end

    -- Sort by visit count descending
    table.sort(frequent, function(a, b) return a.visit_count > b.visit_count end)

    return frequent
end

-- Check if location is frequent
function M.is_frequent(location)
    if not state.initialized then return false end
    if not location or not location.file_path then return false end

    local threshold = (state.config.bookmarks and state.config.bookmarks.frequent_threshold ~= nil)
        and state.config.bookmarks.frequent_threshold or 3
    local location_key = get_location_key(location.file_path, location.position)
    local count = state.visit_counts[location_key] or 0

    return count >= threshold, count
end

-- Get visit count for a location
function M.get_visit_count(location)
    if not state.initialized then return 0 end
    if not location or not location.file_path then return 0 end

    local location_key = get_location_key(location.file_path, location.position)
    return state.visit_counts[location_key] or 0
end

-- Export state for testing/debugging
function M.get_state() return state end

-- Reset state (for testing)
function M.reset()
    state = {
        config = state.config,
        initialized = state.initialized,
        bookmarks = {},
        visit_counts = {},
        current_project = nil,
    }
end

-- Task 12.2: Bookmark persistence integration

-- Save current project bookmarks to disk
function M.save_current_project_bookmarks()
    if not state.initialized then return false, "Bookmark manager not initialized" end
    if not state.current_project then return false, "No current project" end

    local storage = require("spaghetti-comb-v2.history.storage")
    local bookmarks = get_project_bookmarks()

    if #bookmarks == 0 then
        return false, "No bookmarks to save"
    end

    return storage.save_bookmarks(bookmarks, state.current_project)
end

-- Save all project bookmarks to disk
function M.save_all_bookmarks()
    if not state.initialized then return false, "Bookmark manager not initialized" end

    local storage = require("spaghetti-comb-v2.history.storage")
    local saved_count = 0
    local errors = {}

    for project_root, bookmarks in pairs(state.bookmarks) do
        if bookmarks and #bookmarks > 0 then
            local success, err = storage.save_bookmarks(bookmarks, project_root)
            if success then
                saved_count = saved_count + 1
            else
                table.insert(errors, string.format("%s: %s", project_root, err or "unknown error"))
            end
        end
    end

    if #errors > 0 then
        return false, string.format("Saved %d projects, %d errors: %s", saved_count, #errors, table.concat(errors, "; "))
    end

    return true, string.format("Saved %d project bookmarks", saved_count)
end

-- Load bookmarks for a project from disk
function M.load_project_bookmarks(project_root)
    if not state.initialized then return false, "Bookmark manager not initialized" end
    if not project_root then return false, "Invalid project root" end

    local storage = require("spaghetti-comb-v2.history.storage")
    local bookmarks, err = storage.load_bookmarks(project_root)

    if not bookmarks then
        return false, err or "Failed to load bookmarks"
    end

    state.bookmarks[project_root] = bookmarks
    return true, string.format("Loaded %d bookmarks", #bookmarks)
end

-- Auto-save bookmarks on VimLeavePre
function M.setup_auto_save()
    if not state.initialized then return false, "Bookmark manager not initialized" end

    local config = state.config or {}
    if not (config.history and config.history.save_on_exit) then
        return false, "Auto-save disabled in config"
    end

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = vim.api.nvim_create_augroup("SpaghettiCombBookmarkPersistence", { clear = true }),
        callback = function()
            M.save_all_bookmarks()
        end,
    })

    return true, "Bookmark auto-save enabled"
end

-- Auto-load bookmarks on project switch
function M.try_load_on_project_switch(project_root)
    if not state.initialized then return false, "Bookmark manager not initialized" end
    if not project_root then return false, "Invalid project root" end

    local config = state.config or {}
    if not (config.history and config.history.save_on_exit) then
        return false, "Persistence disabled in config"
    end

    -- Don't load if we already have bookmarks for this project
    if state.bookmarks[project_root] and #state.bookmarks[project_root] > 0 then
        return false, "Bookmarks already loaded"
    end

    local storage = require("spaghetti-comb-v2.history.storage")
    local bookmarks, err = storage.load_bookmarks(project_root)

    if bookmarks then
        state.bookmarks[project_root] = bookmarks
        return true, string.format("Loaded %d bookmarks from disk", #bookmarks)
    end

    return false, err or "No saved bookmarks"
end

return M
