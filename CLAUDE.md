# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Running
- **Build**: `swift build`
- **Run locally**: `swift run App serve --hostname 0.0.0.0 --port 8080`
- **Run tests**: `swift test`

### Docker Development
- **Build and run with Docker Compose**: `docker-compose up --build`
- **Run database only**: `docker-compose up db`

### Environment Setup
- Uses SQLite in memory for development and testing environments
- Uses PostgreSQL for staging and production (configured via environment variables)
- Requires `.env` file for database configuration in Docker setup

## Architecture Overview

This is a Vapor 4 Swift web application built using a modular architecture pattern.

### Core Framework Concepts
- **ModuleInterface**: All functionality is organized into modules that implement `ModuleInterface` protocol
- **Repository Pattern**: Data access is abstracted through repository interfaces in `Sources/App/Common/Framework/`
- **Service Layer**: External services (email, LLM, random generation) are abstracted through service interfaces

### Module Structure
The application is organized into four main modules:
- **UserModule**: User management and profile operations
- **AuthModule**: Authentication, JWT tokens, email verification, password reset
- **FrontendModule**: HTML rendering, forms, and web interface using SwiftHtml
- **RulesGenerationModule**: AI-powered game rules generation functionality

### Key Directories
- `Sources/App/Common/`: Shared utilities, extensions, framework interfaces, and middleware
- `Sources/App/Entities/`: Domain models and data structures
- `Sources/App/Modules/`: Feature modules with controllers, repositories, and routing
- `Sources/App/Services/`: External service integrations (Email/Brevo, LLM/OpenAI)
- `Tests/AppTests/`: Comprehensive test suite with mocks and test utilities

### Database & Persistence
- Uses Fluent ORM with SQLite (dev/test) and PostgreSQL (staging/prod)
- Database models are suffixed with `Model` (e.g., `UserAccountModel`)
- Auto-migration runs on application startup
- Repository pattern abstracts database operations

### Authentication & Security
- JWT-based authentication with access and refresh tokens
- App Attest integration for device verification
- Middleware-based authentication (`UserCredentialsAuthenticator`, `UserPayloadAuthenticator`)
- Email verification and password reset flows

### Frontend & Templates
- Server-side HTML rendering using SwiftHtml library
- Form handling with validation framework in `Frontend/Framework/Form/`
- Template system with context objects and reusable components
- CSS served from `Public/css/`

### External Integrations
- **Email**: Brevo email service for transactional emails
- **LLM**: OpenAI integration for rules generation
- **Database**: PostgreSQL for production, SQLite for development

### Testing Strategy
- Comprehensive test suite in `Tests/AppTests/`
- Mock implementations for all external services and repositories
- `TestWorld` class provides test environment setup
- XCTVapor used for HTTP endpoint testing

## Git Flow & Branching Strategy

### Branch Structure
- **`main`**: Production-ready code, highly protected
- **`staging`**: Integration branch for development work
- **`feature/*`**: New features (branch from staging)
- **`refactoring/*`**: Code improvements and architecture changes (branch from staging)
- **`bugfix/*`**: Bug fixes (branch from staging)
- **`hotfix/*`**: Critical production fixes (branch from main, merge to both main and staging)

### Workflow
1. Create feature branches from `staging`
2. Develop and test changes
3. Create PR to merge back to `staging`
4. After testing in staging, merge `staging` to `main` for production releases
5. For critical production issues, create `hotfix/*` from `main`

### Branch Naming Examples
- `feature/user-profile-api`
- `refactoring/controller-architecture`
- `bugfix/email-verification`
- `hotfix/security-patch`

### GitHub Branch Protection Recommendations
**Main Branch:**
- Require pull request reviews (2 reviewers)
- Require status checks to pass
- Restrict pushes and force pushes
- No direct commits allowed

**Staging Branch:**
- Require pull request reviews (1 reviewer)
- Require status checks to pass
- Allow administrator overrides for urgent fixes