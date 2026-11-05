-- Project orientation map: vera overview + unguided structural sweeps shown
-- in ui.relations_tree. <C-]> is a no-op here — orient rows carry locations,
-- not symbols with a relations query to re-root on.
local codanna = require("spaghetti-comb.substrate.codanna")
local project = require("spaghetti-comb.utils.project")
local vera = require("spaghetti-comb.substrate.vera")

local M = {}

-- Structural intents that run without a query term; definitions and impls
-- require one, so they can't seed an unguided sweep.
M.STRUCTURE_INTENTS = {
    { intent = "routes", label = "Routes" },
    { intent = "env", label = "Env vars" },
    { intent = "sql", label = "SQL sites" },
}

---@class OrientReport
---@field root_path string|nil
---@field overview table|string|nil vera overview, parsed or raw prose
---@field structure table<string, SearchHit[]> intent -> hits
---@field codanna_health IndexHealth|nil
---@field errors string[]

-- Fetch every orientation source in parallel and collect a single report;
-- per-source failures land in report.errors instead of aborting the rest.
---@param callback fun(report: OrientReport)
function M._collect(callback)
    ---@type OrientReport
    local report = { structure = {}, errors = {} }
    report.root_path = project.get_current_project_root()

    local pending = #M.STRUCTURE_INTENTS + 2
    local function done()
        pending = pending - 1
        if pending == 0 then callback(report) end
    end

    vera.overview(function(overview, err)
        if err then
            table.insert(report.errors, err)
        else
            report.overview = overview
        end
        done()
    end)

    for _, si in ipairs(M.STRUCTURE_INTENTS) do
        vera.structural(si.intent, nil, function(hits, err)
            if err then
                table.insert(report.errors, err)
            else
                report.structure[si.intent] = hits
            end
            done()
        end)
    end

    codanna.index_health(function(health, err)
        if err then
            table.insert(report.errors, err)
        else
            report.codanna_health = health
        end
        done()
    end)
end

-- The tree formatter already appends basename:line, so name only falls back
-- to a location when the hit names no symbol.
---@param hit SearchHit
---@return RelationItem
function M._hit_item(hit)
    return {
        name = hit.symbol_name or (hit.file_path .. ":" .. hit.line_start),
        kind = hit.symbol_type,
        file_path = hit.file_path,
        line = hit.line_start,
    }
end

---@param hits SearchHit[]
---@return RelationItem[]
function M._hit_items(hits)
    local items = {}
    for _, hit in ipairs(hits) do
        table.insert(items, M._hit_item(hit))
    end
    return items
end

-- Read-only info line; no file_path so the tree renders it unjumpable.
---@param text string
---@return RelationItem
local function info_item(text) return { name = text } end

---@param n number
---@return string
local function file_word(n) return n == 1 and "file" or "files" end

-- Groups extracted from a parsed `vera overview --json` table. Hotspots and
-- entry points jump to their file; everything else renders as info lines.
---@param overview table
---@return RelationsGroup[]
function M._overview_groups(overview)
    local groups = {}

    if vim.islist(overview.entry_points) and #overview.entry_points > 0 then
        local items = {}
        for _, ep in ipairs(overview.entry_points) do
            local file_path = type(ep) == "table" and ep.file_path or ep
            table.insert(items, { name = file_path, file_path = file_path, line = 1 })
        end
        table.insert(groups, { label = "Entry points", items = items })
    end

    if vim.islist(overview.hotspots) and #overview.hotspots > 0 then
        local items = {}
        for _, spot in ipairs(overview.hotspots) do
            table.insert(items, {
                name = spot.file_path,
                kind = spot.chunks and (spot.chunks .. " chunks") or nil,
                file_path = spot.file_path,
                line = 1,
            })
        end
        table.insert(groups, { label = "Hotspots", items = items })
    end

    local info = {}
    for _, lang in ipairs(overview.languages or {}) do
        table.insert(
            info,
            info_item(
                string.format(
                    "lang %s: %d %s, %d chunks",
                    lang.language,
                    lang.files,
                    file_word(lang.files),
                    lang.chunks
                )
            )
        )
    end
    for _, dir in ipairs(overview.top_directories or {}) do
        table.insert(info, info_item(string.format("dir %s: %d %s", dir.directory, dir.files, file_word(dir.files))))
    end
    for _, sym in ipairs(overview.symbol_types or {}) do
        table.insert(info, info_item(string.format("type %s: %d", sym.symbol_type, sym.count)))
    end
    for _, convention in ipairs(overview.conventions or {}) do
        table.insert(info, info_item("convention: " .. tostring(convention)))
    end
    if #info > 0 then table.insert(groups, { label = "Overview", items = info }) end

    return groups
end

-- Turn a collect report into the tree's root + groups. When overview comes
-- back as prose (older vera), its lines render read-only.
---@param report OrientReport
---@return RelationsRoot root
---@return RelationsGroup[] groups
function M._build(report)
    local name = report.root_path and vim.fs.basename(report.root_path) or "project"

    local stats = {}
    if type(report.overview) == "table" then
        if report.overview.file_count then
            table.insert(stats, report.overview.file_count .. " " .. file_word(report.overview.file_count))
        end
        if report.overview.chunk_count then table.insert(stats, report.overview.chunk_count .. " chunks") end
    end
    local health = report.codanna_health
    if health then
        if health.symbol_count then table.insert(stats, health.symbol_count .. " symbols") end
        if health.edge_count then table.insert(stats, health.edge_count .. " edges") end
    end
    if #stats > 0 then name = name .. " — " .. table.concat(stats, ", ") end

    local root = { name = name }
    local groups = {}

    for _, si in ipairs(M.STRUCTURE_INTENTS) do
        local hits = report.structure[si.intent]
        if hits and #hits > 0 then table.insert(groups, { label = si.label, items = M._hit_items(hits) }) end
    end

    if type(report.overview) == "table" then
        vim.list_extend(groups, M._overview_groups(report.overview))
    elseif type(report.overview) == "string" and report.overview ~= "" then
        local items = {}
        for _, line in ipairs(vim.split(report.overview, "\n")) do
            if vim.trim(line) ~= "" then table.insert(items, info_item(line)) end
        end
        if #items > 0 then table.insert(groups, { label = "Overview", items = items }) end
    end

    return root, groups
end

-- Collect orientation data and show it in the relations tree. <CR> jumps to
-- the row's file:line and records a trail entry; <C-]> is unbound in this
-- view. Sources that failed are reported in one warning.
function M.show()
    M._collect(function(report)
        local root, groups = M._build(report)

        if #groups == 0 then
            local detail = #report.errors > 0 and table.concat(report.errors, "\n")
                or "no orientation data for this project"
            vim.notify(detail, vim.log.levels.WARN)
            return
        end

        require("spaghetti-comb.ui.relations_tree").show(root, groups, {
            title = " Orient: " .. (report.root_path or "") .. " ",
            on_jump = function(item) require("spaghetti-comb.navigation.relations").jump_to_item(item, "orient") end,
        })

        if #report.errors > 0 then vim.notify(table.concat(report.errors, "\n"), vim.log.levels.WARN) end
    end)
end

return M
