local M = {}

function M.calculate_coupling_score(symbol_info, references)
	return 0.0
end

function M.analyze_structural_coupling(symbol_info)
	return 0.0
end

function M.analyze_data_coupling(symbol_info)
	return 0.0
end

function M.get_coupling_metrics(symbol_info)
	return {
		structural = 0.0,
		data = 0.0,
		control = 0.0,
		content = 0.0,
		total = 0.0,
	}
end

return M
