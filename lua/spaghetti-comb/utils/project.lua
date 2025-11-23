-- Project detection and management
local M = {}

-- Cache for project root detection to avoid repeated file system operations
local project_cache = {}

-- Project markers to look for (in order of preference)
local PROJECT_MARKERS = {
    ".git", -- Git repository
    ".hg", -- Mercurial repository
    ".svn", -- Subversion repository
    "package.json", -- Node.js project
    "Cargo.toml", -- Rust project
    "go.mod", -- Go project
    "pyproject.toml", -- Python project
    "setup.py", -- Python project
    "Makefile", -- Generic project marker
    "CMakeLists.txt", -- C/C++ project
    ".project", -- Eclipse project
    "composer.json", -- PHP project
}

-- Check if a path exists and is a directory
local function is_directory(path)
    local stat = vim.loop.fs_stat(path)
    return stat and stat.type == "directory"
end

-- Check if a path exists and is a file
local function is_file(path)
    local stat = vim.loop.fs_stat(path)
    return stat and stat.type == "file"
end

-- Get the directory part of a file path
local function dirname(path) return vim.fn.fnamemodify(path, ":h") end

-- Normalize path separators
local function normalize_path(path) return vim.fn.fnamemodify(path, ":p") end

-- Find project root by looking for markers
local function find_project_root(start_path)
    if not start_path or start_path == "" then return nil end

    -- Normalize the starting path
    start_path = normalize_path(start_path)
    local current_path = start_path

    -- Walk up the directory tree looking for project markers
    while current_path and current_path ~= "/" and current_path ~= "" do
        for _, marker in ipairs(PROJECT_MARKERS) do
            local marker_path = current_path .. "/" .. marker

            -- Check if marker exists (file or directory)
            if is_directory(marker_path) or is_file(marker_path) then return current_path end
        end

        -- Move up one directory
        local parent = dirname(current_path)
        if parent == current_path then
            -- Reached the root
            break
        end
        current_path = parent
    end

    -- If no markers found, use the directory containing the file
    if start_path and vim.fn.filereadable(start_path) then return dirname(start_path) end

    return nil
end

-- Detect project root for a given file path
function M.detect_project_root(file_path)
    if not file_path or file_path == "" then return nil end

    -- Check cache first
    if project_cache[file_path] then return project_cache[file_path] end

    local project_root = find_project_root(file_path)

    -- Cache the result
    project_cache[file_path] = project_root

    return project_root
end

-- Get current project root based on current buffer
function M.get_current_project_root()
    local current_file = vim.api.nvim_buf_get_name(0)
    if current_file and current_file ~= "" then return M.detect_project_root(current_file) end

    -- Fallback to current working directory
    return vim.fn.getcwd()
end

-- Check if two paths belong to the same project
function M.is_same_project(path1, path2)
    if not path1 or not path2 then return false end

    local project1 = M.detect_project_root(path1)
    local project2 = M.detect_project_root(path2)

    if not project1 or not project2 then return false end

    return project1 == project2
end

-- Get all cached project roots
function M.get_cached_projects()
    local projects = {}
    for _, project_root in pairs(project_cache) do
        if project_root then projects[project_root] = true end
    end

    local result = {}
    for project_root, _ in pairs(projects) do
        table.insert(result, project_root)
    end

    return result
end

-- Clear project cache (useful for testing or when projects change)
function M.clear_cache() project_cache = {} end

-- Get project name from project root
function M.get_project_name(project_root)
    if not project_root then return "unknown" end

    -- Use the directory name as project name
    return vim.fn.fnamemodify(project_root, ":t")
end

return M
