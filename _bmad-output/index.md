# Project Documentation Index - project-rulebook-be

**Generated:** 2026-01-19
**Workflow:** document-project v3.0.0
**Scan Mode:** Full | **Scan Level:** Deep

---

## Project Overview

| Attribute | Value |
|-----------|-------|
| **Project Name** | project-rulebook-be |
| **Type** | Monolith |
| **Primary Language** | Swift 6.0 |
| **Framework** | Vapor 4.115.1 |
| **Architecture** | Modular Monolith (Service-Oriented) |
| **Repository Type** | Single Codebase |

---

## Quick Reference

### Technology Stack

| Category | Technology |
|----------|------------|
| Language | Swift 6.0 |
| Framework | Vapor 4.115.1 |
| Database | PostgreSQL / SQLite |
| Cache | Redis |
| Auth | JWT |
| Container | Docker |
| Deployment | Railway |

### Entry Points

| File | Purpose |
|------|---------|
| `Sources/App/Entrypoint/entrypoint.swift` | Application main entry |
| `Sources/App/Entrypoint/configure.swift` | Route & middleware setup |
| `Package.swift` | SPM manifest |
| `Dockerfile` | Container build |

### Architecture Patterns

- **Modular Monolith** - Self-contained feature modules
- **Service Layer** - Cross-cutting shared services
- **Repository Pattern** - Data access abstraction
- **Middleware Pipeline** - Request/response processing

### Key Modules

| Module | Responsibility |
|--------|----------------|
| Auth | Authentication, JWT, email verification |
| User | User profiles, account management |
| RulesGeneration | AI image analysis, rules generation |
| Waitlist | Email subscription management |
| CacheAdmin | Cache monitoring and management |
| Frontend | HTML rendering, forms |

---

## Generated Documentation

### Core Documentation

| Document | Description | Status |
|----------|-------------|--------|
| [project-overview.md](./project-overview.md) | Executive summary and project overview | ✓ |
| [architecture.md](./architecture.md) | Comprehensive architecture documentation | ✓ |
| [api-contracts.md](./api-contracts.md) | API endpoint catalog with 22 endpoints | ✓ |
| [data-models.md](./data-models.md) | Database schema with 5 tables | ✓ |
| [source-tree-analysis.md](./source-tree-analysis.md) | Annotated directory structure | ✓ |

### Development & Operations

| Document | Description | Status |
|----------|-------------|--------|
| [development-guide.md](./development-guide.md) | Development setup and workflow | ✓ |
| [deployment-guide.md](./deployment-guide.md) | Deployment configuration and procedures | ✓ |

### State Files

| File | Description | Status |
|------|-------------|--------|
| [project-scan-report.json](./project-scan-report.json) | Workflow state and findings | ✓ |

---

## Existing Project Documentation

### Architecture

| Document | Location |
|----------|----------|
| Architectural Vision | `docs/architecture/architectural-vision.md` |
| Technical Architecture | `docs/architecture/technical-architecture.md` |
| Future Architecture Decisions | `docs/architecture/future-architecture-decisions.md` |

### Testing

| Document | Location |
|----------|----------|
| Testing Standards | `docs/testing/Testing-Standards-and-Patterns.md` |
| Testing Organization | `docs/testing/Testing-Organization-Summary.md` |
| Performance Tests | `docs/testing/Performance-Test-Suite-Summary.md` |
| Testing README | `docs/testing/README.md` |

### Development

| Document | Location |
|----------|----------|
| VS Code Setup | `docs/development/VSCODE_SETUP.md` |
| Xcode Setup | `docs/development/XCODE_SETUP.md` |
| Service Template | `docs/development/vapor-service-template.md` |

### Product

| Document | Location |
|----------|----------|
| PRD | `docs/product/prd.md` |
| Project Context | `docs/project-context.md` |

### Features

| Document | Location |
|----------|----------|
| API Versioning | `docs/features/api-versioning.md` |

### Other

| Document | Location |
|----------|----------|
| README | `README.md` |
| Docker README | `docker/README.md` |
| Conditional Docs | `docs/CONDITIONAL_DOCS.md` |

---

## Getting Started

### Quick Start

```bash
# 1. Clone and setup
git clone <repository-url>
cd project-rulebook-be
cp .env.example .env

# 2. Start development services
docker-compose -f docker-compose.dev.yml up -d

# 3. Build and run
swift build
swift run App serve --hostname 0.0.0.0 --port 8080

# 4. Verify
curl http://localhost:8080/health
```

### Test Admin Login

```bash
curl -X POST http://localhost:8080/api/v1/auth/sign-in \
  -H "Content-Type: application/json" \
  -d '{"email":"root@localhost.com","password":"ChangeMe1"}'
```

### Run Tests

```bash
swift test
```

---

## API Summary

| Category | Endpoints | Auth Required |
|----------|-----------|---------------|
| Authentication | 6 | Mixed |
| User Management | 4 | Yes |
| Rules Generation | 2 | No |
| Waitlist | 4 | Mixed |
| Cache Admin | 6 | Admin |
| System | 1 | No |
| **Total** | **23** | - |

---

## Documentation Statistics

| Metric | Count |
|--------|-------|
| Generated Documents | 8 |
| Existing Documents | 15 |
| API Endpoints Documented | 22 |
| Database Tables Documented | 5 |
| Directories Analyzed | ~100 |

---

## Navigation Tips for AI Assistants

When working with this codebase:

1. **Start here** - Use this index as the entry point
2. **Architecture questions** - Refer to `architecture.md`
3. **API development** - See `api-contracts.md` for endpoint patterns
4. **Database changes** - Check `data-models.md` for schema
5. **Development workflow** - Follow `development-guide.md`
6. **Deployment** - See `deployment-guide.md`

### Key Locations

- **Source code:** `Sources/App/`
- **Tests:** `Tests/AppTests/`
- **Configuration:** `.env`, `Package.swift`
- **Docker:** `Dockerfile`, `docker-compose*.yml`
- **Documentation:** `docs/`, `_bmad-output/`

---

*This index was auto-generated by the document-project workflow for AI-assisted development.*
