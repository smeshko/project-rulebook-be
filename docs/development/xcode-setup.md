---
title: "Xcode Setup"
description: "Xcode configuration for Vapor development"
author: Claude
date: 2026-01-23
---

# Xcode Development Setup

This guide helps you run the Vapor application directly from Xcode with the new PostgreSQL and Redis development setup.

## Prerequisites

Before running the application in Xcode, you **must** start the development database services:

```bash
# Start PostgreSQL and Redis services
docker-compose -f docker-compose.dev.yml up -d

# Verify services are running
docker-compose -f docker-compose.dev.yml ps
```

**Important**: The application now requires PostgreSQL and Redis for development, not just SQLite. These are provided via Docker Compose for production parity.

## Environment Variables Setup

The application automatically loads environment variables from the `.env` file, so no manual configuration is needed in Xcode.

### Automatic Loading
The application will automatically load your `.env` file when it starts, whether you run from:
- Xcode (with Docker services running)
- Command line (`swift run`)
- VS Code
- Docker

### Step 1: Start Development Services
Start the required PostgreSQL and Redis services:

```bash
docker-compose -f docker-compose.dev.yml up -d
```

### Step 2: Create Your .env File
Copy the example file and add your actual API keys:

```bash
cp .env.example .env
# Edit .env and add your actual API keys
```

The `.env.example` file now includes PostgreSQL and Redis configuration that matches the Docker services.

### Step 3: Set Working Directory (Optional)
1. In **Edit Scheme** → **Run** → **Options**
2. Check **Use custom working directory**
3. Set it to your project root directory (where Package.swift is located)

## Database Configuration

The application now uses PostgreSQL + Redis for development to maintain production parity:

- **PostgreSQL**: Primary database (Docker container: `project_rulebook_postgres_dev`)
- **Redis**: Caching layer (Docker container: `project_rulebook_redis_dev`)
- **Testing**: Still uses SQLite in-memory for fast test execution

The Docker services provide:
- PostgreSQL 15.4 with optimized development configuration
- Redis 7.2 with persistence and logging
- Automatic health checks and restart policies

## Common Issues & Solutions

### Issue: "Cannot connect to database"
**Solution:** Ensure Docker services are running:
```bash
docker-compose -f docker-compose.dev.yml up -d
docker-compose -f docker-compose.dev.yml ps  # Should show running services
```

### Issue: "Redis connection failed"
**Solution:** Verify Redis is accessible:
```bash
docker exec -it project_rulebook_redis_dev redis-cli ping
# Should respond with "PONG"
```

### Issue: "Configuration validation failed for JWT"
**Solution:** Ensure the `JWT_KEY` environment variable is set in your `.env` file

### Issue: "Application.shutdown() was not called"
**Solution:** This has been fixed in the entrypoint. The app now properly calls shutdown on exit.

### Issue: "Docker services won't start"
**Solution:** Check Docker daemon and service logs:
```bash
docker ps  # Check if Docker is running
docker-compose -f docker-compose.dev.yml logs postgres
docker-compose -f docker-compose.dev.yml logs redis
```

## Testing the Setup

1. Start Docker services: `docker-compose -f docker-compose.dev.yml up -d`
2. Set up environment variables as described above
3. Run the project from Xcode (⌘+R)
4. You should see logs indicating successful startup:
   ```
   [ INFO ] Configuration loaded for environment: development
   [ INFO ] Database host: localhost (PostgreSQL)
   [ INFO ] Redis host: localhost:6379
   [ INFO ] Services configured: Brevo, OpenAI, Redis Cache
   [ INFO ] Server starting on http://localhost:8080
   ```

## Alternative: Command Line Development

If you prefer command line development:
```bash
# Start development services
docker-compose -f docker-compose.dev.yml up -d

# Copy environment template
cp .env.example .env

# Run the application
swift run App serve
```

This approach automatically loads the `.env` file and doesn't require Xcode scheme configuration.

## Service Management

### Daily Development Workflow
```bash
# Start your development session
docker-compose -f docker-compose.dev.yml up -d

# Develop in Xcode...

# End your session (optional - containers will restart automatically)
docker-compose -f docker-compose.dev.yml down
```

### Database Management
```bash
# Reset database (removes all data)
docker-compose -f docker-compose.dev.yml down -v
docker-compose -f docker-compose.dev.yml up -d

# Access PostgreSQL directly
docker exec -it project_rulebook_postgres_dev psql -U vapor -d project_rulebook_dev

# Access Redis directly
docker exec -it project_rulebook_redis_dev redis-cli
```