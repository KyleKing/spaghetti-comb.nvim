local utils = require("spaghetti-comb.utils")

local M = {}

local bookmarks_state = {
    bookmarks = {},
    collections = {},
    auto_save = true,
}

local BOOKMARKS_VERSION = "1.0"

function M.get_bookmarks_file()
    local data_path = vim.fn.stdpath("data")
    local bookmarks_dir = data_path .. "/spaghetti-comb"

    if vim.fn.isdirectory(bookmarks_dir) == 0 then vim.fn.mkdir(bookmarks_dir, "p") end

    return bookmarks_dir .. "/bookmarks.json"
end

function M.create_bookmark_entry(location, name, collection)
    if not location then return nil end

    local bookmark = {
        id = M.generate_bookmark_id(),
        name = name or M.generate_bookmark_name(location),
        collection = collection or "default",
        location = {
            path = location.path or location.file,
            line = location.line,
            col = location.col or 1,
            text = location.text or "",
            relative_path = utils.get_relative_path(location.path or location.file),
        },
        symbol_info = {
            symbol = location.symbol or location.text or "",
            type = location.type or "unknown",
            language = utils.get_buffer_language(),
        },
        metadata = {
            created_at = os.time(),
            created_by = "spaghetti-comb",
            project_root = utils.get_project_root(),
            git_branch = utils.get_git_branch(),
        },
        tags = {},
        notes = "",
        coupling_score = location.coupling_score or 0.0,
    }

    return bookmark
end

function M.add_bookmark(location, name, collection)
    if not location then
        utils.warn("Cannot create bookmark: invalid location")
        return false
    end

    local bookmark = M.create_bookmark_entry(location, name, collection)
    if not bookmark then
        utils.warn("Failed to create bookmark entry")
        return false
    end

    collection = collection or "default"

    -- Ensure collection exists
    if not bookmarks_state.collections[collection] then
        bookmarks_state.collections[collection] = {
            name = collection,
            created_at = os.time(),
            bookmarks = {},
            description = "",
        }
    end

    -- Check for duplicates
    local existing_id = M.find_duplicate_bookmark(bookmark)
    if existing_id then
        utils.debug("Bookmark already exists: " .. bookmark.name)
        return existing_id
    end

    -- Add bookmark to state
    bookmarks_state.bookmarks[bookmark.id] = bookmark
    table.insert(bookmarks_state.collections[collection].bookmarks, bookmark.id)

    if bookmarks_state.auto_save then M.save_bookmarks() end

    utils.log_action("bookmark_added", bookmark.name)
    return bookmark.id
end

function M.remove_bookmark(location_or_id)
    local bookmark_id

    if type(location_or_id) == "string" then
        bookmark_id = location_or_id
    else
        -- Find bookmark by location
        bookmark_id = M.find_bookmark_by_location(location_or_id)
    end

    if not bookmark_id or not bookmarks_state.bookmarks[bookmark_id] then
        utils.warn("Bookmark not found")
        return false
    end

    local bookmark = bookmarks_state.bookmarks[bookmark_id]
    local collection_name = bookmark.collection

    -- Remove from collection
    if bookmarks_state.collections[collection_name] then
        local collection_bookmarks = bookmarks_state.collections[collection_name].bookmarks
        for i, id in ipairs(collection_bookmarks) do
            if id == bookmark_id then
                table.remove(collection_bookmarks, i)
                break
            end
        end

        -- Remove empty collections (except default)
        if #collection_bookmarks == 0 and collection_name ~= "default" then
            bookmarks_state.collections[collection_name] = nil
        end
    end

    -- Remove from state
    bookmarks_state.bookmarks[bookmark_id] = nil

    if bookmarks_state.auto_save then M.save_bookmarks() end

    utils.log_action("bookmark_removed", bookmark.name)
    return true
end

function M.list_bookmarks(collection)
    local bookmarks = {}

    if collection then
        -- List bookmarks from specific collection
        if bookmarks_state.collections[collection] then
            for _, bookmark_id in ipairs(bookmarks_state.collections[collection].bookmarks) do
                local bookmark = bookmarks_state.bookmarks[bookmark_id]
                if bookmark then table.insert(bookmarks, bookmark) end
            end
        end
    else
        -- List all bookmarks
        for _, bookmark in pairs(bookmarks_state.bookmarks) do
            table.insert(bookmarks, bookmark)
        end
    end

    -- Sort by creation time (newest first)
    table.sort(bookmarks, function(a, b) return a.metadata.created_at > b.metadata.created_at end)

    return bookmarks
