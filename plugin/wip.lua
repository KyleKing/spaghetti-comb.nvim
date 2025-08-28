local M = {}

-- Detect the root directory (project root or Git root)
local function get_root_dir()
    local bufnr = vim.api.nvim_get_current_buf()
    local file_dir = vim.fn.expand("%:p:h")

    -- Check for .git directory or other root markers
    local root = vim.fs.find(
        { ".git", "pyproject.toml", "package.json" },
        { upward = true, path = file_dir }
    )
    if #root > 0 then
        return vim.fs.dirname(root[1])
    else
        return vim.fn.getcwd() -- Fallback to the current working directory
    end
end

-- Get the path of an executable related to the current file
local function find_local_executable(executable)
    local root_dir = get_root_dir()
    local executable_paths = {
        -- Node.js projects
        "node_modules/.bin/" .. executable,
        -- Python projects
        ".venv/bin/" .. executable,
        -- Tox environments
        ".tox/bin/" .. executable,
    }

    for _, path in ipairs(executable_paths) do
        local full_path = root_dir .. "/" .. path
        if vim.fn.executable(full_path) == 1 then
            return full_path
        end
    end

    -- Fallback to system-wide executable
    if vim.fn.executable(executable) == 1 then
        return vim.fn.exepath(executable)
    end

    -- Return nil if no executable found
    return nil
end

-- API to expose the executable finder
M.get_executable = function(executable)
    local path = find_local_executable(executable)
    if path then
        return path
    else
        vim.notify("Executable '" .. executable .. "' not found", vim.log.levels.ERROR)
        return nil
    end
end

return M
