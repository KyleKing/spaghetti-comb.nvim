-- Config validation tests
local MiniTest = require("mini.test")
local config = require("spaghetti-comb.config")

local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
    hooks = {
        post_once = child.stop,
    },
})

T["config"] = MiniTest.new_set()

T["config"]["sanitize drops every invalid value and reports them all"] = function()
    local cleaned, errors = config.sanitize({
        display = { max_items = 0, enabled = "yes" },
        history = { max_entries = -5, max_age_minutes = 10 },
        visual = { color_scheme = "neon" },
        integration = { lsp = "maybe" },
        bookmarks = { frequent_threshold = "three" },
        debug = { log_level = "chatty" },
        keymaps = { open = 42 },
    })

    -- Every invalid key removed; the valid neighbor survives
    MiniTest.expect.equality(cleaned.display.max_items, nil)
    MiniTest.expect.equality(cleaned.display.enabled, nil)
    MiniTest.expect.equality(cleaned.history.max_entries, nil)
    MiniTest.expect.equality(cleaned.history.max_age_minutes, 10)
    MiniTest.expect.equality(cleaned.visual.color_scheme, nil)
    MiniTest.expect.equality(cleaned.integration.lsp, nil)
    MiniTest.expect.equality(cleaned.bookmarks.frequent_threshold, nil)
    MiniTest.expect.equality(cleaned.debug.log_level, nil)
    MiniTest.expect.equality(cleaned.keymaps.open, nil)

    -- One error per invalid key, each naming the key
    MiniTest.expect.equality(#errors, 8)
    MiniTest.expect.equality(table.concat(errors, "\n"):find("history.max_entries") ~= nil, true)
    MiniTest.expect.equality(table.concat(errors, "\n"):find("keymaps.open") ~= nil, true)
end

T["config"]["sanitize keeps valid values and accepts keymap strings and functions"] = function()
    local cleaned, errors = config.sanitize({
        visual = { color_scheme = "subtle", floating_window_width = 120 },
        keymaps = { toggle = "<leader>st", custom = function() end },
    })

    MiniTest.expect.equality(#errors, 0)
    MiniTest.expect.equality(cleaned.visual.color_scheme, "subtle")
    MiniTest.expect.equality(cleaned.visual.floating_window_width, 120)
    MiniTest.expect.equality(type(cleaned.keymaps.custom), "function")
end

T["config"]["non-table sections and values are rejected wholesale"] = function()
    local cleaned, errors = config.sanitize({ history = "bogus", display = 42, keymaps = "no" })

    MiniTest.expect.equality(cleaned.history, nil)
    MiniTest.expect.equality(cleaned.display, nil)
    MiniTest.expect.equality(cleaned.keymaps, nil)
    MiniTest.expect.equality(#errors, 3)
end

T["config"]["validate aggregates errors instead of failing on the first"] = function()
    local ok, errors = config.validate({ history = { max_entries = -1, max_age_minutes = 0 } })

    MiniTest.expect.equality(ok, false)
    MiniTest.expect.equality(#errors, 2)

    local ok2 = config.validate({ history = { max_entries = 50 } })
    MiniTest.expect.equality(ok2, true)
end

T["config setup"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.restart({ "-u", "scripts/minimal_init.lua" })
            child.lua([==[
              _G.notifies = {}
              vim.notify = function(msg, level) table.insert(_G.notifies, { msg = msg, level = level }) end
            ]==])
        end,
    },
})

T["config setup"]["setup notifies once with all invalid keys and falls back to defaults"] = function()
    child.lua([==[
      require("spaghetti-comb").setup({
        history = { max_entries = -1, max_age_minutes = 10 },
        visual = { color_scheme = "neon" },
        keymaps = { open = 3 },
      })
    ]==])

    MiniTest.expect.equality(child.lua_get([==[#_G.notifies]==]), 1)
    local msg = child.lua_get([==[_G.notifies[1].msg]==])
    for _, key in ipairs({ "history.max_entries", "visual.color_scheme", "keymaps.open" }) do
        MiniTest.expect.equality(msg:find(key, 1, true) ~= nil, true)
    end

    -- Invalid keys fell back to defaults; valid keys kept their values
    MiniTest.expect.equality(child.lua_get([==[require("spaghetti-comb").get_config().history.max_entries]==]), 1000)
    MiniTest.expect.equality(child.lua_get([==[require("spaghetti-comb").get_config().history.max_age_minutes]==]), 10)
    MiniTest.expect.equality(
        child.lua_get([==[require("spaghetti-comb").get_config().visual.color_scheme]==]),
        "subtle"
    )
end

return T
