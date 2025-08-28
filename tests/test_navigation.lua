local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local child = MiniTest.new_child_neovim()

local T = new_set({
  hooks = {
    pre_case = function()
      child.restart({ '-u', 'scripts/minimal_init.lua' })
      child.lua([[Navigation = require('spaghetti-comb.navigation')]])
    end,
    post_once = child.stop,
  },
})

T['create_entry()'] = function()
  child.bo.readonly = false
  child.api.nvim_buf_set_lines(0, 0, -1, true, { 'function test() {', '  return 42;', '}' })
  child.api.nvim_win_set_cursor(0, { 1, 9 })
  
  local entry = child.lua_get([[Navigation.create_entry({ text = 'test', type = 'function' })]])
  
  expect.no_error(function()
    assert(entry.symbol == 'test', 'Symbol should match')
    assert(entry.type == 'function', 'Type should match')
    assert(entry.line == 1, 'Line should be 1')
    assert(entry.col == 10, 'Column should be 10 (1-indexed)')
    assert(entry.language ~= nil, 'Language should be set')
    assert(entry.timestamp ~= nil, 'Timestamp should be set')
  end)
end

T['push()'] = new_set()

T['push()']['works with valid symbol'] = function()
  local result = child.lua_get([[Navigation.push({ text = 'test', type = 'function' })]])
  eq(result, true)
  
  local stack_info = child.lua_get([[Navigation.get_stack_info()]])
  eq(stack_info.current_index, 1)
  eq(stack_info.total_entries, 1)
end

T['push()']['handles nil symbol'] = function()
  local result = child.lua_get([[Navigation.push(nil)]])
  eq(result, false)
end

T['peek()'] = function()
  child.lua([[Navigation.push({ text = 'test', type = 'function' })]])
  local entry = child.lua_get([[Navigation.peek()]])
  
  expect.no_error(function()
    assert(entry ~= nil, 'Entry should not be nil')
    assert(entry.symbol == 'test', 'Symbol should match')
  end)
end

T['pop()'] = function()
  child.lua([[
    Navigation.push({ text = 'first', type = 'function' })
    Navigation.push({ text = 'second', type = 'function' })
  ]])
  
  local popped = child.lua_get([[Navigation.pop()]])
  
  expect.no_error(function()
    assert(popped ~= nil, 'Popped entry should not be nil')
    assert(popped.symbol == 'first', 'Should pop to first entry')
  end)
  
  local stack_info = child.lua_get([[Navigation.get_stack_info()]])
  eq(stack_info.current_index, 1)
end

T['navigate_next()'] = function()
  child.lua([[
    Navigation.push({ text = 'first', type = 'function' })
    Navigation.push({ text = 'second', type = 'function' })
    Navigation.pop()
  ]])
  
  local next_entry = child.lua_get([[Navigation.navigate_next()]])
  
  expect.no_error(function()
    assert(next_entry ~= nil, 'Next entry should not be nil')
    assert(next_entry.symbol == 'second', 'Should navigate to second entry')
  end)
  
  local stack_info = child.lua_get([[Navigation.get_stack_info()]])
  eq(stack_info.current_index, 2)
end

T['can_navigate_back()'] = function()
  eq(child.lua_get([[Navigation.can_navigate_back()]]), false)
  
  child.lua([[Navigation.push({ text = 'test', type = 'function' })]])
  eq(child.lua_get([[Navigation.can_navigate_back()]]), false)
  
  child.lua([[Navigation.push({ text = 'test2', type = 'function' })]])
  eq(child.lua_get([[Navigation.can_navigate_back()]]), true)
end

T['can_navigate_forward()'] = function()
  child.lua([[
    Navigation.push({ text = 'first', type = 'function' })
    Navigation.push({ text = 'second', type = 'function' })
  ]])
  eq(child.lua_get([[Navigation.can_navigate_forward()]]), false)
  
  child.lua([[Navigation.pop()]])
  eq(child.lua_get([[Navigation.can_navigate_forward()]]), true)
end

T['clear_stack()'] = function()
  child.lua([[
    Navigation.push({ text = 'test', type = 'function' })
    Navigation.clear_stack()
  ]])
  
  local stack_info = child.lua_get([[Navigation.get_stack_info()]])
  eq(stack_info.current_index, 0)
  eq(stack_info.total_entries, 0)
end

return T