local utils = require("spaghetti-comb.utils")
local navigation = require("spaghetti-comb.navigation")
local error_handler = require("spaghetti-comb.error_handling")

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
        utils.log_lsp_error("No active LSP clients found for current buffer")
        return nil
    end

    return clients
end

local function make_lsp_request(method, params, callback)
    local symbol_info = utils.get_cursor_symbol()
    local context = {
        bufnr = vim.api.nvim_get_current_buf(),
        symbol_text = symbol_info and symbol_info.text,
        method = method,
    }

    error_handler.safe_lsp_call(method, params, callback, context)
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
            local location = utils.create_location_item(
                response.uri,
                response.range,
                utils.get_line_text(vim.uri_to_bufnr(response.uri), response.range.start.line)
            )
            location.coupling_score = M.calculate_location_coupling(location)
            table.insert(processed.locations, location)
        elseif vim.islist(response) then
            for _, item in ipairs(response) do
                if item.uri and item.range then
                    local location = utils.create_location_item(
                        item.uri,
                        item.range,
                        utils.get_line_text(vim.uri_to_bufnr(item.uri), item.range.start.line)
                    )
                    location.coupling_score = M.calculate_location_coupling(location)
                    table.insert(processed.locations, location)
                end
            end
        end
    end

    return processed
end

function M.calculate_location_coupling(location)
    if not location or not location.path then return 0.0 end

    local coupling_metrics = require("spaghetti-comb.coupling.metrics")

    -- Create a simplified symbol info for the location
    local symbol_info = {
        text = location.text or "",
        file = location.path,
        line = location.line,
        type = "reference",
    }

    -- For individual locations, we have limited data, so use a simpler calculation
    local base_score = 0.3 -- Base coupling for any reference

    -- Add coupling based on file distance from current file
    local current_file = vim.api.nvim_buf_get_name(0)
    if location.path ~= current_file then base_score = base_score + 0.2 end

    -- Add coupling based on module boundaries
    local module_coupling = coupling_metrics.analyze_module_boundaries(symbol_info, { { path = current_file } })
    base_score = base_score + (module_coupling * 0.3)

    return math.min(1.0, base_score)
end

