local M = {}

function M.save_session()
	require("spaghetti-comb.utils").info("Save session - not yet implemented")
end

function M.load_session()
	require("spaghetti-comb.utils").info("Load session - not yet implemented")
end

function M.save_navigation_stack(stack)
	return false
end

function M.load_navigation_stack()
	return nil
end

return M
