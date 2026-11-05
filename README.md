# spaghetti-comb.nvim

Semantic entry points, verified structure, and a memory that survives exploration — for codebases you did not write and do not yet understand. The name is a playful reference to "spaghetti code": this plugin is a comb for untangling unfamiliar codebases.

## Why

Exploring a large or generated codebase fails in three familiar ways: you know the concept but not the name; you find the symbol but not its callers; and an hour in, you have forgotten how you arrived anywhere. This plugin attacks all three:

- **Seek** — natural-language search (vera-ai: hybrid BM25 + embeddings) finds the entry point when you do not know the identifier.
- **Relations** — callers, calls, and impact come from codanna's resolved call graph, not grep guesses.
- **Trail** — every jump (LSP, jumplist, seek, relations) records into a per-project history with branching, so re-finding and resuming are first-class.

The trail extends built-in Neovim behavior rather than replacing it. Semantic and structural jumps record back into the same trail, so exploration compounds.

## Requirements

- Neovim 0.10+
- [vera-ai](https://pypi.org/project/vera-ai/) (optional) — semantic features; absent, those commands error loudly and everything else works
- [codanna](https://github.com/bartolli/codanna) + [codanna.nvim](https://github.com/KyleKing/codanna.nvim) (optional) — relations features
- [mini.pick](https://github.com/echasnovski/mini.nvim) (optional) — a plain fallback picker is built in
- Treesitter parsers (optional) — on a keyword, relation commands resolve the enclosing function instead of the literal word
- An LSP server (optional) — jumplist tracking works without one

## Installation

With mini.deps:

```lua
local add, later = MiniDeps.add, MiniDeps.later

later(function()
    add({ source = "KyleKing/spaghetti-comb.nvim" })
    require("spaghetti-comb").setup()
end)
```

Or from a local checkout:

```lua
vim.opt.runtimepath:append("/path/to/spaghetti-comb.nvim")
require("spaghetti-comb").setup()
```

Index a project once for the substrate features (`vera-ai index .`, `codanna index .` in the project root). `:SpaghettiCombStatus` reports index age and how many changed files are newer than the index.

## Usage

Navigate as you normally would — LSP go-to-definition, `<C-o>`/`<C-i>`, file switching. Jumps record automatically. Then:

- `:SpaghettiCombSeek retry with backoff` — semantic search; `<CR>` jumps and records
- `:SpaghettiCombRelated` on a selection — "did something like this already exist"
- `:SpaghettiCombCallers` — verified callers in a tree; `<C-]>` re-roots for deeper exploration
- `:SpaghettiCombHistory` — trail picker, ranked by recency-weighted score; `<C-o>` widens a typed query from the trail to the whole codebase
- `:SpaghettiCombResume` — chronological recap of where you were
- `:SpaghettiCombOrient` — project map: routes, env vars, entry points, hotspots

### Commands

| Command                                                       | Description                                        |
| ------------------------------------------------------------- | -------------------------------------------------- |
| `:SpaghettiCombSeek [query]`                                  | Semantic codebase search                           |
| `:SpaghettiCombRelated`                                       | Implementations related to the selected code       |
| `:SpaghettiCombCallers [symbol]`                              | Callers of the symbol in the relations tree        |
| `:SpaghettiCombCalls [symbol]`                                | Calls made by the symbol in the relations tree     |
| `:SpaghettiCombImpact [symbol]`                               | Impact graph of the symbol in the relations tree   |
| `:SpaghettiCombOrient`                                        | High-level project map in the relations tree       |
| `:SpaghettiCombHistory`                                       | Navigation history picker                          |
| `:SpaghettiCombResume [N]`                                    | Recap of the N most recent trail entries           |
| `:SpaghettiCombNote [text]`                                   | Set a note on the current trail entry (clear: no args) |
| `:SpaghettiCombBreadcrumbs`                                   | Toggle breadcrumb trail view                       |
| `:SpaghettiCombTree`                                          | Toggle navigation tree with preview                |
| `:SpaghettiCombBookmarks`                                     | Bookmark picker                                    |
| `:SpaghettiCombBookmarkToggle`                                | Toggle bookmark at cursor                          |
| `:SpaghettiCombBookmarkClear [global]`                        | Clear bookmarks                                    |
| `:SpaghettiCombBack` / `:SpaghettiCombForward`                | Move through the trail                             |
| `:SpaghettiCombJumpTo {index}`                                | Jump to a trail entry                              |
| `:SpaghettiCombHistoryClear [all]`                            | Clear navigation history                           |
| `:SpaghettiCombStatus`                                        | Navigation status and substrate index health       |
| `:SpaghettiCombSaveHistory` / `:SpaghettiCombLoadHistory`     | Persist or restore history for the current project |
| `:SpaghettiCombSaveBookmarks` / `:SpaghettiCombLoadBookmarks` | Persist or restore bookmarks                       |
| `:SpaghettiCombStorageStats`                                  | Persistence storage statistics                     |
| `:SpaghettiCombCleanupPersistence [days]`                     | Delete persistence files older than N days         |
| `:SpaghettiCombListProjects`                                  | List projects with saved data                      |
| `:SpaghettiCombDebug` / `:SpaghettiCombLogLevel {level}`      | Debug helpers                                      |

The plugin sets no keymaps; the suggested bindings are commented at the bottom of `plugin/spaghetti-comb.lua`.

### For agents

`scripts/sc` exposes the same substrate headlessly — JSON on stdout, errors on stderr: `sc seek`, `sc related`, `sc callers`, `sc calls`, `sc impact`, `sc orient`, `sc status`. The trail is never injected into agent context; agents use the same tools and build their own.

Full reference: `:help spaghetti-comb` (`doc/spaghetti-comb.txt`).

## Configuration

Defaults shown; pass overrides to `setup()`:

```lua
require("spaghetti-comb").setup({
    display = {
        enabled = true,
        max_items = 10,          -- Breadcrumb entries shown
        hotkey_only = true,      -- Show breadcrumbs only on demand
        collapse_unfocused = true,
    },
    history = {
        max_entries = 1000,
        max_age_minutes = 30,
        pruning_debounce_minutes = 2,
        save_on_exit = false,    -- Enable persistence on VimLeavePre
        exploration_timeout_minutes = 5,
        gc_stale_days = 90,      -- Delete persisted data untouched this long; false disables
    },
    integration = {
        jumplist = true,
        lsp = true,
        mini_pick = true,
        statusline = true,
    },
    visual = {
        use_unicode_tree = true,
        color_scheme = "subtle",
        floating_window_width = 80,
        floating_window_height = 20,
    },
    bookmarks = {
        frequent_threshold = 3,  -- Visits before auto-bookmarking
        auto_bookmark_frequent = true,
    },
    debug = {
        enabled = false,
        log_level = "info",
    },
})
```

For the statusline component, call `require("spaghetti-comb.ui.statusline").get_status()` from your statusline config.

## Development

See [DEVELOPER.md](DEVELOPER.md). Quick commands:

```bash
mise run ci         # lint + typecheck + unit tests
mise run itest      # integration suite on a pinned flask clone (CLI + tmux PTY)
mise run demo       # interactive walkthrough of the trail features
```
