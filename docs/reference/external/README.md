---
title: "External Documentation"
description: "External API and service documentation"
author: Claude
date: 2026-01-23
---

# External Documentation

Documentation for external APIs and services used by the project.

## Contents

| File | Description | Source |
|------|-------------|--------|
| `open-ai-api.pdf` | OpenAI API reference | [OpenAI Documentation](https://platform.openai.com/docs) |
| `open-ai-api-1.pdf` | OpenAI API reference (additional) | [OpenAI Documentation](https://platform.openai.com/docs) |
| `open-ai-api-1.txt` | OpenAI API text reference | [OpenAI Documentation](https://platform.openai.com/docs) |
| `vapor-testing.pdf` | Vapor testing documentation | [Vapor Documentation](https://docs.vapor.codes) |
| `vapor-testing.txt` | Vapor testing text reference | [Vapor Documentation](https://docs.vapor.codes) |

## Usage

These documents are provided for offline reference. For the most up-to-date information, consult the original sources linked above.

## OpenAI Integration

The project uses OpenAI's Responses API for:
- Game box image analysis
- Rules summary generation

See `Sources/App/Services/LLM/` for implementation details.

## Vapor Testing

The project uses Vapor's testing framework with:
- XCTest integration
- Swift Testing support
- IsolatedTestWorld pattern

See `docs/testing/` for project-specific testing documentation.
