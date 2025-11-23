-- Persistence and storage management
local M = {}

-- Module dependencies
local types = require("spaghetti-comb.types")

-- Storage paths
local function get_storage_dir()
    local data_path = vim.fn.stdpath("data")
    return data_path .. "/spaghetti-comb"
end

local function get_history_dir()
    return get_storage_dir() .. "/history"
end

local function get_bookmarks_dir()
    return get_storage_dir() .. "/bookmarks"
end

-- Create storage directories if they don't exist
local function ensure_storage_dirs()
    local storage_dir = get_storage_dir()
    local history_dir = get_history_dir()
    local bookmarks_dir = get_bookmarks_dir()

    vim.fn.mkdir(storage_dir, "p")
    vim.fn.mkdir(history_dir, "p")
    vim.fn.mkdir(bookmarks_dir, "p")
end

-- Generate project hash for file naming
local function get_project_hash(project_root)
    if not project_root or project_root == "" then
        return "default"
    end

    -- Simple hash: convert path to safe filename
    local hash = project_root:gsub("/", "_"):gsub("\\", "_"):gsub(":", "")
    -- Take last 50 chars to keep filename reasonable
    if #hash > 50 then
        hash = hash:sub(-50)
    end
    return hash
end

-- Get history file path for project
local function get_history_file(project_root)
    local hash = get_project_hash(project_root)
    return get_history_dir() .. "/" .. hash .. ".json"
end

-- Get bookmarks file path for project
local function get_bookmarks_file(project_root)
    local hash = get_project_hash(project_root)
    return get_bookmarks_dir() .. "/" .. hash .. ".json"
end

-- Task 12.1: History persistence functionality

-- Save navigation history to disk
function M.save_history(trail, project_root)
    if not trail or not project_root then
        return false, "Invalid trail or project_root"
    end

    -- Validate trail structure
    local valid, err = types.validate_navigation_trail(trail)
    if not valid then
        return false, "Invalid trail: " .. (err or "unknown error")
    end

    ensure_storage_dirs()

    local file_path = get_history_file(project_root)

    -- Serialize trail to JSON
    local ok, json = pcall(vim.json.encode, trail)
    if not ok then
        return false, "Failed to encode trail: " .. tostring(json)
    end

    -- Write to file
    local file = io.open(file_path, "w")
    if not file then
        return false, "Failed to open file for writing: " .. file_path
    end

    file:write(json)
    file:close()

    return true, "History saved to " .. file_path
end

-- Load navigation history from disk
function M.load_history(project_root)
    if not project_root then
        return nil, "Invalid project_root"
    end

    local file_path = get_history_file(project_root)

    -- Check if file exists
    if vim.fn.filereadable(file_path) == 0 then
        return nil, "No saved history found for project"
    end

    -- Read file
    local file = io.open(file_path, "r")
    if not file then
        return nil, "Failed to open file for reading: " .. file_path
    end

    local content = file:read("*all")
    file:close()

    -- Decode JSON
    local ok, trail = pcall(vim.json.decode, content)
    if not ok then
        return nil, "Failed to decode trail: " .. tostring(trail)
    end

    -- Validate loaded trail
    local valid, err = types.validate_navigation_trail(trail)
    if not valid then
        return nil, "Invalid saved trail: " .. (err or "unknown error")
    end

    return trail, nil
end

-- Delete history file for project
function M.delete_history(project_root)
    if not project_root then
        return false, "Invalid project_root"
    end

    local file_path = get_history_file(project_root)

    if vim.fn.filereadable(file_path) == 0 then
        return true, "No history file to delete"
    end

    local ok = os.remove(file_path)
    if ok then
        return true, "History deleted"
    else
        return false, "Failed to delete history file"
    end
end

-- Task 12.2: Bookmark persistence

-- Save bookmarks to disk
function M.save_bookmarks(bookmarks, project_root)
    if not bookmarks or not project_root then
        return false, "Invalid bookmarks or project_root"
    end

    ensure_storage_dirs()

    local file_path = get_bookmarks_file(project_root)

    -- Validate each bookmark
    for _, bookmark in ipairs(bookmarks) do
        local valid, err = types.validate_bookmark_entry(bookmark)
        if not valid then
            return false, "Invalid bookmark: " .. (err or "unknown error")
        end
    end

    -- Serialize bookmarks to JSON
    local ok, json = pcall(vim.json.encode, bookmarks)
    if not ok then
        return false, "Failed to encode bookmarks: " .. tostring(json)
    end

    -- Write to file
    local file = io.open(file_path, "w")
    if not file then
        return false, "Failed to open file for writing: " .. file_path
    end

    file:write(json)
    file:close()

    return true, "Bookmarks saved to " .. file_path
end

