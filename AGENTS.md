# Agent guidelines

## Commands

- `mise run ci` runs every gate: lint (stylua check + selene), typecheck (emmylua_check), and test
- `mise run format` fixes formatting
- `mise run test` runs all specs headlessly and `mise run test-file -- -f <path>` runs one file
- `hk check --all` runs the git-hook checks against the whole tree

Run `mise run ci` before reporting work as done.

## Layout

- `lua/spaghetti-comb/init.lua` is the module entry point. `plugin/init.lua` only guards double-loading and requires it
- Specs live in `lua/spaghetti-comb/tests/*_spec.lua` and run with mini.test via `scripts/minimal_init.lua`
- `deps/mini.nvim` is a vendored test dependency cloned by the `deps-mini-nvim` task. Never edit it

## Conventions

- 4-space indentation enforced by stylua. selene and emmylua_check must also pass, and emmylua treats warnings as errors
- Annotate public functions with LuaCATS comments. `.emmyrc.json` configures the checker and `.luarc.json` the editor LSP
- In specs, bind mini.test locally (`local MiniTest = require("mini.test")`) instead of relying on the runtime global, so the type checker can resolve it
- Headless Neovim does not exit after a failed `-c` command, so keep every Lua entry point in mise tasks wrapped in `pcall` with an explicit `cquit 1`
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `build:`) and the commit-msg hook enforces them

This file is template-owned and `copier update` keeps it current. Put project-specific guidance in `AGENTS.local.md` (loaded below when present) or in a nested `AGENTS.md` scoped to its directory.

@AGENTS.local.md