end

function M.list_collections()
    local collections = {}
    for name, collection in pairs(bookmarks_state.collections) do
        table.insert(collections, {
            name = name,
            description = collection.description,
            bookmark_count = #collection.bookmarks,
            created_at = collection.created_at,
        })
    end

    table.sort(collections, function(a, b)
        if a.name == "default" then return true end
        if b.name == "default" then return false end
        return a.name < b.name
    end)

    return collections
end

function M.save_bookmarks()
    local bookmarks_file = M.get_bookmarks_file()

    local data = {
        version = BOOKMARKS_VERSION,
        timestamp = os.time(),
        bookmarks = bookmarks_state.bookmarks,
        collections = bookmarks_state.collections,
        metadata = {
            total_bookmarks = vim.tbl_count(bookmarks_state.bookmarks),
            total_collections = vim.tbl_count(bookmarks_state.collections),
            project_root = utils.get_project_root(),
        },
    }

    local json_data = vim.json.encode(data)

    local file = io.open(bookmarks_file, "w")
    if not file then
        utils.error("Failed to save bookmarks to: " .. bookmarks_file)
        return false
    end

    file:write(json_data)
    file:close()

    return true
end

function M.load_bookmarks()
    local bookmarks_file = M.get_bookmarks_file()

    if vim.fn.filereadable(bookmarks_file) == 0 then
        -- Initialize with default collection
        bookmarks_state.collections.default = {
            name = "default",
            created_at = os.time(),
            bookmarks = {},
            description = "Default bookmark collection",
        }
        return bookmarks_state.bookmarks
    end

    local file = io.open(bookmarks_file, "r")
    if not file then
        utils.error("Failed to load bookmarks from: " .. bookmarks_file)
        return {}
    end

    local json_data = file:read("*a")
    file:close()

    local success, data = pcall(vim.json.decode, json_data)
    if not success then
        utils.error("Failed to parse bookmarks JSON")
        return {}
    end

    if data.bookmarks then bookmarks_state.bookmarks = data.bookmarks end

    if data.collections then bookmarks_state.collections = data.collections end

    -- Ensure default collection exists
    if not bookmarks_state.collections.default then
        bookmarks_state.collections.default = {
            name = "default",
            created_at = os.time(),
            bookmarks = {},
            description = "Default bookmark collection",
        }
    end

    return bookmarks_state.bookmarks
end

function M.find_bookmark_by_location(location)
    if not location then return nil end

    for bookmark_id, bookmark in pairs(bookmarks_state.bookmarks) do
        if bookmark.location.path == (location.path or location.file) and bookmark.location.line == location.line then
            return bookmark_id
        end
    end

    return nil
end

function M.find_duplicate_bookmark(new_bookmark) return M.find_bookmark_by_location(new_bookmark.location) end

function M.generate_bookmark_id() return string.format("bm_%d_%d", os.time(), math.random(1000, 9999)) end

function M.generate_bookmark_name(location)
    local file_name = vim.fn.fnamemodify(location.path or location.file, ":t")
    local symbol = location.symbol or location.text or ""

    if symbol and symbol ~= "" then
        return string.format("%s in %s:%d", symbol, file_name, location.line)
    else
        return string.format("%s:%d", file_name, location.line)
    end
end

function M.create_collection(name, description)
    if not name or name == "" then
        utils.warn("Collection name cannot be empty")
        return false
    end

    if bookmarks_state.collections[name] then
        utils.warn("Collection already exists: " .. name)
        return false
    end

    bookmarks_state.collections[name] = {
        name = name,
        created_at = os.time(),
        bookmarks = {},
        description = description or "",
    }

    if bookmarks_state.auto_save then M.save_bookmarks() end

    utils.log_action("collection_created", name)
    return true
end

