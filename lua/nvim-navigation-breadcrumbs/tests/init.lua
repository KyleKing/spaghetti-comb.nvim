-- Test runner for nvim-navigation-breadcrumbs
local M = {}

-- Run all tests
function M.run_all()
  local MiniTest = require('mini.test')
  
  -- Collect all test sets
  local test_sets = {
    require('nvim-navigation-breadcrumbs.tests.history_spec'),
    require('nvim-navigation-breadcrumbs.tests.ui_spec'),
    require('nvim-navigation-breadcrumbs.tests.navigation_spec'),
    require('nvim-navigation-breadcrumbs.tests.integration_spec'),
  }
  
  -- Run tests
  for _, test_set in ipairs(test_sets) do
    MiniTest.run(test_set)
  end
end

-- Run specific test category
function M.run_history()
  local MiniTest = require('mini.test')
  local test_set = require('nvim-navigation-breadcrumbs.tests.history_spec')
  MiniTest.run(test_set)
end

function M.run_ui()
  local MiniTest = require('mini.test')
  local test_set = require('nvim-navigation-breadcrumbs.tests.ui_spec')
  MiniTest.run(test_set)
end

function M.run_navigation()
  local MiniTest = require('mini.test')
  local test_set = require('nvim-navigation-breadcrumbs.tests.navigation_spec')
  MiniTest.run(test_set)
end

function M.run_integration()
  local MiniTest = require('mini.test')
  local test_set = require('nvim-navigation-breadcrumbs.tests.integration_spec')
  MiniTest.run(test_set)
end

return M