function M.find_references()
    local symbol_info = error_handler.safe_call(
        function() return utils.get_cursor_symbol() end,
        { function_name = "find_references" }
    )

    if not symbol_info or not symbol_info.text then
        utils.debug("No symbol found under cursor")
        return
    end

    local params = error_handler.safe_call(function()
        local p = get_text_document_params()
        p.context = { includeDeclaration = true }
        return p
    end, { symbol_info = symbol_info })

    if not params then
        utils.error("Failed to create text document parameters")
        return
    end

    make_lsp_request("textDocument/references", params, function(result, err)
        if err then
            local fallback_result = M.find_references_fallback(symbol_info.text)
            if #fallback_result > 0 then
                local processed = {
                    method = "textDocument/references",
                    locations = fallback_result,
                    fallback_used = true,
                }

                navigation.push(symbol_info)
                navigation.update_current_entry({ references = processed.locations })
                require("spaghetti-comb.ui.relations").show_relations(processed)
                utils.debug(string.format("Found %d references (fallback) for %s", #fallback_result, symbol_info.text))
            else
                utils.error("Failed to find references with both LSP and fallback methods")
            end
            return
        end

        local processed = error_handler.safe_call(
            function() return M.process_lsp_response("textDocument/references", result) end,
            { result = result, symbol_info = symbol_info }
        )

        if not processed or #processed.locations == 0 then
            utils.debug("No references found for symbol: " .. symbol_info.text)
            return
        end

        error_handler.safe_call(function()
            navigation.push(symbol_info)
            navigation.update_current_entry({ references = processed.locations })
            require("spaghetti-comb.ui.relations").show_relations(processed)
        end, { processed = processed, symbol_info = symbol_info })

        utils.debug(string.format("Found %d references for %s", #processed.locations, symbol_info.text))
    end)
end

function M.go_to_definition()
    local symbol_info = utils.get_cursor_symbol()
    if not symbol_info then
        utils.debug("No symbol found under cursor")
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
            utils.debug("No definition found for symbol: " .. symbol_info.text)
            return
        end

        local location = processed.locations[1]
        if location then
            navigation.push(symbol_info)
            navigation.update_current_entry({ definitions = processed.locations })

            vim.cmd("edit " .. vim.fn.fnameescape(location.path))
            vim.api.nvim_win_set_cursor(0, { location.line, location.col - 1 })
            vim.cmd("normal! zz")

            utils.log_navigation(
                string.format("Definition of %s at %s:%d", symbol_info.text, location.relative_path, location.line)
            )

            require("spaghetti-comb.ui.relations").show_relations(processed)
        end
    end)
end

function M.find_implementations()
    local symbol_info = utils.get_cursor_symbol()
    if not symbol_info then
        utils.debug("No symbol found under cursor")
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
            utils.debug("No implementations found for symbol: " .. symbol_info.text)
            return
        end

        navigation.update_current_entry({ implementations = processed.locations })

        require("spaghetti-comb.ui.relations").show_relations(processed)

        utils.debug(string.format("Found %d implementations for %s", #processed.locations, symbol_info.text))
    end)
end

function M.get_call_hierarchy_incoming()
    local symbol_info = utils.get_cursor_symbol()
    if not symbol_info then
        utils.debug("No symbol found under cursor")
        return
    end

    local params = get_text_document_params()

    make_lsp_request("textDocument/prepareCallHierarchy", params, function(result, err)
        if err or not result or #result == 0 then
            utils.log_lsp_error("Call hierarchy not available for this symbol")
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

            navigation.push(symbol_info)
            navigation.update_current_entry({ incoming_calls = calls })

            local processed = {
                method = "callHierarchy/incomingCalls",
                locations = calls,
                symbol_info = symbol_info,
                context = { type = "incoming_calls" },
            }

            require("spaghetti-comb.ui.relations").show_relations(processed)
            utils.debug(string.format("Found %d incoming calls for %s", #calls, symbol_info.text))
        end)
    end)
end

function M.get_call_hierarchy_outgoing()
    local symbol_info = utils.get_cursor_symbol()
    if not symbol_info then
        utils.debug("No symbol found under cursor")
        return
    end

    local params = get_text_document_params()

    make_lsp_request("textDocument/prepareCallHierarchy", params, function(result, err)
        if err or not result or #result == 0 then
            utils.log_lsp_error("Call hierarchy not available for this symbol")
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

            navigation.push(symbol_info)
            navigation.update_current_entry({ outgoing_calls = calls })

            local processed = {
                method = "callHierarchy/outgoingCalls",
                locations = calls,
                symbol_info = symbol_info,
                context = { type = "outgoing_calls" },
            }

            require("spaghetti-comb.ui.relations").show_relations(processed)
            utils.debug(string.format("Found %d outgoing calls for %s", #calls, symbol_info.text))
        end)
    end)
end

function M.find_references_fallback(symbol_text)
    if not symbol_text or symbol_text == "" then return {} end

    utils.debug("Using enhanced fallback for finding references")

    local results = {}

    -- Try ripgrep first (faster and more accurate)
    local rg_results = M.find_references_with_ripgrep(symbol_text)
    if #rg_results > 0 then return rg_results end

    -- Fall back to regular grep
    local cwd = vim.fn.getcwd()
    local language_extensions = M.get_language_file_extensions()
    local extension_pattern = table.concat(language_extensions, " -o -name ")

    local cmd = string.format(
        "find %s -type f \\( -name %s \\) -not -path '*/node_modules/*' -not -path '*/.git/*' -exec grep -Hn '%s' {} \\;",
        vim.fn.shellescape(cwd),
        extension_pattern,
        vim.fn.shellescape(symbol_text)
    )

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then
        -- Last resort: use basic grep
        return M.find_references_basic_grep(symbol_text)
    end

    for line in output:gmatch("[^\r\n]+") do
        local file, line_num, text = line:match("([^:]+):(%d+):(.*)")
        if file and line_num and text then
            local abs_path = vim.fn.fnamemodify(file, ":p")
            if vim.fn.filereadable(abs_path) == 1 then
                table.insert(
                    results,
                    utils.create_location_item(utils.path_to_uri(abs_path), {
                        start = { line = tonumber(line_num) - 1, character = 0 },
                        ["end"] = { line = tonumber(line_num) - 1, character = #text },
                    }, text:gsub("^%s*", ""))
                )
            end
        end
    end

    return results
end

function M.find_references_with_ripgrep(symbol_text)
    if vim.fn.executable("rg") == 0 then return {} end

    local cwd = vim.fn.getcwd()
    local language_extensions = M.get_language_file_extensions()
    local extension_args = {}

    for _, ext in ipairs(language_extensions) do
        table.insert(extension_args, "--glob")
        table.insert(extension_args, "*" .. ext)
    end

    local cmd = {
        "rg",
        "--line-number",
        "--column",
        "--no-heading",
        "--color=never",
        "--smart-case",
    }

    for _, arg in ipairs(extension_args) do
        table.insert(cmd, arg)
    end

    table.insert(cmd, vim.fn.shellescape(symbol_text))
    table.insert(cmd, cwd)

    local output = vim.fn.system(table.concat(cmd, " "))
    if vim.v.shell_error ~= 0 then return {} end

    local results = {}
    for line in output:gmatch("[^\r\n]+") do
        local file, line_num, col_num, text = line:match("([^:]+):(%d+):(%d+):(.*)")
        if file and line_num and col_num and text then
            local abs_path = vim.fn.fnamemodify(file, ":p")
            if vim.fn.filereadable(abs_path) == 1 then
                table.insert(
                    results,
                    utils.create_location_item(utils.path_to_uri(abs_path), {
                        start = { line = tonumber(line_num) - 1, character = tonumber(col_num) - 1 },
                        ["end"] = { line = tonumber(line_num) - 1, character = tonumber(col_num) - 1 + #symbol_text },
                    }, text:gsub("^%s*", ""))
                )
            end
        end
    end

    return results
end

function M.find_references_basic_grep(symbol_text)
    local cwd = vim.fn.getcwd()
    local cmd = string.format(
        "grep -rn --exclude-dir=node_modules --exclude-dir=.git '%s' %s",
        vim.fn.shellescape(symbol_text),
        vim.fn.shellescape(cwd)
    )

    local output = vim.fn.system(cmd)
    if vim.v.shell_error ~= 0 then return {} end

    local results = {}
    for line in output:gmatch("[^\r\n]+") do
        local file, line_num, text = line:match("([^:]+):(%d+):(.*)")
        if file and line_num and text then
            local abs_path = vim.fn.fnamemodify(file, ":p")
            if vim.fn.filereadable(abs_path) == 1 then
                table.insert(
                    results,
                    utils.create_location_item(utils.path_to_uri(abs_path), {
                        start = { line = tonumber(line_num) - 1, character = 0 },
                        ["end"] = { line = tonumber(line_num) - 1, character = #text },
                    }, text:gsub("^%s*", ""))
                )
            end
        end
    end

    return results
end

function M.get_language_file_extensions()
    local current_language = utils.get_buffer_language()

    local extension_map = {
        typescript = { "*.ts", "*.tsx", "*.d.ts" },
        javascript = { "*.js", "*.jsx", "*.mjs", "*.cjs" },
        python = { "*.py", "*.pyx", "*.pyi" },
        rust = { "*.rs" },
        go = { "*.go" },
        lua = { "*.lua" },
        c = { "*.c", "*.h" },
        cpp = { "*.cpp", "*.cxx", "*.cc", "*.hpp", "*.hxx" },
        java = { "*.java" },
        kotlin = { "*.kt", "*.kts" },
        swift = { "*.swift" },
        ruby = { "*.rb" },
        php = { "*.php" },
        bash = { "*.sh", "*.bash" },
        zsh = { "*.zsh" },
    }

    local extensions = extension_map[current_language] or { "*.*" }

    -- Always include common config and documentation files
    table.insert(extensions, "*.json")
    table.insert(extensions, "*.yaml")
    table.insert(extensions, "*.yml")
    table.insert(extensions, "*.toml")
    table.insert(extensions, "*.md")

    return extensions
end

function M.find_definitions_treesitter(symbol_text, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    local parser = vim.treesitter.get_parser(bufnr)
    if not parser then return {} end

    local tree = parser:parse()[1]
    if not tree then return {} end

    local root = tree:root()
    local language = utils.get_buffer_language()

    -- Enhanced query patterns for multiple definition types
    local query_patterns = {
        typescript = {
            string.format([[(function_declaration name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(method_definition name: (property_identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(class_declaration name: (type_identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(interface_declaration name: (type_identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(type_alias_declaration name: (type_identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(variable_declarator name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
        },
        javascript = {
            string.format([[(function_declaration name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(method_definition name: (property_identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(class_declaration name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(variable_declarator name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
        },
        python = {
            string.format([[(function_definition name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(class_definition name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(assignment left: (identifier) @name (#eq? @name "%s"))]], symbol_text),
        },
        rust = {
            string.format([[(function_item name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(struct_item name: (type_identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(enum_item name: (type_identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(impl_item trait: (type_identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(trait_item name: (type_identifier) @name (#eq? @name "%s"))]], symbol_text),
        },
        go = {
            string.format([[(function_declaration name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(method_declaration name: (field_identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(type_declaration name: (type_identifier) @name (#eq? @name "%s"))]], symbol_text),
        },
        lua = {
            string.format([[(function_statement name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format([[(local_function name: (identifier) @name (#eq? @name "%s"))]], symbol_text),
            string.format(
                [[(assignment_statement (variable_list name: (identifier) @name (#eq? @name "%s")))]],
                symbol_text
            ),
        },
    }

    local patterns = query_patterns[language] or {}
    if #patterns == 0 then return {} end

    local results = {}
    local seen_locations = {}

    for _, pattern in ipairs(patterns) do
        local ok, query = pcall(vim.treesitter.query.parse, language, pattern)
        if ok and query then
            for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
                local start_row, start_col, end_row, end_col = node:range()
                local node_text = vim.treesitter.get_node_text(node, bufnr)

                -- Avoid duplicate results
                local location_key = string.format("%d:%d", start_row, start_col)
                if not seen_locations[location_key] then
                    seen_locations[location_key] = true

                    table.insert(
                        results,
                        utils.create_location_item(utils.path_to_uri(vim.api.nvim_buf_get_name(bufnr)), {
                            start = { line = start_row, character = start_col },
                            ["end"] = { line = end_row, character = end_col },
                        }, node_text)
                    )
                end
            end
        end
    end

    return results
end

function M.find_definitions_across_project(symbol_text)
    local results = {}
    local cwd = vim.fn.getcwd()
    local language_extensions = M.get_language_file_extensions()

    -- Build file pattern for find command
    local find_patterns = {}
    for _, ext in ipairs(language_extensions) do
        table.insert(find_patterns, "-name")
        table.insert(find_patterns, ext)
        table.insert(find_patterns, "-o")
    end
    -- Remove the last "-o"
    if #find_patterns > 0 then table.remove(find_patterns) end

    local cmd = {
        "find",
        cwd,
        "-type",
        "f",
        "(",
    }
    for _, pattern in ipairs(find_patterns) do
        table.insert(cmd, pattern)
    end
    table.insert(cmd, ")")
    table.insert(cmd, "-not")
    table.insert(cmd, "-path")
    table.insert(cmd, "*/node_modules/*")
    table.insert(cmd, "-not")
    table.insert(cmd, "-path")
    table.insert(cmd, "*/.git/*")

    local find_output = vim.fn.system(table.concat(cmd, " "))
    if vim.v.shell_error ~= 0 then return {} end

    local files = vim.split(find_output, "\n", { plain = true })
    local max_files = 50 -- Limit to avoid performance issues

    for i, file in ipairs(files) do
        if i > max_files then break end
        if file and file ~= "" and vim.fn.filereadable(file) == 1 then
            local bufnr = vim.fn.bufnr(file, true)
            if bufnr ~= -1 then
                local file_results = M.find_definitions_treesitter(symbol_text, bufnr)
                for _, result in ipairs(file_results) do
                    table.insert(results, result)
                end
            end
        end
    end

    return results
end

function M.find_references_with_fallback(symbol_info, callback)
    local params = get_text_document_params()
    params.context = { includeDeclaration = true }

    make_lsp_request("textDocument/references", params, function(result, err)
        local processed

        if err or not result then
            utils.log_lsp_error("LSP references failed, using fallback methods")
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
            utils.debug("No references found for symbol: " .. symbol_info.text)
            callback(processed)
            return
        end

        navigation.update_current_entry({ references = processed.locations })
        callback(processed)

        utils.debug(string.format("Found %d references for %s", #processed.locations, symbol_info.text))
    end)
end

function M.find_definitions_with_fallback(symbol_info, callback)
    local params = get_text_document_params()

    make_lsp_request("textDocument/definition", params, function(result, err)
        local processed

        if err or not result then
            utils.log_lsp_error("LSP definition failed, using treesitter fallback")
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
            utils.debug("No definition found for symbol: " .. symbol_info.text)
            callback(processed)
            return
        end

        navigation.update_current_entry({ definitions = processed.locations })
        callback(processed)

        utils.debug(string.format("Found %d definitions for %s", #processed.locations, symbol_info.text))
    end)
end

function M.analyze_current_symbol()
    local symbol_info = utils.get_cursor_symbol()
    if not symbol_info then
        utils.debug("No symbol found under cursor")
        return
    end

    navigation.push(symbol_info)

    local all_data = { locations = {} }
    local completed_requests = 0
    local total_requests = 2

    local function check_completion()
        completed_requests = completed_requests + 1
        if completed_requests >= total_requests then require("spaghetti-comb.ui.relations").show_relations(all_data) end
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
