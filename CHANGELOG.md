## v0.2.0 (2026-11-05)

### Feat

- garbage-collect stale persistence and dead-file bookmarks at startup
- report files changed since index in status and sc
- add :SpaghettiCombResume recap of recent trail entries
- resolve the enclosing symbol for relation commands
- enrich trail entries with dwell, interaction kind, note, and score
- harden trail persistence, config, and rendering against bad data
- sc CLI and command registrations
- relations tree and orientation views
- seek, related, and index-health commands
- content-addressed history search with codebase widening
- add substrate adapters for Vera and codanna

### Fix

- run picker jumps in the target window and surface ambiguity candidates

## v0.1.1 (2026-09-04)

### Refactor

- replace the deprecated per-buffer and per-window option API
- require nvim 0.13 and lean on its filesystem builtins

## v0.1.0 (2026-08-31)

### Feat

- add demo scenarios for navigation, LSP, and advanced features
- implement Task 12 - Optional Persistence System
- implement Tasks 9-11 - Infrastructure Components
- implement Tasks 7 & 8 - Complete Phase 2 UI Components
- implement Task 6 - Hotkey-Triggered Breadcrumb System (Phase 2 Part 1)
- implement Task 5 - Bookmark Management System
- implement Task 4
- Implement Task 3
- finish implementing Task 2
- add MiniDoc
- add breadcrumbs proposal to implementation plan
- improve logging during usage
- implement split window rather than floating panel
- implement Phase 5
- implement Phase 4
- improve Phase 3
- implement Phase 3
- finish Phase 2
- run selene
- finish Phase 1
- partial Task 2
- initialize the project

### Fix

- scope cursor_jump_timer as module-local to avoid global leak
- cache negative project-root lookups
- reject unreadable paths in project root fallback
- debounce LSP cursor tracking and cache project root by directory
- reset LSP cursor tracking when tracked buffer was wiped
- untrack deps/mini.nvim gitlink so clones don't fail
- normalize log level before nil-config guard in should_log
- correct filereadable guards on missing files
- nvim 0.12 compat and bug fixes salvaged from CI branch
- repair test runner so mini.test actually executes specs
- do not use insecure loadstring
- add error handling when closing the panel

### Refactor

- share demo console formatting and drive run_all from one registry
- remove all v2 references from codebase
- rename remaining Spaghetti Comb to v2
- rename to spaghetti-comb-v2.nvim
- rename to v1
- purge repo
