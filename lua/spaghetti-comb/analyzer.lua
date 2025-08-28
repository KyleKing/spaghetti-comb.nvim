local utils = require("spaghetti-comb.utils")
local navigation = require("spaghetti-comb.navigation")

local M = {}

local function get_lsp_clients()
    local bufnr = vim.api.nvim_get_current_buf()
    local clients

    if vim.lsp.get_clients then
        clients = vim.lsp.get_clients({ bufnr = bufnr })
    else
        clients = vim.lsp.get_active_clients({ bufnr = bufnr })
    end

    if #clients == 0 then
        utils.warn("No active LSP clients found for current buffer")
        return nil
    end

    return clients
end

local function make_lsp_request(method, params, callback)
    local clients = get_lsp_clients()
    if not clients then
        callback(nil, "No LSP clients available")
        return
    end

    local client = clients[1]

    client.request(method, params, function(err, result)
        if err then
            utils.error(string.format("LSP request failed: %s", err.message or tostring(err)))
            callback(nil, err)
            return
        end

        callback(result, nil)
    end)
end

local function get_text_document_params()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)

    return {
        textDocument = vim.lsp.util.make_text_document_params(bufnr),
        position = {
            line = cursor[1] - 1,
            character = cursor[2],
        },
    }
end

function M.process_lsp_response(method, response)
    local processed = {
        method = method,
        locations = {},
        symbol_info = {},
        context = {},
    }

    if not response then return processed end

    if type(response) == "table" then
        if response.uri and response.range then
            table.insert(
                processed.locations,
                utils.create_location_item(
                    response.uri,
                    response.range,
                    utils.get_line_text(vim.uri_to_bufnr(response.uri), response.range.start.line)
                )
            )
        elseif vim.islist(response) then
            for _, item in ipairs(response) do
                if item.uri and item.range then
                    table.insert(
                        processed.locations,
                        utils.create_location_item(
                            item.uri,
                            item.range,
                            utils.get_line_text(vim.uri_to_bufnr(item.uri), item.range.start.line)
                        )
                    )
                end
            end
        end
    end

    return processed
end

