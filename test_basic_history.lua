#!/usr/bin/env lua

-- Add current directory to package path
package.path = package.path .. ';./lua/nvim-navigation-breadcrumbs/?.lua;./lua/nvim-navigation-breadcrumbs/?/init.lua'

print('Running basic history manager tests...')

-- Test setup
print('Testing setup...')
local config = {
  history = {
    exploration_timeout_minutes = 5
  }
}

local history_manager = require('nvim-navigation-breadcrumbs.history.manager')
history_manager.setup(config)
history_manager.set_current_project('/test/project')
assert(history_manager.get_current_project() == '/test/project', 'Project setup failed')
print('✓ Setup test passed')

-- Test jump recording
print('Testing jump recording...')
local from_location = {
  file_path = '/test/project/file1.lua',
  position = {line = 10, column = 5}
}
local to_location = {
  file_path = '/test/project/file2.lua', 
  position = {line = 20, column = 10}
}

local success, entry = history_manager.record_jump(from_location, to_location, 'manual')
assert(success == true, 'Jump recording failed')
assert(entry.file_path == '/test/project/file2.lua', 'Wrong file path')
assert(entry.position.line == 20, 'Wrong line number')
print('✓ Jump recording test passed')

-- Test trail state
local trail = history_manager.get_current_trail()
assert(#trail.entries == 1, 'Wrong number of entries')
assert(trail.current_index == 1, 'Wrong current index')
print('✓ Trail state test passed')

-- Test exploration state
local state = history_manager.determine_exploration_state()
assert(state == 'exploring', 'Wrong exploration state: ' .. tostring(state))
print('✓ Exploration state test passed')

-- Test navigation
print('Testing navigation...')
local success2, entry2 = history_manager.record_jump(to_location, {
  file_path = '/test/project/file3.lua',
  position = {line = 30, column = 15}
}, 'lsp_definition')

assert(success2 == true, 'Second jump recording failed')
assert(#history_manager.get_current_trail().entries == 2, 'Wrong number of entries after second jump')

-- Test go back
local back_success, back_entry = history_manager.go_back(1)
assert(back_success == true, 'Go back failed')
assert(history_manager.get_current_trail().current_index == 1, 'Wrong index after go back')

-- Test go forward
local forward_success, forward_entry = history_manager.go_forward(1)
assert(forward_success == true, 'Go forward failed')
assert(history_manager.get_current_trail().current_index == 2, 'Wrong index after go forward')

print('✓ Navigation test passed')

-- Test stats
print('Testing stats...')
local stats = history_manager.get_stats()
assert(stats.total_entries == 2, 'Wrong total entries in stats')
assert(stats.current_index == 2, 'Wrong current index in stats')
assert(stats.exploration_state == 'exploring', 'Wrong exploration state in stats')
print('✓ Stats test passed')

print('All basic tests passed!')