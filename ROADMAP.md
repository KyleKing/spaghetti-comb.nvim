# Roadmap

The core plugin (history tracking, bookmarks, UI components, persistence) is implemented. This roadmap covers hardening that foundation and then building the on-demand code-relations features that make the plugin genuinely useful for exploring large, unfamiliar, or generated codebases.

Historical planning docs (NEXT_STEPS.md, IMPLEMENTATION_PLAN.md, tickets/) were condensed into this file in July 2026; see git history if you need them.

## Phase 1: Trustworthy test suite and CI

The test infrastructure was broken until July 2026 (the runner never collected any cases), so existing behavior is under-verified. Goal: every merge runs a meaningful suite.

- [x] Fix the test runner so mini.test actually collects and runs spec files
- [x] Fix `mise.toml` tasks (stale module path, removed `tests-v1/`, Lua toolchain removed)
- [x] Restore the CI workflow from the orphaned `claude/add-ci-pipeline` branch
- [x] Salvage the expanded specs from that branch (history, navigation, ui, integration: ~600 lines of Task 13 tests, never executed; expect failures on first real run)
- [x] Replace remaining placeholder tests (`-- TODO: Implement in task 13.x`) with real cases, prioritizing: pruning and location recovery, project separation, jumplist integration, picker fallback
- [x] Adopt child-process isolation (`MiniTest.new_child_neovim`) for tests that touch windows, autocmds, or LSP so module-state leaks stop masking bugs
- [x] Clear the 21 selene warnings so `mise run typecheck` passes and can gate CI

Exit criteria: CI green on stable and nightly, no placeholder tests in core paths.

## Phase 2: Hardening and correctness

Make the recorded trail trustworthy before building more UI on top of it.

- [ ] Error handling: corrupted trail recovery in `history/manager.lua`, invalid entries in `ui/floating_tree.lua`, missing `.git` in `utils/project.lua`
- [ ] Config validation for all sections (`visual.color_scheme`, negative thresholds, keymap types) with actionable error messages
- [ ] LSP edge cases: server not running, empty responses, multiple results
- [ ] Enforce `history.max_entries` as a hard cap in `record_jump`
- [ ] Verify persistence round-trips with large datasets and handles corrupt JSON
- [ ] Vim help doc (`doc/spaghetti-comb.txt`) generated or written, wired to `mise run docs`

## Phase 3: Relations exploration (the "large codebase" features)

On-demand answers to "who calls this, what does this call, where is it defined" without losing your place. This revives the best ideas from the removed v1 relations panel, built on the current history/preview/picker infrastructure instead of a standalone panel.

- [ ] `navigation/relations.lua`: gather LSP references, definitions, implementations, and call hierarchy (incoming/outgoing) for the symbol under cursor
- [ ] Relations view reusing the floating tree + preview layout: symbol at root, references and callees as branches, `<CR>` to jump, `<C-]>` to re-root on the selected symbol (deep exploration)
- [ ] Record relation jumps into the existing history trail so breadcrumbs and back/forward work across exploration sessions
- [ ] Treesitter fallback for symbol context when no LSP is attached; grep fallback as last resort
- [ ] Picker mode for relations results (fuzzy filter across file names and code lines)

Deferred from v1 unless a concrete need appears: coupling metrics (`[C:0.7]` scores), coupling-based filtering, graph export.

## Phase 4: Performance at scale

Tune once relations features generate real load. Targets from SPEC.md: navigation ops < 50ms, preview < 200ms, < 10MB for 1000 entries.

- [ ] Benchmark suite (1000+ entry trails, 100+ bookmarks) as tests with documented baselines
- [ ] Index lookups: entry-by-id and entry-by-file maps in the history manager; hash lookup for bookmarks (`get_location_key` already exists)
- [ ] Async preview loading (`vim.uv.fs_*`) with a small LRU cache
- [ ] Virtual scrolling in the floating tree for long trails
- [ ] Trim stored context (target line + function name) and fetch full preview context on demand
- [ ] Periodic garbage collection: empty trails, bookmarks for deleted files, stale persistence files

## Phase 5: Polish and release

- [ ] Standardize error messages and `vim.notify` usage across modules
- [ ] README walkthrough with screenshots or a recorded demo
- [ ] CONTRIBUTING.md, and ARCHITECTURE notes folded into DEVELOPER.md
- [ ] Beta test against real large projects (a generated codebase, a big monorepo) with several LSP servers (ts_ls, rust-analyzer, pyright, gopls)
- [ ] Tag v0.1.0

## Later ideas

Kept intentionally out of scope until the above ships: session management across Neovim instances, telescope/trouble/DAP integrations, git blame integration, shared team bookmarks, coupling analysis dashboard.
