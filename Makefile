LUA := tests/ scripts/ plugin/ lua/

test: deps/mini.nvim # Run all test files
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

test_file: deps/mini.nvim # Run test from file at `$FILE` environment variable
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

lint: # Format code using stylua
	stylua $(LUA) --check

format: # Format code using stylua (fix)
	stylua $(LUA)

typecheck: # Check for errors with selene
	selene $(LUA)

luals: # Run lua-language-server type checking
	@echo "lua-language-server type checking not implemented yet"

docs: deps/mini.nvim # Generate plugin documentation using mini.doc
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua require('mini.doc').generate()" -c "qa!"

setup: # Initialize plugin from template
	@echo "Plugin structure already set up"

deps/mini.nvim: # Download 'mini.nvim' to use its 'mini.test' testing module
	@mkdir -p deps
	git clone --filter=blob:none https://github.com/echasnovski/mini.nvim $@

.PHONY: test test_file lint format luals docs setup
