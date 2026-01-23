---
title: "Documentation Overhaul Plan"
description: "Plan for restructuring project documentation"
author: Claude
date: 2026-01-23
---

# Documentation Overhaul Plan

## Goal

Restructure project documentation to be:
1. **Centralized** - All documentation in `docs/`, with `_bmad-output/` only for BMAD planning artifacts
2. **Modular** - Focused templates for AI agents to create components correctly
3. **Standards-compliant** - Fix BMAD documentation standards violations
4. **Non-redundant** - Single source of truth for each topic

---

## Target Structure

### docs/ (All Documentation)

```text
docs/
├── README.md                           # Documentation index (entry point)
│
├── templates/                          # AI-focused creation guides
│   ├── README.md
│   ├── service-creation.md
│   ├── repository-creation.md
│   ├── migration-creation.md
│   ├── controller-creation.md
│   ├── router-creation.md
│   ├── model-creation.md
│   ├── module-creation.md
│   └── error-creation.md
│
├── architecture/
│   ├── README.md                       # Navigation index
│   ├── technical-architecture.md       # System architecture (enhanced with merged content)
│   ├── architectural-vision.md         # Core principles
│   ├── future-architecture-decisions.md # Planned changes
│   ├── api-contracts.md                # MOVED from _bmad-output/
│   ├── data-models.md                  # MOVED from _bmad-output/
│   └── ADRs/
│       ├── ADR-001-ServiceRegistry.md
│       ├── ADR-002-Module-Colocation-and-Simplification.md
│       ├── ADR-003-Clean-Architecture-Migration.md
│       └── ADR-004-AOP-Simplification.md
│
├── development/
│   ├── README.md                       # Dev setup overview
│   ├── getting-started.md              # MOVED from _bmad-output/development-guide.md
│   ├── deployment.md                   # MOVED from _bmad-output/deployment-guide.md
│   ├── troubleshooting.md              # MOVED from root README.md
│   ├── VSCODE_SETUP.md
│   └── XCODE_SETUP.md
│
├── testing/
│   ├── README.md                       # Primary testing reference
│   ├── standards-and-patterns.md       # RENAMED
│   └── performance.md                  # RENAMED
│
├── reference/
│   ├── README.md                       # Reference docs index
│   ├── source-tree.md                  # MOVED from _bmad-output/source-tree-analysis.md
│   └── external/                       # MOVED from documentation/external/
│       ├── README.md
│       ├── open-ai-api.pdf
│       ├── open-ai-api-1.pdf
│       ├── open-ai-api-1.txt
│       ├── vapor-testing.pdf
│       └── vapor-testing.txt
│
├── product/
│   └── prd.md
│
├── features/
│   └── api-versioning.md
│
├── planning/
│   ├── work/
│   └── archive/
│
├── CONDITIONAL_DOCS.md                 # Expanded navigation guide
└── DOCUMENTATION_STANDARDS.md          # Standards reference
```

### _bmad-output/ (BMAD Planning Only)

```text
_bmad-output/
├── README.md                           # Explains BMAD planning purpose
├── epics.md                            # Epic definitions
├── project-scan-report.json            # KEEP: BMAD resumability state
├── project-planning-artifacts/         # Planning outputs
└── implementation-artifacts/           # Sprint tracking, story files
    ├── sprint-status.yaml
    └── [story files]
```

**Removed from _bmad-output/:**
- `index.md` → content absorbed into `docs/README.md`
- `project-overview.md` → content absorbed into `docs/README.md`
- `architecture.md` → merged into `docs/architecture/technical-architecture.md`, then deleted
- `api-contracts.md` → moved to `docs/architecture/`
- `data-models.md` → moved to `docs/architecture/`
- `source-tree-analysis.md` → moved to `docs/reference/`
- `development-guide.md` → moved to `docs/development/`
- `deployment-guide.md` → moved to `docs/development/`

---

## Standards Clarification

**YAML Frontmatter:** Accepted as a CommonMark extension. All major documents will use frontmatter for metadata (title, description, date). This aligns with the BMAD standards doc which includes a frontmatter section.

