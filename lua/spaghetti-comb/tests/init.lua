-- Test runner for spaghetti-comb
local M = {}

local SPEC_DIR = "lua/spaghetti-comb/tests"

local function run_files(files)
    local MiniTest = require("mini.test")
    MiniTest.run({
        collect = {
            find_files = function() return files end,
        },
    })
end

local function spec_path(name) return string.format("%s/%s_spec.lua", SPEC_DIR, name) end

-- Run all tests
function M.run_all()
    local files = vim.fn.glob(SPEC_DIR .. "/*_spec.lua", false, true)
    table.sort(files)
    run_files(files)
end

-- Run specific test category
function M.run_history() run_files({ spec_path("history") }) end

function M.run_ui() run_files({ spec_path("ui") }) end

function M.run_navigation() run_files({ spec_path("navigation") }) end

function M.run_integration() run_files({ spec_path("integration") }) end

function M.run_lsp() run_files({ spec_path("lsp") }) end

function M.run_bookmarks() run_files({ spec_path("bookmarks") }) end

return M
