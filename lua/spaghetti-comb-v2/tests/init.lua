-- Test runner for spaghetti-comb-v2
local M = {}

-- Run all tests
function M.run_all()
    local MiniTest = require("mini.test")

    -- Collect all test sets
    local test_sets = {
        require("spaghetti-comb-v2.tests.history_spec"),
        require("spaghetti-comb-v2.tests.ui_spec"),
        require("spaghetti-comb-v2.tests.navigation_spec"),
        require("spaghetti-comb-v2.tests.integration_spec"),
        require("spaghetti-comb-v2.tests.lsp_spec"),
    }

    -- Run tests
    for _, test_set in ipairs(test_sets) do
        MiniTest.run(test_set)
    end
end

-- Run specific test category
function M.run_history()
    local MiniTest = require("mini.test")
    local test_set = require("spaghetti-comb-v2.tests.history_spec")
    MiniTest.run(test_set)
end

function M.run_ui()
    local MiniTest = require("mini.test")
    local test_set = require("spaghetti-comb-v2.tests.ui_spec")
    MiniTest.run(test_set)
end

function M.run_navigation()
    local MiniTest = require("mini.test")
    local test_set = require("spaghetti-comb-v2.tests.navigation_spec")
    MiniTest.run(test_set)
end

function M.run_integration()
    local MiniTest = require("mini.test")
    local test_set = require("spaghetti-comb-v2.tests.integration_spec")
    MiniTest.run(test_set)
end

function M.run_lsp()
    local MiniTest = require("mini.test")
    local test_set = require("spaghetti-comb-v2.tests.lsp_spec")
    MiniTest.run(test_set)
end

return M
