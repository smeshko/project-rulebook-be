---
title: "Templates Index"
description: "AI-focused creation guides for project-rulebook-be components"
author: Claude
date: 2026-01-23
---

# Templates

Focused templates for creating components correctly in project-rulebook-be.

## Template Index

| Template | When to Use |
|----------|-------------|
| [controller-creation.md](controller-creation.md) | Creating HTTP endpoint handlers with business logic |
| [router-creation.md](router-creation.md) | Defining routes, middleware, and OpenAPI documentation |
| [service-creation.md](service-creation.md) | External API integrations or shared functionality |
| [repository-creation.md](repository-creation.md) | Database access abstraction layer |
| [model-creation.md](model-creation.md) | Database entities (Fluent models) and DTOs |
| [migration-creation.md](migration-creation.md) | Database schema changes |
| [module-creation.md](module-creation.md) | New feature domain with full structure |
| [error-creation.md](error-creation.md) | Custom error types for API responses |

## Usage Instructions

1. **Identify** what component you need from the index above
2. **Read** the template's "When to Use" section to confirm it's right
3. **Copy** the code template and replace placeholders
4. **Verify** against the checklist at the end of each template
5. **Reference** the codebase examples for real implementations

## Placeholder Reference

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{Module}` | Module name (PascalCase) | `Auth`, `User`, `RulesGeneration` |
| `{module}` | Module name (camelCase) | `auth`, `user`, `rulesGeneration` |
| `{module-slug}` | URL path segment (kebab-case) | `auth`, `rules-generation` |
| `{Entity}` | Entity name (PascalCase) | `RefreshToken`, `UserAccount` |
| `{entity}` | Entity name (camelCase) | `refreshToken`, `userAccount` |
| `{Name}` | Component name (PascalCase) | `Cache`, `LLM` |
| `{name}` | Component name (camelCase) | `cache`, `llm` |
| `{Service}` | Service name (PascalCase) | `Email`, `LLM`, `Cache` |
| `{table_name}` | Database table (snake_case, plural) | `users`, `refresh_tokens` |

## Component Relationships

```text
Module
├── Router (routes → middleware → controller)
├── Controller (request handling, business logic)
├── Repository (data access)
├── Models/ (DTOs for request/response)
└── Database/
    ├── Models/ (Fluent entities)
    └── Migrations/ (schema changes)
```

## Directory Structure

```text
Sources/App/
├── Modules/
│   └── {Module}/
│       ├── {Module}Module.swift
│       ├── {Module}Router.swift
│       ├── Controllers/
│       │   └── {Module}Controller.swift
│       ├── Repositories/
│       │   └── {Entity}Repository.swift
│       ├── Models/
│       │   └── {Feature}.swift (DTOs)
│       └── Database/
│           ├── Models/
│           │   └── {Entity}Model.swift
│           └── Migrations/
│               └── {Module}Migrations.swift
├── Services/
│   └── {ServiceName}/
│       ├── {ServiceName}Service.swift
│       └── {ServiceName}ServiceInterface.swift (if protocol separate)
├── Entities/
│   └── Errors/
│       └── {Domain}Error.swift
└── Common/
    ├── Extensions/
    │   ├── Application+Services.swift
    │   └── Request+Services.swift
    └── Framework/
        └── Repository.swift
```

## File Naming Conventions

| Component | Pattern | Example |
|-----------|---------|---------|
| Module | `{Module}Module.swift` | `AuthModule.swift` |
| Router | `{Module}Router.swift` | `AuthRouter.swift` |
| Controller | `{Module}Controller.swift` | `AuthController.swift` |
| Repository | `{Entity}Repository.swift` | `RefreshTokenRepository.swift` |
| Migration | `{Module}Migrations.swift` | `AuthMigrations.swift` |
| Database Model | `{Entity}Model.swift` | `RefreshTokenModel.swift` |
| Error | `{Domain}Error.swift` | `AuthenticationError.swift` |
| Service | `{Service}Service.swift` | `LLMService.swift` |

## Before You Start

Read [architecture/technical-architecture.md](../architecture/technical-architecture.md) for critical rules that apply to all components.

## Codebase Examples

| Component | Reference Implementation |
|-----------|-------------------------|
| Full Module | `Sources/App/Modules/Auth/` |
| Controller | `Sources/App/Modules/Auth/Controllers/AuthController.swift` |
| Router | `Sources/App/Modules/Auth/AuthRouter.swift` |
| Repository | `Sources/App/Modules/Auth/Repositories/RefreshTokenRepository.swift` |
| Migration | `Sources/App/Modules/Auth/Database/Migrations/AuthMigrations.swift` |
| Model | `Sources/App/Modules/Auth/Database/Models/RefreshTokenModel.swift` |
| Service | `Sources/App/Services/LLM/LLMService.swift` |
| Error | `Sources/App/Entities/Errors/AuthenticationError.swift` |

## Related Documentation

- [Architecture](../architecture/README.md) - System design and ADRs
- [Development](../development/README.md) - Setup and deployment guides
- [Testing](../testing/README.md) - Testing infrastructure and patterns
