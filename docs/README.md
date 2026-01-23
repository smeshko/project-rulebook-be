---
title: "Documentation Index"
description: "Central documentation hub for project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Project Rulebook Backend Documentation

Central hub for all project documentation.

## Quick Links

| Need to... | Go to |
|------------|-------|
| Create a new component | [templates/](templates/) |
| Understand the architecture | [architecture/](architecture/) |
| Set up development | [development/](development/) |
| Run tests | [testing/](testing/) |
| Find specific docs | [CONDITIONAL_DOCS.md](CONDITIONAL_DOCS.md) |

## Documentation Structure

```text
docs/
├── templates/          # Component creation guides
├── architecture/       # System design & ADRs
├── development/        # Setup & deployment
├── testing/            # Testing infrastructure
├── reference/          # API contracts, data models, external docs
├── product/            # Product requirements
└── planning/           # Work planning & archives
```

## For AI Agents

**Critical reading:**
- [architecture/technical-architecture.md](architecture/technical-architecture.md) - Architecture, patterns, and rules
- [CONDITIONAL_DOCS.md](CONDITIONAL_DOCS.md) - Find relevant docs by task
- [templates/README.md](templates/README.md) - Component creation guides

## For Developers

### Getting Started

1. Read [development/README.md](development/README.md) for setup
2. Understand [architecture/technical-architecture.md](architecture/technical-architecture.md)
3. Review [testing/README.md](testing/README.md) for test patterns

### Creating Components

Use the templates in [templates/](templates/) for:
- Services, Repositories, Migrations
- Controllers, Routers, Models
- Modules, Errors

### Making Changes

1. Check [CONDITIONAL_DOCS.md](CONDITIONAL_DOCS.md) for relevant docs
2. Follow patterns in existing code
3. Write tests using patterns in [testing/standards-and-patterns.md](testing/standards-and-patterns.md)

## Documentation Standards

All documentation follows [DOCUMENTATION_STANDARDS.md](DOCUMENTATION_STANDARDS.md):
- CommonMark compliance
- No time estimates
- Language tags on code blocks
- YAML frontmatter on major docs

## Project Overview

**Project Rulebook** is an AI-powered board game rules generation backend built with:
- **Swift 6.0** and **Vapor 4**
- **PostgreSQL** (production) / **SQLite** (testing)
- **Redis** for AI response caching
- **OpenAI** for game box recognition and rules generation

See [architecture/technical-architecture.md](architecture/technical-architecture.md) for details.
