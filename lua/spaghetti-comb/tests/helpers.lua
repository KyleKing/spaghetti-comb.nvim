-- Shared spec helpers: substring assertion, module-field snapshot/restore,
-- and stubs that record what a show function was handed.
local MiniTest = require("mini.test")

local M = {}

---@param str any
---@param needle string
function M.expect_contains(str, needle)
    MiniTest.expect.equality(type(str) == "string" and str:find(needle, 1, true) ~= nil, true)
end

-- Snapshot each {module, field} pair now; the returned function puts them back.
---@param targets table[] entries shaped { module, "field" }
---@return fun()
function M.save(targets)
    local saved = {}
    for _, t in ipairs(targets) do
        saved[#saved + 1] = { t[1], t[2], t[1][t[2]] }
    end
    return function()
        for _, s in ipairs(saved) do
            s[1][s[2]] = s[3]
        end
    end
end

-- Replace module[field] with a stub that records its args under `keys` into
-- `seen.shown` and reports success.
---@param module table
---@param field string
---@param seen table
---@param keys string[]
function M.stub_show(module, field, seen, keys)
    module[field] = function(...)
        local args = { ... }
        local record = {}
        for i, k in ipairs(keys) do
            record[k] = args[i]
        end
        seen.shown = record
        return true, "shown"
    end
end

return M
