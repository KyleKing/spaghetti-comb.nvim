local utils = require("spaghetti-comb.utils")
local navigation = require("spaghetti-comb.navigation")

local M = {}

local function get_session_dir()
    local data_path = vim.fn.stdpath("data")
    local session_dir = data_path .. "/spaghetti-comb/sessions"

    if vim.fn.isdirectory(session_dir) == 0 then vim.fn.mkdir(session_dir, "p") end

    return session_dir
end

local function get_session_file(name)
    local session_dir = get_session_dir()
    name = name or "default"
    return session_dir .. "/" .. name .. ".json"
end

local function serialize_session()
    local stack_entries = navigation.get_stack_entries()
    local stack_info = navigation.get_stack_info()

    local session_data = {
        version = "1.0",
        timestamp = os.time(),
        working_directory = vim.fn.getcwd(),
        navigation_stack = {
            current_index = stack_info.current_index,
            entries = stack_entries,
        },
        metadata = {
            project_root = utils.get_project_root(),
            nvim_version = vim.version(),
            total_entries = #stack_entries,
        },
    }

    return vim.json.encode(session_data)
end

local function deserialize_session(json_data)
    local success, session_data = pcall(vim.json.decode, json_data)
    if not success then return nil, "Failed to parse session JSON" end

    if not session_data.version or not session_data.navigation_stack then return nil, "Invalid session format" end

    return session_data, nil
end

function M.save_session(name)
    local session_file = get_session_file(name)

    local json_data = serialize_session()

    local file = io.open(session_file, "w")
    if not file then
        utils.error("Failed to create session file: " .. session_file)
        return false
    end

    file:write(json_data)
    file:close()

    utils.info("Session saved to: " .. session_file)
    return true
end

function M.load_session(name)
    local session_file = get_session_file(name)

    if vim.fn.filereadable(session_file) == 0 then
        utils.warn("Session file not found: " .. session_file)
        return false
    end

    local file = io.open(session_file, "r")
    if not file then
        utils.error("Failed to read session file: " .. session_file)
        return false
    end

    local json_data = file:read("*a")
    file:close()

    local session_data, err = deserialize_session(json_data)
    if not session_data then
        utils.error("Failed to load session: " .. (err or "unknown error"))
        return false
    end

    navigation.clear_stack()

    if session_data.working_directory and vim.fn.isdirectory(session_data.working_directory) == 1 then
        vim.cmd("cd " .. vim.fn.fnameescape(session_data.working_directory))
    end

    local nav_stack = session_data.navigation_stack
    if nav_stack and nav_stack.entries then
        for _, entry in ipairs(nav_stack.entries) do
            if vim.fn.filereadable(entry.file) == 1 then
                local symbol_info = {
                    text = entry.symbol,
                    type = entry.type or "unknown",
                    bufnr = vim.fn.bufnr(entry.file, true),
                }
                navigation.push(symbol_info)

                local current = navigation.peek()
                if current then
                    for key, value in pairs(entry) do
                        if key ~= "symbol" then current[key] = value end
                    end
                end
            else
                utils.warn("Skipping missing file in session: " .. entry.file)
            end
        end

        if nav_stack.current_index and nav_stack.current_index > 0 then
            navigation.jump_to_index(nav_stack.current_index)
        end
    end

    utils.info(string.format("Session loaded from: %s (%d entries)", session_file, #(nav_stack.entries or {})))
    return true
end

function M.list_sessions()
    local session_dir = get_session_dir()
    local sessions = {}

    local handle = vim.loop.fs_scandir(session_dir)
    if handle then
        while true do
            local name, type = vim.loop.fs_scandir_next(handle)
            if not name then break end

            if type == "file" and name:match("%.json$") then
                local session_name = name:gsub("%.json$", "")
                local session_file = session_dir .. "/" .. name
                local stat = vim.loop.fs_stat(session_file)

                table.insert(sessions, {
                    name = session_name,
                    file = session_file,
                    mtime = stat and stat.mtime.sec or 0,
                    size = stat and stat.size or 0,
                })
            end
        end
    end

    table.sort(sessions, function(a, b) return a.mtime > b.mtime end)

    return sessions
end

function M.delete_session(name)
    local session_file = get_session_file(name)

    if vim.fn.filereadable(session_file) == 0 then
        utils.warn("Session file not found: " .. session_file)
        return false
    end

    local success = os.remove(session_file)
    if success then
        utils.info("Session deleted: " .. session_file)
        return true
    else
        utils.error("Failed to delete session: " .. session_file)
        return false
    end
end

function M.save_navigation_stack(stack)
    if not stack or not stack.entries then return false end

    return M.save_session("auto_backup_" .. os.time())
end

function M.load_navigation_stack()
    local sessions = M.list_sessions()
    for _, session in ipairs(sessions) do
        if session.name:match("^auto_backup_") then
            local success = M.load_session(session.name)
            if success then return navigation.get_stack_entries() end
        end
    end
    return nil
end

function M.get_session_info(name)
    local session_file = get_session_file(name)

    if vim.fn.filereadable(session_file) == 0 then return nil end

    local file = io.open(session_file, "r")
    if not file then return nil end

    local json_data = file:read("*a")
    file:close()

    local session_data, err = deserialize_session(json_data)
    if not session_data then return nil end

    local stat = vim.loop.fs_stat(session_file)

    return {
        name = name,
        version = session_data.version,
        timestamp = session_data.timestamp,
        working_directory = session_data.working_directory,
        total_entries = session_data.metadata and session_data.metadata.total_entries or 0,
        file_size = stat and stat.size or 0,
        file_mtime = stat and stat.mtime.sec or 0,
    }
end

return M
