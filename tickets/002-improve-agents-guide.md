# Ticket 002: Improve AGENTS.md

## Goal
Refine AGENTS.md to be concise AI-specific guidance. Keep development commands and quick architecture overview. Focus on what AI agents need to know quickly.

## Current State
- AGENTS.md contains development commands and architecture overview
- Some content overlaps with what will be in DEVELOPER.md
- Could be more scannable for AI tooling
- Architecture description references v1 structure (needs updating)

## Tasks

1. **Refine for AI agents**
   - Keep development commands (testing, linting, formatting, docs)
   - Keep quick architecture overview
   - Make it scannable with clear sections
   - Add quick reference for common tasks

2. **Update architecture description**
   - Note that v2 is the current focus
   - Reference v2 structure where appropriate
   - Keep high-level overview (not detailed)

3. **Allow duplication with DEVELOPER.md**
   - Some overlap is acceptable (different audiences)
   - AGENTS.md = quick reference for AI
   - DEVELOPER.md = detailed guide for humans

4. **Improve scannability**
   - Use clear headings
   - Use bullet points for commands
   - Keep sections concise
   - Add quick links/references

## Acceptance Criteria

- [ ] AGENTS.md is concise and scannable
- [ ] Development commands are clearly listed
- [ ] Architecture overview is updated for v2
- [ ] Suitable for AI tooling consumption
- [ ] Quick reference format maintained

## Files to Modify

- `/AGENTS.md` - Refine content for AI agents

## Demo

After completion, an AI agent should be able to:
1. Quickly find development commands
2. Understand the architecture at a glance
3. Know what tools are available
4. Understand the project structure

## Test

```bash
# Verify AGENTS.md is concise and scannable
wc -l AGENTS.md
# Should be relatively short (< 100 lines)
head -30 AGENTS.md
# Should show clear structure with commands
```

