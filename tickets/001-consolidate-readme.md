# Ticket 001: Consolidate README.md

## Goal
Create a user-facing README.md that focuses on "why" - project purpose, features, installation, and v1->v2 migration path. Remove implementation details and spec details.

## Current State
- README.md contains both v1 and v2 information mixed together
- Includes implementation details that belong in DEVELOPER.md
- Includes spec details that belong in SPEC.md
- Missing clear migration path from v1 to v2

## Tasks

1. **Extract "why" content**
   - Project purpose: Help developers untangle complex codebases
   - Key features: Code exploration, relationship visualization
   - Installation instructions (simplified)
   - Quick start guide

2. **Document v1->v2 migration path**
   - Explain why v2 was started:
     - v1: Relations panel approach (split window with focus mode)
     - v2: Breadcrumb-based navigation (extends built-in Neovim functionality)
   - Document what can be reused from v1:
     - `analyzer.lua` - LSP integration patterns
     - `coupling/` - Metrics and graph visualization
     - `navigation.lua` - Navigation stack concepts
     - `persistence/` - Storage patterns
   - No backward compatibility concerns - document clean migration

3. **Remove implementation details**
   - Move architecture details to DEVELOPER.md
   - Move testing details to DEVELOPER.md
   - Move configuration examples to DEVELOPER.md

4. **Remove spec details**
   - Move use cases to SPEC.md
   - Move feature specifications to SPEC.md
   - Move error handling to SPEC.md

## Acceptance Criteria

- [ ] README.md focuses solely on "why" and "what users need to know"
- [ ] Clear explanation of v1 vs v2 differences
- [ ] Migration path documented
- [ ] Installation and quick start are clear
- [ ] No implementation details remain
- [ ] No spec details remain
- [ ] Single clear narrative for users

## Files to Modify

- `/README.md` - Rewrite to focus on user-facing content

## Demo

After completion, README.md should be readable by a new user who wants to:
1. Understand what the plugin does
2. Install it
3. Get started quickly
4. Understand the v1->v2 transition

## Test

```bash
# Verify README.md is readable and focused
cat README.md | head -50
# Should show project purpose, features, installation - not implementation details
```