function M.find_references()
    local symbol_info = utils.get_cursor_symbol()
    if not symbol_info then
        utils.warn("No symbol found under cursor")
        return
    end

    local params = get_text_document_params()
    params.context = { includeDeclaration = true }

    make_lsp_request("textDocument/references", params, function(result, err)
        if err then
            utils.error("Failed to find references: " .. tostring(err))
            return
        end

        local processed = M.process_lsp_response("textDocument/references", result)

        if #processed.locations == 0 then
            utils.info("No references found for symbol: " .. symbol_info.text)
            return
        end

        navigation.push(symbol_info)
        navigation.update_current_entry({ references = processed.locations })

        require("spaghetti-comb.ui.floating").show_relations(processed)

        utils.info(string.format("Found %d references for %s", #processed.locations, symbol_info.text))
    end)
end

function M.go_to_definition()
    local symbol_info = utils.get_cursor_symbol()
    if not symbol_info then
        utils.warn("No symbol found under cursor")
        return
    end

    local params = get_text_document_params()

    make_lsp_request("textDocument/definition", params, function(result, err)
        if err then
            utils.error("Failed to find definition: " .. tostring(err))
            return
        end

        local processed = M.process_lsp_response("textDocument/definition", result)

        if #processed.locations == 0 then
            utils.info("No definition found for symbol: " .. symbol_info.text)
            return
        end

        local location = processed.locations[1]
        if location then
            navigation.push(symbol_info)
            navigation.update_current_entry({ definitions = processed.locations })

            vim.cmd("edit " .. vim.fn.fnameescape(location.path))
            vim.api.nvim_win_set_cursor(0, { location.line, location.col - 1 })
            vim.cmd("normal! zz")

            utils.info(
                string.format(
                    "Navigated to definition of %s at %s:%d",
                    symbol_info.text,
                    location.relative_path,
                    location.line
                )
            )

            require("spaghetti-comb.ui.floating").show_relations(processed)
        end
    end)
end

function M.find_implementations()
    local symbol_info = utils.get_cursor_symbol()
    if not symbol_info then
        utils.warn("No symbol found under cursor")
        return
    end

    local params = get_text_document_params()

    make_lsp_request("textDocument/implementation", params, function(result, err)
        if err then
            utils.error("Failed to find implementations: " .. tostring(err))
            return
        end

        local processed = M.process_lsp_response("textDocument/implementation", result)

        if #processed.locations == 0 then
            utils.info("No implementations found for symbol: " .. symbol_info.text)
            return
        end

        navigation.update_current_entry({ implementations = processed.locations })

        require("spaghetti-comb.ui.floating").show_relations(processed)

        utils.info(string.format("Found %d implementations for %s", #processed.locations, symbol_info.text))
    end)
end

function M.get_call_hierarchy_incoming()
    local symbol_info = utils.get_cursor_symbol()
    if not symbol_info then
        utils.warn("No symbol found under cursor")
        return
    end

    local params = get_text_document_params()

    make_lsp_request("textDocument/prepareCallHierarchy", params, function(result, err)
        if err or not result or #result == 0 then
            utils.warn("Call hierarchy not available for this symbol")
            return
        end

        local hierarchy_item = result[1]
        local incoming_params = { item = hierarchy_item }

        make_lsp_request("callHierarchy/incomingCalls", incoming_params, function(incoming_result, incoming_err)
            if incoming_err then
                utils.error("Failed to get incoming calls: " .. tostring(incoming_err))
                return
            end

            local calls = {}
            if incoming_result then
                for _, call in ipairs(incoming_result) do
                    if call.from and call.from.uri and call.from.range then
                        table.insert(
                            calls,
                            utils.create_location_item(call.from.uri, call.from.range, call.from.name or "")
                        )
                    end
                end
            end

            navigation.update_current_entry({ incoming_calls = calls })

            utils.info(string.format("Found %d incoming calls for %s", #calls, symbol_info.text))
        end)
    end)
end

function M.get_call_hierarchy_outgoing()
    local symbol_info = utils.get_cursor_symbol()
    if not symbol_info then
        utils.warn("No symbol found under cursor")
        return
    end

    local params = get_text_document_params()

    make_lsp_request("textDocument/prepareCallHierarchy", params, function(result, err)
        if err or not result or #result == 0 then
            utils.warn("Call hierarchy not available for this symbol")
            return
        end

        local hierarchy_item = result[1]
        local outgoing_params = { item = hierarchy_item }

        make_lsp_request("callHierarchy/outgoingCalls", outgoing_params, function(outgoing_result, outgoing_err)
            if outgoing_err then
                utils.error("Failed to get outgoing calls: " .. tostring(outgoing_err))
                return
            end

            local calls = {}
            if outgoing_result then
                for _, call in ipairs(outgoing_result) do
                    if call.to and call.to.uri and call.to.range then
                        table.insert(calls, utils.create_location_item(call.to.uri, call.to.range, call.to.name or ""))
                    end
                end
            end

            navigation.update_current_entry({ outgoing_calls = calls })

            utils.info(string.format("Found %d outgoing calls for %s", #calls, symbol_info.text))
        end)
    end)
end

function M.find_references_fallback(symbol_text)
    if not symbol_text or symbol_text == "" then return {} end

    utils.info("Using grep fallback for finding references")

    local cwd = vim.fn.getcwd()
    local cmd = string.format("grep -rn --exclude-dir=node_modules --exclude-dir=.git '%s' %s", symbol_text, cwd)

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then return {} end

    local results = {}
    for line in output:gmatch("[^\r\n]+") do
        local file, line_num, text = line:match("([^:]+):(%d+):(.*)")
        if file and line_num and text then
            local abs_path = vim.fn.fnamemodify(file, ":p")
            table.insert(
                results,
                utils.create_location_item(utils.path_to_uri(abs_path), {
                    start = { line = tonumber(line_num) - 1, character = 0 },
                    ["end"] = { line = tonumber(line_num) - 1, character = #text },
                }, text:gsub("^%s*", ""))
            )
        end
    end

    return results
end

function M.find_definitions_treesitter(symbol_text, bufnr)
    local parser = vim.treesitter.get_parser(bufnr)
    if not parser then return {} end

    local tree = parser:parse()[1]
    local root = tree:root()
    local language = utils.get_buffer_language()

    local query_strings = {
        typescript = string.format([[(function_declaration name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
        javascript = string.format([[(function_declaration name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
        python = string.format([[(function_definition name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
        rust = string.format([[(function_item name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
        go = string.format([[(function_declaration name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
    }

    local query_string = query_strings[language]
    if not query_string then return {} end

    local ok, query = pcall(vim.treesitter.query.parse, language, query_string)
    if not ok then return {} end

    local results = {}
    for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
        local start_row, start_col, end_row, end_col = node:range()
        local text = vim.treesitter.get_node_text(node, bufnr)

        table.insert(
            results,
            utils.create_location_item(utils.path_to_uri(vim.api.nvim_buf_get_name(bufnr)), {
                start = { line = start_row, character = start_col },
                ["end"] = { line = end_row, character = end_col },
            }, text)
        )
    end

    return results
end

function M.find_references_with_fallback(symbol_info, callback)
    local params = get_text_document_params()
    params.context = { includeDeclaration = true }

    make_lsp_request("textDocument/references", params, function(result, err)
        local processed

        if err or not result then
            utils.warn("LSP references failed, using fallback methods")
            local fallback_results = M.find_references_fallback(symbol_info.text)
            processed = {
                method = "textDocument/references",
                locations = fallback_results,
                symbol_info = {},
                context = { fallback = true },
            }
        else
            processed = M.process_lsp_response("textDocument/references", result)
        end

        if #processed.locations == 0 then
            utils.info("No references found for symbol: " .. symbol_info.text)
            callback(processed)
            return
        end

        navigation.update_current_entry({ references = processed.locations })
        callback(processed)

        utils.info(string.format("Found %d references for %s", #processed.locations, symbol_info.text))
    end)
end

function M.find_definitions_with_fallback(symbol_info, callback)
    local params = get_text_document_params()

    make_lsp_request("textDocument/definition", params, function(result, err)
        local processed

        if err or not result then
            utils.warn("LSP definition failed, using treesitter fallback")
            local fallback_results = M.find_definitions_treesitter(symbol_info.text, symbol_info.bufnr)
            processed = {
                method = "textDocument/definition",
                locations = fallback_results,
                symbol_info = {},
                context = { fallback = true },
            }
        else
            processed = M.process_lsp_response("textDocument/definition", result)
        end

        if #processed.locations == 0 then
            utils.info("No definition found for symbol: " .. symbol_info.text)
            callback(processed)
            return
        end

        navigation.update_current_entry({ definitions = processed.locations })
        callback(processed)

        utils.info(string.format("Found %d definitions for %s", #processed.locations, symbol_info.text))
    end)
end

function M.analyze_current_symbol()
    local symbol_info = utils.get_cursor_symbol()
    if not symbol_info then
        utils.warn("No symbol found under cursor")
        return
    end

    navigation.push(symbol_info)

    local all_data = { locations = {} }
    local completed_requests = 0
    local total_requests = 2

    local function check_completion()
        completed_requests = completed_requests + 1
        if completed_requests >= total_requests then require("spaghetti-comb.ui.floating").show_relations(all_data) end
    end

    M.find_references_with_fallback(symbol_info, function(processed)
        for _, loc in ipairs(processed.locations) do
            table.insert(all_data.locations, loc)
        end
        check_completion()
    end)

    M.find_definitions_with_fallback(symbol_info, function(processed)
        for _, loc in ipairs(processed.locations) do
            table.insert(all_data.locations, loc)
        end
        check_completion()
    end)

    M.get_call_hierarchy_incoming()
    M.get_call_hierarchy_outgoing()
end

return M
