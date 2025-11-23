-- Demo Scenario 3: Advanced Features
-- Showcases intelligent pruning, location recovery, and multi-project workflows

local demo = {}

function demo.setup()
    require("spaghetti-comb").setup({
        history = {
            max_entries = 1000,
            max_age_minutes = 30,
            pruning_debounce_minutes = 2,
            exploration_timeout_minutes = 5,
        },
        bookmarks = {
            frequent_threshold = 3,
            auto_bookmark_frequent = true,
        },
    })
end

-- Demo: Inconsequential jump pruning
function demo.inconsequential_jump_pruning()
    print("\nInconsequential Jump Pruning Demo")
    print("=================================\n")

    local history_manager = require("spaghetti-comb.history.manager")
    history_manager.clear_all_history()
    history_manager.set_current_project(vim.fn.getcwd())

    print("Recording navigation within same file...")
    print("(Small movements are considered inconsequential)")

    -- Create small jumps within same file
    local file_path = vim.fn.getcwd() .. "/src/history/manager.lua"
    local lines = { 10, 12, 14, 16, 18, 100, 105, 110 }

    for i = 1, #lines - 1 do
        local from_loc = { file_path = file_path, position = { line = lines[i], column = 1 } }
        local to_loc = { file_path = file_path, position = { line = lines[i + 1], column = 1 } }

        history_manager.record_jump(from_loc, to_loc, "auto")
        print(string.format("  Jump: line %d → %d (distance: %d)", lines[i], lines[i + 1], lines[i + 1] - lines[i]))
    end

    local trail = history_manager.get_current_trail()
    local initial_count = #trail.entries
    print(string.format("\nTotal jumps recorded: %d", initial_count))

    -- Prune inconsequential jumps
    print("\nPruning inconsequential jumps...")
    local pruned_entries = history_manager.prune_inconsequential_jumps(trail.entries)

    print(string.format("After pruning: %d entries", #pruned_entries))
    print(string.format("Removed: %d small movements", initial_count - #pruned_entries))

    print("\nPruning rules:")
    print("  ✓ Same file + small distance (<5 lines) → pruned")
    print("  ✓ Quick succession (<30 seconds) → pruned")
    print("  ✗ Manual jumps → kept")
    print("  ✗ Cross-file jumps → kept")
    print("  ✗ Large distance jumps → kept")
end

-- Demo: Automatic frequent location detection
function demo.frequent_location_detection()
    print("\n\nFrequent Location Detection Demo")
    print("================================\n")

    local bookmarks = require("spaghetti-comb.history.bookmarks")
    bookmarks.clear_all_bookmarks(true)

    print("Recording visits to same location...")
    print("(Locations visited 3+ times become auto-bookmarked)")

    local frequent_location = {
        file_path = vim.fn.getcwd() .. "/src/config.lua",
        position = { line = 53, column = 1 },
    }

    -- Visit location multiple times
    for i = 1, 5 do
        print(string.format("\n  Visit #%d", i))
        bookmarks.increment_visit_count(frequent_location)

        local visit_count = bookmarks.get_visit_count(frequent_location)
        print(string.format("    Visit count: %d", visit_count))

        if visit_count >= 3 then
            print("    Status: 🔥 Frequent location!")
        end
    end

    -- Check if auto-bookmarked
    local is_frequent = bookmarks.is_frequent_location(frequent_location)
    print(string.format("\n✓ Auto-bookmarked as frequent: %s", is_frequent and "Yes" or "No"))

    -- Show all frequent locations
    local frequent_locs = bookmarks.get_frequent_locations()
    print(string.format("\nTotal frequent locations: %d", #frequent_locs))
end

-- Demo: Multi-project workflow
function demo.multi_project_workflow()
    print("\n\nMulti-Project Workflow Demo")
    print("===========================\n")

    local history_manager = require("spaghetti-comb.history.manager")
    history_manager.clear_all_history()

    print("Working with multiple projects...")
    print("Each project maintains separate history\n")

    local projects = {
        {
            name = "neovim-plugin",
            root = "/home/user/projects/neovim-plugin",
            files = { "init.lua", "config.lua", "ui/main.lua" },
        },
        {
            name = "web-app",
            root = "/home/user/projects/web-app",
            files = { "app.js", "routes/index.js", "controllers/user.js" },
        },
        {
            name = "cli-tool",
            root = "/home/user/projects/cli-tool",
            files = { "main.go", "cmd/root.go", "pkg/parser.go" },
        },
    }

    -- Record navigation in each project
    for _, project in ipairs(projects) do
        print(string.format("Project: %s", project.name))
        history_manager.set_current_project(project.root)

        for i = 1, #project.files - 1 do
            local from_loc = {
                file_path = project.root .. "/" .. project.files[i],
                position = { line = 10 * i, column = 1 },
            }
            local to_loc = {
                file_path = project.root .. "/" .. project.files[i + 1],
                position = { line = 10 * (i + 1), column = 1 },
            }

            history_manager.record_jump(from_loc, to_loc, "manual")
            print(string.format("  ✓ %s → %s", project.files[i], project.files[i + 1]))
        end

        local trail = history_manager.get_current_trail()
        print(string.format("  History entries: %d\n", #trail.entries))
    end

    -- Show all projects
    print("All project trails:")
    local all_projects = history_manager.get_all_project_trails()
    for project_root, data in pairs(all_projects) do
        print(string.format("  %s: %d entries", project_root, data.stats.total_entries))
    end

    -- Switch between projects
    print("\nSwitching to 'web-app' project...")
    local success = history_manager.switch_to_project("/home/user/projects/web-app")
    if success then
        local trail = history_manager.get_current_trail()
        print(string.format("  ✓ Loaded %d entries for web-app", #trail.entries))
    end
end

-- Demo: Location recovery after code changes
function demo.location_recovery()
    print("\n\nLocation Recovery Demo")
    print("======================\n")

    local history_manager = require("spaghetti-comb.history.manager")

    print("Simulating location recovery after file edits...")
    print("(In real usage, this handles line shifts from code changes)")

    -- Create entry with context
    local entry = {
        file_path = vim.fn.getcwd() .. "/src/history/manager.lua",
        position = { line = 100, column = 5 },
        original_position = { line = 100, column = 5 },
        timestamp = os.time() - 3600, -- 1 hour ago
        context = {
            before_lines = { "-- Setup the history manager", "function M.setup(config)" },
            after_lines = { "    state.config = config or {}", "    state.initialized = true" },
            function_name = "M.setup",
        },
        jump_type = "manual",
    }

    print("\nOriginal location:")
    print(string.format("  File: %s", entry.file_path))
    print(string.format("  Line: %d", entry.position.line))
    print(string.format("  Function: %s", entry.context.function_name))

    print("\nRecovery strategies:")
    print("  1. Context matching - Match surrounding lines")
    print("  2. Function search - Find function by name")
    print("  3. Symbol search - Use unique code patterns")

    print("\nAttempting recovery...")
    print("  ✓ Would search for function 'M.setup'")
    print("  ✓ Would match context lines")
    print("  ✓ Would update position if shifted")

    print("\nResult: Location recovered successfully")
    print("  New line: 105 (shifted by +5 lines)")
end

-- Demo: Branch visualization
function demo.branch_visualization()
    print("\n\nBranch Visualization Demo")
    print("=========================\n")

    local history_manager = require("spaghetti-comb.history.manager")
    history_manager.clear_all_history()
    history_manager.set_current_project(vim.fn.getcwd())

    print("Creating branching navigation paths...")
    print("(Like Git branches for your code exploration)\n")

    -- Main branch
    print("Main branch:")
    for i = 1, 3 do
        local from_loc = { file_path = "/test/file" .. i .. ".lua", position = { line = i, column = 1 } }
        local to_loc = { file_path = "/test/file" .. (i + 1) .. ".lua", position = { line = i + 1, column = 1 } }
        history_manager.record_jump(from_loc, to_loc, "manual")
        print(string.format("  %d → %d", i, i + 1))
    end

    -- Create branch at position 2
    print("\nCreating branch from position 2:")
    history_manager.navigate_to_index(2)

    local branch_loc = { file_path = "/test/branch.lua", position = { line = 10, column = 1 } }
    local from_loc = { file_path = "/test/file2.lua", position = { line = 2, column = 1 } }
    history_manager.record_jump(from_loc, branch_loc, "manual")
    print("  2 → branch (new exploration path)")

    -- Show branch structure
    local branches = history_manager.get_active_branches()
    print(string.format("\nActive branches: %d", #branches))
    for i, branch in ipairs(branches) do
        print(string.format("  Branch %d:", i))
        print(string.format("    ID: %s", branch.id:sub(1, 8) .. "..."))
        print(string.format("    From index: %d", branch.from_index))
    end

    print("\nVisualization (use :SpaghettiCombTree):")
    print("  └─ file1.lua")
    print("     └─ file2.lua")
    print("        ├─ file3.lua (main)")
    print("        └─ branch.lua (branch)")
end

-- Demo: Performance metrics
function demo.performance_metrics()
    print("\n\nPerformance Metrics Demo")
    print("========================\n")

    local history_manager = require("spaghetti-comb.history.manager")
    history_manager.clear_all_history()
    history_manager.set_current_project("/test/performance")

    print("Testing performance with large history...")

    -- Record many jumps
    local start_time = os.clock()
    local jump_count = 1000

    for i = 1, jump_count do
        local from_loc = { file_path = "/test/file" .. i .. ".lua", position = { line = i, column = 1 } }
        local to_loc = { file_path = "/test/file" .. (i + 1) .. ".lua", position = { line = i + 1, column = 1 } }
        history_manager.record_jump(from_loc, to_loc, "manual")
    end

    local elapsed = os.clock() - start_time

    print(string.format("\nRecorded %d jumps in %.3f seconds", jump_count, elapsed))
    print(string.format("Average: %.3f ms per jump", (elapsed / jump_count) * 1000))

    -- Test navigation performance
    start_time = os.clock()
    for i = 1, 100 do
        history_manager.go_back(1)
        history_manager.go_forward(1)
    end
    elapsed = os.clock() - start_time

    print(string.format("\n100 back/forward operations: %.3f seconds", elapsed))

    -- Memory usage (approximate)
    local trail = history_manager.get_current_trail()
    local entries_size = #trail.entries
    print(string.format("\nMemory usage:"))
    print(string.format("  Entries: %d", entries_size))
    print(string.format("  Est. size: ~%.2f KB", (entries_size * 200) / 1024))
end

-- Run all advanced demos
function demo.run_all()
    print("\n╔════════════════════════════════════════╗")
    print("║   Advanced Features Demo              ║")
    print("╚════════════════════════════════════════╝")

    demo.setup()

    demo.inconsequential_jump_pruning()
    demo.frequent_location_detection()
    demo.multi_project_workflow()
    demo.location_recovery()
    demo.branch_visualization()
    demo.performance_metrics()

    print("\n╔════════════════════════════════════════╗")
    print("║   Advanced Demo Complete!             ║")
    print("╚════════════════════════════════════════╝\n")
end

return demo
