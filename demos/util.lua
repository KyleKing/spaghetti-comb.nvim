-- Shared console formatting for the demo scenarios
local M = {}

local BOX_WIDTH = 48
local INDENT = 3

function M.banner(title)
    local rule = string.rep("═", BOX_WIDTH)
    local gap = math.max(0, BOX_WIDTH - INDENT - vim.fn.strdisplaywidth(title))
    print(string.format("\n╔%s╗", rule))
    print(string.format("║%s%s%s║", string.rep(" ", INDENT), title, string.rep(" ", gap)))
    print(string.format("╚%s╝\n", rule))
end

function M.section(title)
    print("\n" .. title)
    print(string.rep("=", vim.fn.strdisplaywidth(title)) .. "\n")
end

function M.rule() print("\n" .. string.rep("-", 50)) end

return M
