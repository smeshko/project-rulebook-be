---
title: "Development Documentation"
description: "Setup and development guides for project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Development Documentation

Guides for setting up and working with the project.

## Contents

| Document | Description |
|----------|-------------|
| [getting-started.md](getting-started.md) | Initial setup and configuration |
| [deployment.md](deployment.md) | Deployment procedures and environments |
| [vscode-setup.md](vscode-setup.md) | VS Code configuration |
| [xcode-setup.md](xcode-setup.md) | Xcode configuration |

## Quick Start

1. Clone the repository
2. Run `swift build` to build the project
3. Start Docker services: `docker-compose up -d`
4. Run the server: `swift run App serve`

## Development Environment

### Prerequisites

- Swift 6.0+
- macOS 15+
- Docker (for PostgreSQL and Redis)
- Xcode 16+ (optional, for IDE)

### Environment Variables

Copy `.env.example` to `.env` and configure:

```text
DATABASE_URL=postgres://...
REDIS_URL=redis://...
OPENAI_API_KEY=sk-...
BREVO_API_KEY=...
```

## Build Commands

```bash
# Build
swift build

# Run
swift run App serve

# Test
swift test

# Clean
swift package clean
```

## Docker Services

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# Reset database
docker-compose down -v && docker-compose up -d
```

## IDE Setup

- **VS Code**: See [vscode-setup.md](vscode-setup.md)
- **Xcode**: See [xcode-setup.md](xcode-setup.md)
