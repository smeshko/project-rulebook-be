---
title: "Documentation Standards"
description: "Technical documentation standards for project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Documentation Standards

Standards for creating and maintaining documentation in this project.

---

## Critical Rules

### Rule 1: CommonMark Strict Compliance

ALL documentation MUST follow CommonMark specification exactly.

### Rule 2: No Time Estimates

NEVER document time estimates, durations, or completion times for any workflow, task, or activity. This includes:

- Workflow execution time (e.g., "30-60 min", "2-8 hours")
- Task duration estimates
- Implementation time ranges
- Any temporal measurements

**Instead:** Focus on workflow steps, dependencies, and outputs.

---

## CommonMark Essentials

### Headers

- Use ATX-style ONLY: `#` `##` `###` (NOT Setext underlines)
- Single space after `#`: `# Title` (NOT `#Title`)
- No trailing `#`: `# Title` (NOT `# Title #`)
- Hierarchical order: Don't skip levels (h1 → h2 → h3, not h1 → h3)

### Code Blocks

Use fenced blocks with language identifier:

````markdown
```swift
let example = "code"
```
````

**Required Language Tags:**

| Content Type | Tag |
|--------------|-----|
| Swift code | `swift` |
| Shell commands | `bash` |
| JSON | `json` |
| YAML | `yaml` |
| Directory trees | `text` |
| Plain text/output | `text` |
| HTTP requests | `http` |

### Lists

- Consistent markers within list: all `-` or all `*` (don't mix)
- Proper indentation for nested items (2 or 4 spaces, stay consistent)
- Blank line before/after list for clarity

### Links

- Inline: `[text](url)`
- Reference: `[text][ref]` then `[ref]: url` at bottom
- NO bare URLs without `<>` brackets
- Descriptive link text: "See the API reference" NOT "Click here"

### Emphasis

- Italic: `*text*` or `_text_`
- Bold: `**text**` or `__text__`
- Consistent style within document

---

## YAML Frontmatter

Use YAML frontmatter for major documents:

```yaml
---
title: "Document Title"
description: "Brief description"
date: YYYY-MM-DD
---
```

Frontmatter is an accepted CommonMark extension in this project.

---

## Style Guidelines

### Task-Oriented Focus

- Write for user GOALS, not feature lists
- Start with WHY, then HOW
- Every doc answers: "What can I accomplish?"

### Clarity Principles

- Active voice: "Click the button" NOT "The button should be clicked"
- Present tense: "The function returns" NOT "The function will return"
- Direct language: "Use X for Y" NOT "X can be used for Y"
- Second person: "You configure" NOT "Users configure"

### Structure

- One idea per sentence
- One topic per paragraph
- Headings describe content accurately
- Examples follow explanations

### Accessibility

- Descriptive link text
- Alt text for diagrams
- Semantic heading hierarchy (don't skip levels)
- Tables have headers

---

## Documentation Types

### README Files

- What (overview), Why (purpose), How (quick start)
- Under 500 lines (link to detailed docs)

### Architecture Docs

- System overview diagram
- Component descriptions
- Data flow
- Technology decisions (ADRs)

### Developer Guides

- Setup/environment requirements
- Code organization
- Development workflow
- Testing approach

### Templates

- Overview: when to use
- Step-by-step instructions with code examples
- Checklist for completion
- Reference files (links to implementations)
- Common mistakes to avoid

---

## Quality Checklist

Before finalizing any documentation:

- [ ] CommonMark compliant (no violations)
- [ ] NO time estimates anywhere
- [ ] Headers in proper hierarchy
- [ ] All code blocks have language tags
- [ ] Links work and have descriptive text
- [ ] Active voice, present tense
- [ ] Task-oriented (answers "how do I...")
- [ ] Examples are concrete and working
- [ ] Accessibility standards met
- [ ] Spelling/grammar checked

---

## Historical Documents

Planning documents in `docs/planning/archive/` may contain time estimates retained for historical reference. These documents include a notice:

> **Historical Document**
>
> This document was created during original planning and contains time estimates retained for historical reference.
