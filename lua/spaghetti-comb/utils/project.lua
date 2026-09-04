-- Project detection and management
local M = {}

-- Cache for project root detection to avoid repeated file system operations.
-- Paths that resolve to no project are cached as NO_PROJECT so the directory
-- walk is not repeated on every lookup.
local project_cache = {}
local NO_PROJECT = {}

-- Nested so vim.fs.root treats every marker as equal priority, returning the nearest
-- ancestor holding any of them. A flat list would instead rank the markers, so a
-- distant .git would win over the package.json sitting right beside the file.
local PROJECT_MARKERS = {
    {
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
    },
}

-- Find project root by looking for markers
local function find_project_root(start_path)
    if not start_path or start_path == "" then return nil end

    local root = vim.fs.root(start_path, PROJECT_MARKERS)
    if root ~= nil then return root end

    -- If no markers found, use the directory containing the file
    if vim.fn.filereadable(start_path) == 1 then return vim.fs.dirname(vim.fs.abspath(start_path)) end

    return nil
end

-- Detect project root for a given file path
function M.detect_project_root(file_path)
    if not file_path or file_path == "" then return nil end

    -- Non-file buffer names (term://, fugitive://, etc.) can never resolve to
    -- a real project root, so skip the filesystem walk entirely.
    if file_path:match("^%w+://") then return nil end

    -- Cache by containing directory rather than exact file path, so distinct
    -- files (temp files, scratch buffers) in the same directory share a walk.
    local cache_key = vim.fs.dirname(vim.fs.abspath(file_path))
    local cached = project_cache[cache_key]
    if cached ~= nil then return cached ~= NO_PROJECT and cached or nil end

    local project_root = find_project_root(file_path)

    -- Cache the result
    project_cache[cache_key] = project_root or NO_PROJECT

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
        if project_root ~= NO_PROJECT then projects[project_root] = true end
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
    return vim.fs.basename(project_root)
end

return M