**Archived Planning Docs:** Historical notice overrides the "no time estimates" rule. Archived docs retain original content with a notice explaining they contain historical estimates.

---

## Implementation

### Phase 1: Foundation

**1.1 Create docs/DOCUMENTATION_STANDARDS.md**

Referenced in `project-config.yaml:26` but doesn't exist. Adapt from `_bmad/bmm/data/documentation-standards.md`:
- CommonMark rules
- No time estimates rule (for new docs)
- Code block language requirements
- YAML frontmatter as accepted extension
- Quality checklist

**1.2 Untrack .DS_Store files**

```bash
git rm --cached docs/.DS_Store docs/documentation/.DS_Store docs/planning/.DS_Store
```

**1.3 Create _bmad-output/README.md**

```markdown
# BMAD Planning Artifacts

This directory contains BMAD workflow planning outputs only.

**For project documentation, see `docs/`.**

## Contents

| Item | Purpose |
|------|---------|
| `epics.md` | Epic and story definitions |
| `project-scan-report.json` | BMAD workflow resumability state |
| `project-planning-artifacts/` | Planning workflow outputs |
| `implementation-artifacts/` | Sprint tracking and story files |

## Note

Documentation files previously in this directory have been consolidated into `docs/`:
- Architecture docs → `docs/architecture/`
- Development guides → `docs/development/`
- Reference materials → `docs/reference/`
```

---

### Phase 2: Merge and Move Content

**2.1 Merge _bmad-output/architecture.md into technical-architecture.md**

Before deleting, review `_bmad-output/architecture.md` for any content not in `docs/architecture/technical-architecture.md`:
- Compare sections
- Merge unique content (if any)
- Ensure no information loss

**2.2 Update reference in future-architecture-decisions.md**

File `docs/architecture/future-architecture-decisions.md:499` references `_bmad-output/architecture.md`. Update to point to `docs/architecture/technical-architecture.md`.

```bash
# Find and update the reference
grep -n "_bmad-output/architecture" docs/architecture/future-architecture-decisions.md
# Edit to point to docs/architecture/technical-architecture.md
```

**2.3 Move API and data documentation**

```bash
mv _bmad-output/api-contracts.md docs/architecture/
mv _bmad-output/data-models.md docs/architecture/
```

**2.4 Move development documentation**

```bash
mv _bmad-output/development-guide.md docs/development/getting-started.md
mv _bmad-output/deployment-guide.md docs/development/deployment.md
```

**2.5 Move reference documentation**

```bash
mkdir -p docs/reference
mv _bmad-output/source-tree-analysis.md docs/reference/source-tree.md
mv docs/documentation/external docs/reference/external
rmdir docs/documentation
```

