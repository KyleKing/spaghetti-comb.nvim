-- Scale probe for trail hot paths: 1000-entry trail + 100 bookmarks.
-- Run: nvim --headless --noplugin -u scripts/minimal_init.lua -l scripts/bench.lua
local manager = require("spaghetti-comb.history.manager")
local picker = require("spaghetti-comb.ui.picker")
local bookmarks = require("spaghetti-comb.history.bookmarks")

local function bench(name, fn)
    local start = vim.uv.hrtime()
    local result = fn()
    local ms = (vim.uv.hrtime() - start) / 1e6
    print(string.format("%-42s %8.2f ms", name, ms))
    return result
end

manager.setup({})
manager.set_current_project("/bench/project")

local trail = manager.get_current_trail()

bench("build 1000 entries (direct insert)", function()
    for i = 1, 1000 do
        table.insert(
            trail.entries,
            require("spaghetti-comb.types").create_navigation_entry({
                file_path = "/bench/project/src/mod" .. (i % 50) .. ".lua",
                position = { line = i, column = 1 },
                timestamp = os.time() - (1000 - i) * 60,
                jump_type = i % 5 == 0 and "vera_seek" or "manual",
                context = { function_name = "fn_" .. i, before_lines = { "ctx" }, after_lines = { "ctx" } },
            })
        )
    end
    trail.current_index = 1000
end)

bench("record_jump x100 (cap enforcement live)", function()
    for i = 1001, 1100 do
        manager.record_jump(nil, {
            file_path = "/bench/project/src/mod" .. (i % 50) .. ".lua",
            position = { line = i, column = 1 },
        }, "manual")
    end
end)

local sorted
bench("sort_by_score x1000 entries", function() sorted = picker.sort_by_score(trail.entries) end)
bench("sort_by_recency x1000 entries", function() picker.sort_by_recency(trail.entries) end)
bench("_format_navigation_item x1000", function()
    for _, e in ipairs(trail.entries) do
        picker._format_navigation_item(e)
    end
end)
bench("_build_search_text x1000", function()
    for _, e in ipairs(trail.entries) do
        picker._build_search_text(e)
    end
end)
bench("filter_navigation_entries (match ~50)", function() picker.filter_navigation_entries(trail.entries, "fn_5") end)
bench("entry_score x10000 (repeat ranking cost)", function()
    for _ = 1, 10 do
        for _, e in ipairs(trail.entries) do
            manager.entry_score(e)
        end
    end
end)

bench("save trail (json encode + write)", function() manager.save_current_project_history() end)
bench("load trail (read + decode + validate)", function()
    manager.reset()
    manager.setup({})
    manager.set_current_project("/bench/project")
    manager.load_project_history("/bench/project")
end)

bench("add 100 bookmarks", function()
    for i = 1, 100 do
        bookmarks.toggle_bookmark({
            file_path = "/bench/project/src/mod" .. i .. ".lua",
            position = { line = i, column = 1 },
        })
    end
end)
bench("bookmark frecency sort + format x100", function()
    local all = bookmarks.get_all_bookmarks("/bench/project") or {}
    picker.sort_by_frecency(all)
    for _, b in ipairs(all) do
        picker._format_bookmark_item(b)
    end
end)

print("sorted[1].file_path:", sorted and sorted[1] and sorted[1].file_path)
print("done")