-- Load bookmarks from disk
function M.load_bookmarks(project_root)
    if not project_root then
        return nil, "Invalid project_root"
    end

    local file_path = get_bookmarks_file(project_root)

    -- Check if file exists
    if vim.fn.filereadable(file_path) == 0 then
        return {}, nil -- Return empty array if no bookmarks saved
    end

    -- Read file
    local file = io.open(file_path, "r")
    if not file then
        return nil, "Failed to open file for reading: " .. file_path
    end

    local content = file:read("*all")
    file:close()

    -- Decode JSON
    local ok, bookmarks = pcall(vim.json.decode, content)
    if not ok then
        return nil, "Failed to decode bookmarks: " .. tostring(bookmarks)
    end

    -- Validate loaded bookmarks
    if type(bookmarks) ~= "table" then
        return nil, "Invalid bookmarks format"
    end

    -- Filter out bookmarks for deleted/moved files
    local valid_bookmarks = {}
    for _, bookmark in ipairs(bookmarks) do
        local valid, _ = types.validate_bookmark_entry(bookmark)
        if valid and vim.fn.filereadable(bookmark.file_path) == 1 then
            table.insert(valid_bookmarks, bookmark)
        end
    end

    return valid_bookmarks, nil
end

-- Delete bookmarks file for project
function M.delete_bookmarks(project_root)
    if not project_root then
        return false, "Invalid project_root"
    end

    local file_path = get_bookmarks_file(project_root)

    if vim.fn.filereadable(file_path) == 0 then
        return true, "No bookmarks file to delete"
    end

    local ok = os.remove(file_path)
    if ok then
        return true, "Bookmarks deleted"
    else
        return false, "Failed to delete bookmarks file"
    end
end

-- Persistence cleanup and management

-- Clean up old or invalid persistence files
function M.cleanup_persistence(max_age_days)
    max_age_days = max_age_days or 90 -- Default 90 days

    ensure_storage_dirs()

    local now = os.time()
    local max_age_seconds = max_age_days * 24 * 60 * 60
    local cleaned_count = 0

    -- Clean history files
    local history_files = vim.fn.glob(get_history_dir() .. "/*.json", false, true)
    for _, file_path in ipairs(history_files) do
        local stat = vim.loop.fs_stat(file_path)
        if stat and (now - stat.mtime.sec) > max_age_seconds then
            os.remove(file_path)
            cleaned_count = cleaned_count + 1
        end
    end

    -- Clean bookmark files
    local bookmark_files = vim.fn.glob(get_bookmarks_dir() .. "/*.json", false, true)
    for _, file_path in ipairs(bookmark_files) do
        local stat = vim.loop.fs_stat(file_path)
        if stat and (now - stat.mtime.sec) > max_age_seconds then
            os.remove(file_path)
            cleaned_count = cleaned_count + 1
        end
    end

    return true, string.format("Cleaned up %d old persistence files", cleaned_count)
end

-- List all saved projects
function M.list_saved_projects()
    ensure_storage_dirs()

    local projects = {}

    -- Get all history files
    local history_files = vim.fn.glob(get_history_dir() .. "/*.json", false, true)
    for _, file_path in ipairs(history_files) do
        local filename = vim.fn.fnamemodify(file_path, ":t:r")
        local stat = vim.loop.fs_stat(file_path)
        if stat then
            table.insert(projects, {
                hash = filename,
                type = "history",
                modified = stat.mtime.sec,
                size = stat.size,
            })
        end
    end

    -- Get all bookmark files
    local bookmark_files = vim.fn.glob(get_bookmarks_dir() .. "/*.json", false, true)
    for _, file_path in ipairs(bookmark_files) do
        local filename = vim.fn.fnamemodify(file_path, ":t:r")
        local stat = vim.loop.fs_stat(file_path)
        if stat then
            -- Check if we already have this project from history
            local found = false
            for _, project in ipairs(projects) do
                if project.hash == filename then
                    project.has_bookmarks = true
                    found = true
                    break
                end
            end

            if not found then
                table.insert(projects, {
                    hash = filename,
                    type = "bookmarks",
                    modified = stat.mtime.sec,
                    size = stat.size,
                })
            end
        end
    end

    return projects
end

-- Get storage statistics
function M.get_storage_stats()
    ensure_storage_dirs()

    local stats = {
        history_count = 0,
        bookmark_count = 0,
        total_size = 0,
        storage_dir = get_storage_dir(),
    }

    -- Count history files
    local history_files = vim.fn.glob(get_history_dir() .. "/*.json", false, true)
    stats.history_count = #history_files
    for _, file_path in ipairs(history_files) do
        local stat = vim.loop.fs_stat(file_path)
        if stat then
            stats.total_size = stats.total_size + stat.size
        end
    end

    -- Count bookmark files
    local bookmark_files = vim.fn.glob(get_bookmarks_dir() .. "/*.json", false, true)
    stats.bookmark_count = #bookmark_files
    for _, file_path in ipairs(bookmark_files) do
        local stat = vim.loop.fs_stat(file_path)
        if stat then
            stats.total_size = stats.total_size + stat.size
        end
    end

    return stats
end

return M
