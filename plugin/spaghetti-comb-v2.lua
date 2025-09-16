-- Spaghetti Comb v2 - Neovim Plugin for Code Exploration
-- Prevent loading if already loaded or if Neovim version is too old
if vim.g.loaded_spaghetti_comb or vim.fn.has("nvim-0.8") ~= 1 then return end
vim.g.loaded_spaghetti_comb = 1

require("spaghetti-comb-v2").setup()
