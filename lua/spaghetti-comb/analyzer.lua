local utils = require("spaghetti-comb.utils")
local navigation = require("spaghetti-comb.navigation")

local M = {}

local function get_lsp_clients()
	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_active_clients({ bufnr = bufnr })

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
	if not response then
		return {}
	end

	local processed = {
		method = method,
		locations = {},
		symbol_info = {},
		context = {},
	}

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
		elseif vim.tbl_islist(response) then
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

function M.analyze_current_symbol()
	local symbol_info = utils.get_cursor_symbol()
	if not symbol_info then
		utils.warn("No symbol found under cursor")
		return
	end

	navigation.push(symbol_info)

	M.find_references()
	M.get_call_hierarchy_incoming()
	M.get_call_hierarchy_outgoing()
end

return M
