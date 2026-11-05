# Roadmap

The core plugin (history tracking, bookmarks, UI components, persistence) is implemented. This roadmap covers hardening that foundation and then building the semantic + structural exploration features that make the plugin genuinely useful for navigating large, unfamiliar, or generated codebases.

Historical planning docs (NEXT_STEPS.md, IMPLEMENTATION_PLAN.md, tickets/) were condensed into this file in July 2026; see git history if you need them.

## Paradigm and use cases

Files and folders are spatial organization; semantic meaning is a second axis, and the trail is the record that joins them. The plugin's thesis: semantic tools seed and enrich exploration, and the navigation trail preserves orientation and judgment — including for harnesses, which reach the same substrate through the plugin's adapter layer rather than receiving the trail itself.

Target use cases, in priority order:

- **H5 Re-find** — "I saw a thing about X" → content-addressed trail search (JetBrains Recent Locations analogue, but persistent and per-project)
- **H1 Seed** — "I know the concept, not the name" → NL search → first entry point
- **Review cluster** — for code review (incl. second-look): "what are all the related abstractions", "did the agent reuse or reinvent a pattern", "high-level orientation for humans and agents"
- **H2 Orient** — "who calls this / what does it call / what breaks" → verified relations graph
- **H4 Resume** — "where was I" → chronological snippet recap (Parnin & DeLine, CHI 2010: 2x resumption success)
- **H7 Decide** — signposts at jump time: signatures, roles, centrality, preview

Explicitly out of scope: trail-as-agent-context (agents use the same substrate tools and build their own context), agent-originated trail recording, auto-injected editor state.

## Substrate decisions (empirical, 2026-11-05)

Bake-off on irm-0-null (~15k source files, Python/TS/Go): 13 known-answer NL queries scored for Recall@5/MRR, plus install, index, and crash behavior. Eval harness: `/tmp` session scripts (transient); numbers below.

### Semantic layer: **Vera** (`vera-ai`, Rust binary via uv/crates)

| Tool | Recall@5 | MRR | Index | Outcome |
|---|---|---|---|---|
| **vera-ai v2.3.1** | **10/13** | **0.622** | ~3 min, 1.6GB | **Chosen** |
| Semble | 10/13 | 0.564 | ~2 min | Close second; `find_related` UX is the reference but Vera's query-by-example matched it (snippet query surfaced the retry-abstraction family cross-file). Python+vicinity dep vs Rust binary |
| osgrep | — | — | died ~45 min | Stale since Dec 2025, single maintainer; install needed a `distutils` shim (node-gyp vs Python 3.14), indexer died mid-run. Disqualified operationally |
| SIFS | — | — | — | Right recipe (Model2Vec+BM25+JSON) but 2 stars / months old; skipped as unspikable risk |
| grepai | — | — | — | Dense-only default; its "hybrid" is a token-ratio, not BM25 |
| vectorcode | — | — | — | Dense-only, stale, PyTorch+Chroma weight, no file watching |
| claude-context | — | — | — | Needs Milvus via Docker or Zilliz Cloud; ops burden |
| codanna semantic | 5/13 | 0.163 | ~35 min | Docstring-gated embeddings (only documented symbols indexed); confirmed weak on real code |

Vera specifically: hybrid BM25 + `potion-code-16M-v2` (32MB static Model2Vec embeddings, no torch/GPU contention with local LLMs), RRF fusion, optional Jina-ONNX cross-encoder reranker, `search --json`, `overview` and `structural` orientation commands, MCP server mode, `watch` for incremental index updates. Query-by-example verified working. Note: `vera serve` is an OpenAI-compatible *embedding/rerank* server, not a query daemon — there is no warm-query HTTP path in v2.3.1; the CLI (~5s cold start on the eval repo) is the transport.

### Structural layer: **codanna** (Rust, via `codanna.nvim`)

| Tool | Outcome |
|---|---|
| **codanna v0.16+** | **Chosen** — verified call-site edges (`find_callers` returns exact `call_line`/`call_column`), `analyze_impact`, 636k symbols / 511k edges indexed, 0.3s queries, Lua support |
| codesearch | Disqualified — unindexed per-call scan crashed on a non-UTF-8 file after 108s / 2GB RSS on this repo |
| Serena/LSP | Comparable but not needed: nvim already speaks LSP for live-buffer precision; Serena adds nothing a personal plugin needs |
| graphtrail | Unspiked; noted as future alternative if codanna stalls |

Trade-off accepted: ~35 min initial index on a 15k-file monorepo (embeddings + edge resolution) — one-time/`--watch` cost, not per-query.

## Phase 1: Trustworthy test suite and CI ✅

Exit criteria met: CI green on stable and nightly, no placeholder tests in core paths.

## Phase 2: Hardening and trail enrichment

Make the recorded trail trustworthy and richer before building more UI on it.