**2.6 Clean up _bmad-output/**

After merging and moving:
```bash
rm _bmad-output/index.md
rm _bmad-output/project-overview.md
rm _bmad-output/architecture.md
```

Keep: `epics.md`, `project-scan-report.json`, `project-planning-artifacts/`, `implementation-artifacts/`

---

### Phase 3: Create Templates

Create `docs/templates/` directory with 8 focused templates:

| Template | Source Patterns |
|----------|-----------------|
| `service-creation.md` | `CacheService.swift`, `OpenAIService.swift`, `EmailService.swift` |
| `repository-creation.md` | `Repository.swift`, `UserRepository.swift` |
| `migration-creation.md` | `AuthMigrations.swift`, `UserMigrations.swift` |
| `controller-creation.md` | `AuthController.swift`, `RulesGenerationController.swift` |
| `router-creation.md` | `AuthRouter.swift`, `RulesGenerationRouter.swift` |
| `model-creation.md` | `UserAccountModel.swift`, `User.swift`, `OpenAIError.swift` |
| `module-creation.md` | `AuthModule.swift`, `RulesGenerationModule.swift` |
| `error-creation.md` | `OpenAIError.swift`, `UserError.swift`, `AppError.swift` |

**Template structure:**
```yaml
---
title: "[Component] Creation Template"
description: "Guide for creating [component] in project-rulebook-be"
date: 2026-01-22
---
```
- Overview: when to use this template
- Step-by-step instructions with code examples
- Checklist for completion
- Reference files (links to actual implementations)
- Common mistakes to avoid

**Template README** (`docs/templates/README.md`):
- Index of all templates
- Quick reference: component type → template
- Link to `technical-architecture.md` for rules

---

### Phase 4: Standards Compliance

**4.1 Remove time estimates from active planning docs**

Files to modify in `docs/planning/work/`:

| File | Patterns to Remove |
|------|-------------------|
| `openapi-documentation/plan.md` | "Estimated Effort: X hours" |
| `openapi-documentation/tasks.md` | Duration estimates, "10-15 hours", task hour breakdowns |
| `remove-image-caching/plan.md` | "Estimated Effort: X hours" |
| `remove-image-caching/tasks.md` | "Estimated Duration: 6-9 hours", task hour breakdowns |
| `remove-image-caching/research.md` | Latency estimates (review - may be technical specs) |

**Comprehensive grep patterns:**
```bash
# Find all time estimate patterns
grep -rEn "(Estimated (Effort|Duration|Commits)|[0-9]+-[0-9]+ hours?|[0-9]+ hours?|~[0-9]+ hours?)" docs/planning/work/ --include="*.md"
```

**4.2 Add historical notices to archived planning docs**

Add to top of files in `docs/planning/archive/` that contain time estimates:

```markdown
> **Historical Document**
>
> This document was created during original planning and contains time estimates
> retained for historical reference. Do not use these estimates for future planning.
```

Do NOT modify the actual content - only add the notice.

**4.3 Add language tags to ALL unlabeled code blocks**

Files with unlabeled code blocks (comprehensive list):

| File | Approx Count |
|------|--------------|
| `docs/architecture/technical-architecture.md` | 21 |
| `docs/architecture/ADRs/ADR-003-Clean-Architecture-Migration.md` | 9+ |
| `docs/testing/README.md` | 3+ |
| Other files | Audit needed |

**Find all unlabeled blocks:**
```bash
grep -rn "^\`\`\`$" docs/ --include="*.md"
```

**Language mapping:**
| Content Type | Tag |
|--------------|-----|
| Directory trees | `text` |
| Swift code | `swift` |
| Shell commands | `bash` |
| JSON | `json` |
| HTTP requests | `http` |
| YAML | `yaml` |
| Plain text/output | `text` |

---

### Phase 5: Update References and Links

**5.1 Update root README.md**

Current references to fix:
- Line ~404: References `.claude/docs/*` - update to `docs/`
- Line ~84-86: Development setup links - verify paths after moves

```bash
# Find all internal doc references
grep -n "docs/" README.md
grep -n ".claude/docs" README.md
```

**5.2 Update docs/testing/README.md**

Line 13 references files that will be renamed:
- `Testing-Organization-Summary.md` → being merged/deleted
- `Testing-Standards-and-Patterns.md` → `standards-and-patterns.md`

**5.3 Update docs/architecture/future-architecture-decisions.md**

Line 499 references `_bmad-output/architecture.md` → update to `docs/architecture/technical-architecture.md`

**5.4 Scan for all broken references after moves**

```bash
# After all moves, find potentially broken links
grep -rn "_bmad-output/" docs/ --include="*.md"
grep -rn "documentation/external" docs/ --include="*.md"
grep -rn "Testing-Organization-Summary" docs/ --include="*.md"
grep -rn "Testing-Standards-and-Patterns" docs/ --include="*.md"
```

---

### Phase 6: Consolidation and Navigation

**6.1 Create section README files**

| File | Content |
|------|---------|
| `docs/README.md` | Documentation index, quick links, project overview |
| `docs/templates/README.md` | Template index with usage guide |
| `docs/architecture/README.md` | Architecture docs index, reading order, ADR status |
| `docs/development/README.md` | Development setup overview, links to guides |
| `docs/reference/README.md` | Reference materials index |
| `docs/reference/external/README.md` | External docs with descriptions and sources |

**6.2 Consolidate testing documentation**

Current:
- `README.md` - infrastructure overview
- `Testing-Organization-Summary.md` - reorganization history (redundant)
- `Testing-Standards-and-Patterns.md` - patterns guide
- `Performance-Test-Suite-Summary.md` - performance testing

Actions:
1. Merge useful content from `Testing-Organization-Summary.md` into `README.md`
2. Delete `Testing-Organization-Summary.md`
3. Rename `Testing-Standards-and-Patterns.md` → `standards-and-patterns.md`
4. Rename `Performance-Test-Suite-Summary.md` → `performance.md`
5. Update all references to renamed files

**6.3 Expand CONDITIONAL_DOCS.md**

Expand from 22 lines to comprehensive mapping:
- All 8 templates with "read when" conditions
- Architecture documents
- Testing documents
- Development documents
- Feature documents
- Reference documents

Target: 100+ lines with 25+ documentation mappings.

**6.4 Delete vapor-service-template.md**

After creating enhanced `docs/templates/service-creation.md`, delete `docs/development/vapor-service-template.md` (content superseded).

---

### Phase 7: Polish

**7.1 Add YAML frontmatter to major documents**

Template:
```yaml
---
title: "Document Title"
description: "Brief description"
date: YYYY-MM-DD
---
```

Files to update:
- `docs/architecture/technical-architecture.md`
- `docs/architecture/architectural-vision.md`
- `docs/architecture/future-architecture-decisions.md`
- `docs/testing/README.md`
- `docs/testing/standards-and-patterns.md`
- `docs/development/VSCODE_SETUP.md`
- `docs/development/XCODE_SETUP.md`
- All new README files created in Phase 6

**7.2 Trim root README.md**

Current: ~520 lines, Target: <500 lines

- Move troubleshooting section to `docs/development/troubleshooting.md`
- Keep essential quick-start content
- Link to detailed docs instead of duplicating

**7.3 Final validation**

```bash
echo "=== Documentation Validation ==="

echo "Time estimates in active planning (should be empty):"
grep -rEn "(Estimated (Effort|Duration)|[0-9]+-[0-9]+ hours|[0-9]+ hours)" docs/planning/work/ --include="*.md" | grep -v "Historical Document"

echo ""
echo "Unlabeled code blocks (should be empty):"
grep -rn "^\`\`\`$" docs/ --include="*.md"

echo ""
echo "References to old _bmad-output/ paths (should be empty):"
grep -rn "_bmad-output/\(architecture\|index\|project-overview\|development-guide\|deployment-guide\|source-tree\)" docs/ --include="*.md"

echo ""
echo "References to old testing file names (should be empty):"
grep -rn "Testing-Organization-Summary\|Testing-Standards-and-Patterns\|Performance-Test-Suite-Summary" docs/ --include="*.md"

echo ""
echo "Template count (should be 9):"
ls docs/templates/*.md 2>/dev/null | wc -l

echo ""
echo "_bmad-output/ contents (should be: README.md, epics.md, project-scan-report.json, 2 dirs):"
ls _bmad-output/

echo ""
echo "README.md line count (target <500):"
wc -l < README.md
```

---

## Summary

| Action | Count |
|--------|-------|
| Files moved from _bmad-output/ to docs/ | 6 |
| Files merged then deleted | 1 (architecture.md) |
| Files deleted (redundant) | 3 (index.md, project-overview.md, Testing-Organization-Summary.md) |
| Files kept in _bmad-output/ | 4 (README, epics, scan-report, 2 dirs) |
| New templates created | 8 |
| New README/index files created | 6 |
| Files renamed | 2 (testing docs) |
| Link updates required | 10+ references |
| Code blocks to fix | 30+ |
| Documents to add frontmatter | 10+ |

**End State:**
- `docs/` contains all project documentation
- `_bmad-output/` contains only BMAD planning artifacts
- 8 focused templates for AI agent productivity
- Full standards compliance (with frontmatter as accepted extension)
- Zero redundancy between directories
- All internal links updated and working
