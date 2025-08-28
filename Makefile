# Run all test files
test: deps/mini.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

# Run test from file at `$FILE` environment variable
test_file: deps/mini.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

# Format code using stylua
lint:
	stylua lua/ --check

# Format code using stylua (fix)
format:
	stylua lua/

# Run lua-language-server type checking
luals:
	@echo "lua-language-server type checking not implemented yet"

# Generate plugin documentation using mini.doc
docs: deps/mini.nvim
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua require('mini.doc').generate()" -c "qa!"

# Initialize plugin from template
setup:
	@echo "Plugin structure already set up"

# Download 'mini.nvim' to use its 'mini.test' testing module
deps/mini.nvim:
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/echasnovski/mini.nvim $@

.PHONY: test test_file lint format luals docs setup