- [ ] Error handling: corrupted trail recovery in `history/manager.lua`, invalid entries in `ui/floating_tree.lua`, missing `.git` in `utils/project.lua`
- [ ] Config validation for all sections (`visual.color_scheme`, negative thresholds, keymap types) with actionable error messages
- [ ] LSP edge cases: server not running, empty responses, multiple results
- [ ] Enforce `history.max_entries` as a hard cap in `record_jump`
- [ ] Verify persistence round-trips with large datasets and handles corrupt JSON
- [ ] Trail schema enrichment (`NavigationEntry`): `symbol` (stable identity, survives line shifts), `interaction_kind` (read/edit/jump — edits are the strong relevance signal), `dwell_ms` (enter/leave), `note`, decay-weighted score alongside raw `visit_count` (Mylyn DOI lesson: predictable and user-visible, never auto-hiding). Storage migration for existing entries
- [ ] Vim help doc (`doc/spaghetti-comb.txt`) generated or written, wired to `mise run docs`

## Phase 3: Substrate adapters + semantic features

Thin adapters normalize both substrates into one internal type set; human pickers and an agent-facing CLI consume the same layer. No fallback chain — codanna and Vera are required for the features that use them; missing tools error loudly.

- [x] `substrate/types.lua`: normalized `SearchHit`, `RelationItem`, `SkeletonNode` (file_path, position, symbol, kind, signature/docstring, score, source)
- [x] `substrate/codanna.lua`: async-only `codanna mcp --json` calls; codanna.nvim required for its configured binary path (its `exec_async` drops the error envelope on non-zero exit, so the adapter self-execs to keep exit codes — fix upstream in codanna.nvim); callers/calls/impact/search_symbols/index_info; maps exit codes (1=not found, 2=error, 7=index-version mismatch → "run `codanna index --force`")
- [x] `substrate/vera.lua`: `vera-ai search <q> --json` via `vim.system` (async); `find_related` query-by-example; `overview`/`structural` intents; missing binary → loud error
- [x] **H5**: content-addressed trail search — history picker filters by snippet text / `context.function_name` / file path / branch; `<C-o>` widens the same picker to Vera codebase search ("my memory, then the codebase")
- [x] **H1**: `:SpaghettiCombSeek` — Vera NL search picker with signature/snippet signposts; choosing a result records a jump (`jump_type="vera_seek"`)
- [x] **Review cluster**: `find_related` — query-by-example on symbol/selection under cursor → ranked related implementations (proven on irm: surfaced the retry-abstraction family); `orient` — Vera `overview` + `structural` (routes/env/sql sweeps) + codanna index counts → high-level codebase map in the tree view
- [x] **H2**: `navigation/relations.lua` — codanna callers/calls/impact in `ui/relations_tree.lua` (a floating_tree sibling; single-level fetch on open, `<C-]>` re-roots for deep exploration), jumps recorded (`jump_type="codanna_*"`)
- [x] `scripts/sc`: headless-nvim CLI exposing the same adapters (`sc seek`, `sc related`, `sc callers`, `sc calls`, `sc impact`, `sc orient`, `sc status`) — the agent-facing surface for wavez/second-look/ACP; same Lua code, second transport. Build the minimal version; expand when a real caller exists
- [x] Index health in `:SpaghettiCombStatus` — Vera index age/size, codanna `get_index_info` (symbol count, edge count, version)

## Phase 4: Performance at scale

- [ ] Benchmark suite (1000+ entry trails, 100+ bookmarks) as tests with documented baselines
- [ ] Index lookups: entry-by-id and entry-by-file maps; hash lookup for bookmarks
- [ ] Async preview loading (`vim.uv.fs_*`) with a small LRU cache
- [ ] Virtual scrolling in the floating tree for long trails
- [ ] Index freshness: evaluate `vera watch` for incremental reindexing on edit; codanna `--watch` equivalent; staleness surfaced in `:SpaghettiCombStatus`
- [ ] Warm-path discipline: no warm Vera query path exists in v2.3.1 (`serve` is embedding-only); revisit if Vera adds a query daemon or the MCP stdio transport proves worth keeping alive; codanna calls stay async
- [ ] Periodic garbage collection: empty trails, bookmarks for deleted files, stale persistence files

## Phase 5: Polish and release

- [ ] Standardize error messages and `vim.notify` usage across modules
- [ ] README reframe: "semantic entry points, verified structure, and a memory that survives exploration"; walkthrough demo
- [ ] Trail recap (`:SpaghettiCombResume`) — chronological snippets of last N entries (H4; deferred here only because H5/seek/review-cluster rank higher)
- [ ] CONTRIBUTING.md, ARCHITECTURE notes folded into DEVELOPER.md
- [ ] Beta test against real large projects (a generated codebase, a big monorepo) with several LSP servers
- [ ] Tag v0.1.0

## Later ideas

- wavez-facing: expose adapters through wavez's socket/MCP when wavez M3's Neovim pickers land (wavez's own SQLite code-intel store is a future comparable provider)
- `find_related` for second-look review flow: "agent invented an Nth implementation of X" as a review check
- Semantic trail search via embeddings — only if keyword search measurably fails (trail corpus is small; lexical-first per re-finding research)
- Task/thread labels grouping trail segments into resumable units (Mnemora "Threads" precedent)
- Session management across Neovim instances, telescope/trouble/DAP integrations, git blame integration, shared team bookmarks, coupling analysis dashboard
