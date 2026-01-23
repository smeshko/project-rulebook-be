---
title: "Getting Started"
description: "Development setup guide for project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Development Guide - project-rulebook-be

**Generated:** 2026-01-19
**Project:** Swift/Vapor 4 Backend

---

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Swift | 6.0+ | swift-tools-version:6.0 |
| Xcode | 16+ | Required for macOS development |
| Docker | Latest | For PostgreSQL/Redis services |
| Docker Compose | Latest | For development environment |
| macOS | 15+ | Target platform |

---

## Quick Start

### 1. Clone and Setup

```bash
# Clone repository
git clone <repository-url>
cd project-rulebook-be

# Copy environment configuration
cp .env.example .env
# Edit .env with your API keys (OPENAI_KEY or GEMINI_API_KEY)
```

### 2. Start Development Services

```bash
# Start PostgreSQL and Redis
docker-compose -f docker-compose.dev.yml up -d

# Verify services are running
docker-compose -f docker-compose.dev.yml ps
```

### 3. Build and Run

```bash
# Build the project
swift build

# Run the application
swift run App serve --hostname 0.0.0.0 --port 8080
```

### 4. Verify Installation

```bash
# Health check
curl http://localhost:8080/health

# Should return: {"status":"healthy"}
```

---

## Environment Configuration

### Required Variables

```bash
# Database (PostgreSQL)
DATABASE_HOST=localhost
DATABASE_NAME=project_rulebook_dev
DATABASE_USERNAME=vapor
DATABASE_PASSWORD=password
DATABASE_PORT=5432

# Redis Cache
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DATABASE=0
REDIS_POOL_SIZE=5

# Security
JWT_KEY=<minimum_32_characters_secret>
BASE_URL=http://localhost:8080
APPLICATION_IDENTIFIER=com.yourcompany.app

# AI Services (choose one)
OPENAI_KEY=<your_openai_key>
GEMINI_API_KEY=<your_gemini_key>

# Email Service
BREVO_API_KEY=<your_brevo_key>
BREVO_URL=https://api.brevo.com
```

### Optional Variables

```bash
# Cache Configuration
CACHE_MAX_ENTRIES=1000
CACHE_RULES_TTL=3600
CACHE_CLEANUP_INTERVAL=600

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000
```

---

## Build Commands

| Command | Description |
|---------|-------------|
| `swift build` | Build debug version |
| `swift build -c release` | Build release version |
| `swift run App serve` | Run application |
| `swift test` | Run all tests |
| `swift test --filter <TestName>` | Run specific tests |
| `swift package resolve` | Resolve dependencies |
| `swift package update` | Update dependencies |

---

## Testing

### Run Tests

```bash
# All tests
swift test

# Specific test categories
swift test --filter AuthenticationTests
swift test --filter SecurityTests
swift test --filter AISecurityTests
swift test --filter PerformanceTests
```

### Test Infrastructure

- **IntegrationTestCase**: HTTP endpoint testing
- **UnitTestCase**: Service and business logic
- **PerformanceTestCase**: Benchmarking

### Test Environment

Tests use SQLite in-memory database with mocked external services.

---

## Database Management

### Development Commands

```bash
# Start services
docker-compose -f docker-compose.dev.yml up -d

# Stop services
docker-compose -f docker-compose.dev.yml down

# Reset database (removes all data)
docker-compose -f docker-compose.dev.yml down -v
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f postgres
docker-compose -f docker-compose.dev.yml logs -f redis
```

### Database Connection

```bash
# Connect to PostgreSQL
docker exec -it project_rulebook_postgres_dev psql -U vapor -d project_rulebook_dev

# Test Redis
docker exec -it project_rulebook_redis_dev redis-cli ping
```

### Migrations

Migrations run automatically on application startup. The system uses Fluent ORM with versioned migrations.

---

## IDE Setup

### Xcode

See `docs/development/xcode-setup.md` for detailed setup instructions.

Key steps:
1. Open `Package.swift` in Xcode
2. Wait for dependencies to resolve
3. Select the `App` scheme
4. Set working directory to project root in scheme settings

### VS Code

See `docs/development/vscode-setup.md` for detailed setup instructions.

Recommended extensions:
- Swift (Swift Server Work Group)
- Swift Snippets
- Docker

---

## Default Admin User

On first run, a default admin user is created:

| Field | Value |
|-------|-------|
| Email | `root@localhost.com` |
| Password | `ChangeMe1` |
| Role | Admin |

**Change this password immediately in non-development environments!**

---

## Common Issues

### Database Connection Failed

```bash
# Check if PostgreSQL is running
docker-compose -f docker-compose.dev.yml ps

# View PostgreSQL logs
docker-compose -f docker-compose.dev.yml logs postgres
```

### Redis Connection Failed

```bash
# Check if Redis is running
docker-compose -f docker-compose.dev.yml ps

# Test Redis connection
docker exec -it project_rulebook_redis_dev redis-cli ping
```

### JWT Errors

```bash
# JWT_KEY must be at least 32 characters
echo $JWT_KEY | wc -c
```

### Port Already in Use

```bash
# Find process using port 8080
lsof -i :8080

# Kill the process or use a different port
swift run App serve --port 8081
```

---

## Project Structure

```text
Sources/App/
├── Entrypoint/      # Application entry point
├── Modules/         # Feature modules
│   ├── Auth/        # Authentication
│   ├── User/        # User management
│   ├── RulesGeneration/  # Core AI feature
│   ├── Waitlist/    # Email waitlist
│   ├── CacheAdmin/  # Admin cache management
│   └── Frontend/    # HTML rendering
├── Services/        # Shared services
├── Common/          # Cross-cutting concerns
├── Middlewares/     # HTTP middleware
├── Extensions/      # Swift extensions
├── Errors/          # Error handling
└── Entities/        # Domain entities
```

---

## Additional Resources

- `docs/development/vscode-setup.md` - VS Code configuration
- `docs/development/xcode-setup.md` - Xcode configuration
- `docs/templates/` - Component creation templates
- `docs/testing/` - Testing documentation
- `docs/architecture/` - Architecture documentation
