-- HACK: Copied from https://dev.to/miguelcrespo/how-to-write-a-neovim-plugin-in-lua-30p9
--  Useful as a positive control before replacing with logic relevant for my use case

local function main()
    print("Hello from our plugin")
end

local function setup()
    local augroup = vim.api.nvim_create_augroup("ScratchBuffer", { clear = true })

    vim.api.nvim_create_autocmd("VimEnter", {
        group = augroup,
        desc = "Set a fennel scratch buffer on load",
        once = true,
        callback = main,
    })
end

return { setup = setup }
