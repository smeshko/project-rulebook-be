---
title: "Product Documentation"
description: "Product requirements and specifications for project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Product Documentation

Product requirements, specifications, and roadmap for Project Rulebook backend.

## Contents

| Document | Description |
|----------|-------------|
| [prd.md](prd.md) | Product Requirements Document - vision, success criteria, API specs, roadmap |

## Overview

Project Rulebook is an AI-powered board game rules generation backend. Key features:

- **Multi-Model AI Resilience**: Google Gemini primary, OpenAI fallback
- **Intelligent Caching**: 80% API cost reduction through response caching
- **Stateless Design**: Enables offline-first mobile clients
- **Enterprise Security**: Prompt injection protection, rate limiting

## Success Metrics

| Metric | Target |
|--------|--------|
| Uptime | 99.5% |
| Image Analysis P95 | <30s |
| Rules Generation P95 | <15s |
| Cache Hit Rate | >60% |

## API Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/api/v1/rules-generation/game-box-analysis` | Analyze game box image |
| `/api/v1/rules-generation/rules-summary` | Generate rules summary |

## Related Documentation

- [Architecture](../architecture/README.md) - System design and ADRs
- [Reference](../reference/README.md) - API contracts and data models
- [Development](../development/README.md) - Setup and deployment guides