function M.delete_collection(name)
    if name == "default" then
        utils.warn("Cannot delete default collection")
        return false
    end

    if not bookmarks_state.collections[name] then
        utils.warn("Collection not found: " .. name)
        return false
    end

    -- Move bookmarks to default collection
    local collection = bookmarks_state.collections[name]
    for _, bookmark_id in ipairs(collection.bookmarks) do
        local bookmark = bookmarks_state.bookmarks[bookmark_id]
        if bookmark then
            bookmark.collection = "default"
            table.insert(bookmarks_state.collections.default.bookmarks, bookmark_id)
        end
    end

    bookmarks_state.collections[name] = nil

    if bookmarks_state.auto_save then M.save_bookmarks() end

    utils.log_action("collection_deleted", name)
    return true
end

function M.move_bookmark_to_collection(bookmark_id, target_collection)
    local bookmark = bookmarks_state.bookmarks[bookmark_id]
    if not bookmark then
        utils.warn("Bookmark not found")
        return false
    end

    if not bookmarks_state.collections[target_collection] then
        utils.warn("Target collection not found: " .. target_collection)
        return false
    end

    local current_collection = bookmark.collection

    -- Remove from current collection
    if bookmarks_state.collections[current_collection] then
        local collection_bookmarks = bookmarks_state.collections[current_collection].bookmarks
        for i, id in ipairs(collection_bookmarks) do
            if id == bookmark_id then
                table.remove(collection_bookmarks, i)
                break
            end
        end
    end

    -- Add to target collection
    bookmark.collection = target_collection
    table.insert(bookmarks_state.collections[target_collection].bookmarks, bookmark_id)

    if bookmarks_state.auto_save then M.save_bookmarks() end

    utils.log_action("bookmark_moved", string.format("%s -> %s", bookmark.name, target_collection))
    return true
end

function M.add_bookmark_tag(bookmark_id, tag)
    local bookmark = bookmarks_state.bookmarks[bookmark_id]
    if not bookmark then
        utils.warn("Bookmark not found")
        return false
    end

    if not vim.tbl_contains(bookmark.tags, tag) then
        table.insert(bookmark.tags, tag)

        if bookmarks_state.auto_save then M.save_bookmarks() end

        utils.log_action("tag_added", tag)
    end

    return true
end

function M.search_bookmarks(query, collection)
    local results = {}
    local bookmarks = M.list_bookmarks(collection)

    query = query:lower()

    for _, bookmark in ipairs(bookmarks) do
        local searchable_text = table.concat({
            bookmark.name:lower(),
            bookmark.symbol_info.symbol:lower(),
            bookmark.location.text:lower(),
            bookmark.location.relative_path:lower(),
            bookmark.notes:lower(),
            table.concat(bookmark.tags, " "):lower(),
        }, " ")

        if searchable_text:find(query, 1, true) then table.insert(results, bookmark) end
    end

    return results
end

function M.get_bookmark_stats()
    local total_bookmarks = vim.tbl_count(bookmarks_state.bookmarks)
    local total_collections = vim.tbl_count(bookmarks_state.collections)

    local coupling_distribution = { high = 0, medium = 0, low = 0 }
    for _, bookmark in pairs(bookmarks_state.bookmarks) do
        local coupling = bookmark.coupling_score or 0.0
        if coupling >= 0.7 then
            coupling_distribution.high = coupling_distribution.high + 1
        elseif coupling >= 0.4 then
            coupling_distribution.medium = coupling_distribution.medium + 1
        else
            coupling_distribution.low = coupling_distribution.low + 1
        end
    end

    return {
        total_bookmarks = total_bookmarks,
        total_collections = total_collections,
        coupling_distribution = coupling_distribution,
        auto_save = bookmarks_state.auto_save,
    }
end

function M.set_auto_save(enabled) bookmarks_state.auto_save = enabled end

function M.clear_all_bookmarks()
    bookmarks_state.bookmarks = {}
    bookmarks_state.collections = {
        default = {
            name = "default",
            created_at = os.time(),
            bookmarks = {},
            description = "Default bookmark collection",
        },
    }

    if bookmarks_state.auto_save then M.save_bookmarks() end

    utils.log_action("bookmarks_cleared", "all")
end

-- Initialize bookmarks on module load
M.load_bookmarks()

return M
