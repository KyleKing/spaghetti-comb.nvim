# Where is my executable?

> [!WARNING]
> This plugin is incomplete because it was not something I found I needed. I'll leave this as archived if I want to revisit creating a plugin or revisit this use case

Efficiently find executables (such as `eslint` or `flake8`) in mono-repos for other nvim plugins (like `conform` and `nvim-lint`).

Correctly supports `poetry` (`.venv`) and JavaScript/TypeScript/etc. (`node_modules`). Please submit an issue to request additional languages.

## Example

In the below example `eslint (A)` would be found for `file-A.ts` while `eslint (B)` would be found for `file-B.js`. The benefit is that any locally-installed `eslint` plugins and the specific `eslint` version are scoped to the files within that directory. In the same fashion, `flake8` is found for `file.py`; however any files in `Git Root/*.*` would use the system-wide `flake8` or `eslint` binary (if it is installed) because there is no local version within the git directory.

```txt
- Git Root and/or NVIM project root
    - ProjectA
        - node_modules/.bin/eslint (A)
        - src/file-A.ts
    - ProjectB
        - node_modules/.bin/eslint (B)
        - src/file-B.js
    - Project C
        - .venv/bin/flake8
        - src/file.py
```

## Usage

> [!NOTE]
> Need to provide guidance on configuring for LazyVim
>
> For now, locally test with:
>
> ```lua
> {
>   dir = "~/Developer/kyleking/find-relative-executable.nvim",
>   name = "find-relative-executable",
>   -- options = {}, -- PLANNED: This should be all that is needed
>   config = function ()
>       require("find-relative-executable").setup()
>   end
> }
> ```

```lua
local where_is_my_executable = require("where_is_my_executable")
where_is_my_executable.find("eslint") -- Uses the currently visible buffer

-- Or provide your own path
where_is_my_executable.find("flake8", vim.fn.getcwd() .. "some/path/file.py")
```

nvim-lint example:

```lua
local lint = require('lint')
local my_plugin = require('my-exec-finder')

lint.linters_by_ft = {
  python = {
    function()
      return {
        cmd = my_plugin.get_executable('flake8') or 'flake8',  -- fallback to system-wide if local not found
        args = { '--format', 'default', vim.api.nvim_buf_get_name(0) },
        stdin = true,
      }
    end
  },
  typescript = {
    function()
      return {
        cmd = my_plugin.get_executable('eslint') or 'eslint',
        args = { '--stdin', '--stdin-filename', vim.api.nvim_buf_get_name(0) },
        stdin = true,
      }
    end
  }
}
```

conform example

```lua
local conform = require('conform')
local my_plugin = require('my-exec-finder')

conform.setup {
  formatters_by_ft = {
    python = {
      function()
        return { cmd = my_plugin.get_executable('black') or 'black' }
      end
    },
    javascript = {
      function()
        return { cmd = my_plugin.get_executable('prettier') or 'prettier' }
      end
    }
  }
}
```

Structure

```lua
my-nvim-plugin/
├── lua/
│   └── my-exec-finder/
│       └── init.lua
├── README.md
└── init.lua
```

```
{
  'path-to-your/my-nvim-plugin',
  config = function()
    require('my-exec-finder')
  end
}
```

## Tasks

- [ ] Initialize plugin based on template and document local testing with LazyVim
- [ ] Document integration with `conform` and `nvim-lint` using LazyVim
- [ ] Implement test framework
- [ ] Generate Vim Documentation
- [ ] Link related plugins (if any?) or document other alternatives
