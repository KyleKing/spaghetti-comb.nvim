local utils = require("spaghetti-comb-v1.utils")
local navigation = require("spaghetti-comb-v1.navigation")

local M = {}

local function get_session_dir()
    local data_path = vim.fn.stdpath("data")
    local session_dir = data_path .. "/spaghetti-comb-v1/sessions"

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
        version = "1.1",
        timestamp = os.time(),
        working_directory = vim.fn.getcwd(),
        window_layout = {
            current_win = vim.api.nvim_get_current_win(),
            current_buf = vim.api.nvim_get_current_buf(),
            current_tab = vim.api.nvim_get_current_tabpage(),
            layout_info = vim.fn.winrestcmd(),
        },
        navigation_stack = {
            current_index = stack_info.current_index,
            entries = stack_entries,
        },
        metadata = {
            project_root = utils.get_project_root(),
            nvim_version = vim.version(),
            total_entries = #stack_entries,
            session_id = string.format("%s_%d", vim.fn.hostname(), os.time()),
            git_branch = utils.get_git_branch(),
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

    utils.log_action("session_saved", session_file)
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

    if session_data.window_layout and session_data.window_layout.layout_info then
        pcall(function() vim.cmd(session_data.window_layout.layout_info) end)
    end

    utils.log_action("session_loaded", string.format("%s (%d entries)", session_file, #(nav_stack.entries or {})))
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
        utils.log_action("session_deleted", session_file)
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
        session_id = session_data.metadata and session_data.metadata.session_id,
        git_branch = session_data.metadata and session_data.metadata.git_branch,
    }
end

function M.auto_backup_session()
    local stack_info = navigation.get_stack_info()
    if stack_info.total_entries == 0 then return false end

    local backup_name = string.format("auto_%s_%d", os.date("%Y%m%d_%H%M%S"), math.random(1000, 9999))

    return M.save_session(backup_name)
end

function M.restore_context_from_entry(entry)
    if not entry or not entry.context then return false end

    local context = entry.context

    if context.working_dir and vim.fn.isdirectory(context.working_dir) == 1 then
        vim.cmd("cd " .. vim.fn.fnameescape(context.working_dir))
    end

    if context.view then pcall(vim.fn.winrestview, context.view) end

    if context.win_config and context.win_config.relative and context.win_config.relative ~= "" then
        local current_win = vim.api.nvim_get_current_win()
        pcall(vim.api.nvim_win_set_config, current_win, context.win_config)
    end

    return true
end

function M.clean_old_auto_sessions(max_age_days)
    max_age_days = max_age_days or 7
    local cutoff_time = os.time() - (max_age_days * 24 * 60 * 60)

    local sessions = M.list_sessions()
    local cleaned_count = 0

    for _, session in ipairs(sessions) do
        if session.name:match("^auto_") and session.mtime < cutoff_time then
            if M.delete_session(session.name) then cleaned_count = cleaned_count + 1 end
        end
    end

    if cleaned_count > 0 then
        utils.log_action("sessions_cleaned", string.format("%d old auto-backup sessions", cleaned_count))
    end

    return cleaned_count
end

return M
