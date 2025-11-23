-- Demo Scenario 1: Basic Navigation History Tracking
-- This demo showcases the core functionality of Spaghetti Comb

local demo = {}

-- Initialize the plugin
function demo.setup()
    require("spaghetti-comb").setup({
        history = {
            max_entries = 1000,
            max_age_minutes = 30,
            save_on_exit = true,
        },
        display = {
            max_items = 10,
            hotkey_only = true,
        },
        integration = {
            jumplist = true,
            lsp = true,
        },
    })
end

-- Demo 1: Recording and navigating jumps
function demo.navigate_between_files()
    print("Demo 1: Basic Navigation")
    print("========================")

    local history_manager = require("spaghetti-comb.history.manager")
    history_manager.set_current_project(vim.fn.getcwd())

    -- Simulate jumping between files
    local files = {
        { path = "src/init.lua", line = 10 },
        { path = "src/config.lua", line = 25 },
        { path = "src/ui/breadcrumbs.lua", line = 50 },
        { path = "src/history/manager.lua", line = 100 },
    }

    print("\nRecording navigation jumps...")
    for i = 1, #files - 1 do
        local from_location = {
            file_path = vim.fn.getcwd() .. "/" .. files[i].path,
            position = { line = files[i].line, column = 1 },
        }
        local to_location = {
            file_path = vim.fn.getcwd() .. "/" .. files[i + 1].path,
            position = { line = files[i + 1].line, column = 1 },
        }

        local success = history_manager.record_jump(from_location, to_location, "manual")
        if success then
            print(string.format("  ✓ Jump %d→%d: %s:%d → %s:%d", i, i + 1, files[i].path, files[i].line, files[i + 1].path, files[i + 1].line))
        end
    end

    -- Show statistics
    local stats = history_manager.get_stats()
    print(string.format("\nNavigation Statistics:"))
    print(string.format("  Total entries: %d", stats.total_entries))
    print(string.format("  Current index: %d", stats.current_index))
    print(string.format("  Exploration state: %s", stats.exploration_state))

    -- Navigate backward
    print("\nNavigating backward...")
    history_manager.go_back(2)
    local current_entry = history_manager.get_current_entry()
    if current_entry then
        print(string.format("  Current location: %s:%d", current_entry.file_path, current_entry.position.line))
    end

    -- Navigate forward
    print("\nNavigating forward...")
    history_manager.go_forward(1)
    current_entry = history_manager.get_current_entry()
    if current_entry then
        print(string.format("  Current location: %s:%d", current_entry.file_path, current_entry.position.line))
    end
end

-- Demo 2: Branch creation
function demo.branching_navigation()
    print("\nDemo 2: Branching Navigation")
    print("============================")

    local history_manager = require("spaghetti-comb.history.manager")

    print("\nCreating navigation branches...")
    print("  1. Navigate to position 2")
    history_manager.navigate_to_index(2)

    print("  2. Jump to a new location (creates a branch)")
    local branch_location = {
        file_path = vim.fn.getcwd() .. "/src/types.lua",
        position = { line = 42, column = 5 },
    }
    local from_location = {
        file_path = vim.fn.getcwd() .. "/src/config.lua",
        position = { line = 25, column = 1 },
    }

    history_manager.record_jump(from_location, branch_location, "manual")

    local branches = history_manager.get_active_branches()
    print(string.format("\n  Active branches: %d", #branches))
    for i, branch in ipairs(branches) do
        print(string.format("    Branch %d: ID=%s, created at index %d", i, branch.id, branch.from_index))
    end
end

-- Demo 3: Bookmarks
function demo.bookmark_management()
    print("\nDemo 3: Bookmark Management")
    print("===========================")

    local bookmarks = require("spaghetti-comb.history.bookmarks")

    -- Add manual bookmarks
    print("\nAdding bookmarks...")
    local bookmark_locations = {
        { file = "src/init.lua", line = 17, desc = "Main entry point" },
        { file = "src/config.lua", line = 53, desc = "Config validation" },
        { file = "src/history/manager.lua", line = 200, desc = "Pruning logic" },
    }

    for _, loc in ipairs(bookmark_locations) do
        local location = {
            file_path = vim.fn.getcwd() .. "/" .. loc.file,
            position = { line = loc.line, column = 1 },
        }
        local success, bookmark = bookmarks.add_bookmark(location, true)
        if success then
            print(string.format("  ✓ Bookmarked: %s:%d - %s", loc.file, loc.line, loc.desc))
        end
    end

    -- List all bookmarks
    local all_bookmarks = bookmarks.get_all_bookmarks()
    print(string.format("\nTotal bookmarks: %d", #all_bookmarks))

    -- Toggle a bookmark
    print("\nToggling bookmark at src/init.lua:17...")
    local toggle_location = {
        file_path = vim.fn.getcwd() .. "/src/init.lua",
        position = { line = 17, column = 1 },
    }
    local success, action = bookmarks.toggle_bookmark(toggle_location)
    print(string.format("  Action: %s", action))
end

-- Demo 4: UI Components
function demo.ui_components()
    print("\nDemo 4: UI Components")
    print("=====================")

    print("\nUI components available:")
    print("  1. Breadcrumbs - :SpaghettiCombBreadcrumbs")
    print("  2. Navigation Tree - :SpaghettiCombTree")
    print("  3. Bookmark Picker - :SpaghettiCombBookmarks")
    print("  4. History Picker - :SpaghettiCombHistory")
    print("\nNote: UI components require an active Neovim session")
    print("      Run these commands in Neovim to see the UI")
end

-- Demo 5: Persistence
function demo.persistence()
    print("\nDemo 5: Persistence")
    print("===================")

    local history_manager = require("spaghetti-comb.history.manager")
    local bookmarks = require("spaghetti-comb.history.bookmarks")
    local storage = require("spaghetti-comb.history.storage")

    -- Save current session
    print("\nSaving navigation history...")
    local success, msg = history_manager.save_current_project_history()
    print(string.format("  %s", msg))

    print("\nSaving bookmarks...")
    success, msg = bookmarks.save_current_project_bookmarks()
    print(string.format("  %s", msg))

    -- Show storage statistics
    local stats = storage.get_storage_stats()
    print(string.format("\nStorage Statistics:"))
    print(string.format("  History files: %d", stats.history_count))
    print(string.format("  Bookmark files: %d", stats.bookmark_count))
    print(string.format("  Total size: %d bytes", stats.total_size))
    print(string.format("  Storage directory: %s", stats.storage_dir))

    -- List saved projects
    print("\nSaved projects:")
    local projects = storage.list_saved_projects()
    for i, project in ipairs(projects) do
        print(string.format("  %d. %s (%d bytes)", i, project.hash, project.size))
    end
end

-- Run all demos
function demo.run_all()
    print("\n╔════════════════════════════════════════╗")
    print("║   Spaghetti Comb Demo Scenarios      ║")
    print("╚════════════════════════════════════════╝\n")

    demo.setup()

    -- Allow some time between demos
    local function pause()
        print("\n" .. string.rep("-", 50))
    end

    demo.navigate_between_files()
    pause()

    demo.branching_navigation()
    pause()

    demo.bookmark_management()
    pause()

    demo.ui_components()
    pause()

    demo.persistence()

    print("\n╔════════════════════════════════════════╗")
    print("║   Demo Complete!                      ║")
    print("╚════════════════════════════════════════╝\n")
end

return demo
