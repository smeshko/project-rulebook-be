# Docker Development Guide

## Overview

This guide covers the PostgreSQL and Redis Docker setup for local development. The development environment now uses production-grade databases instead of SQLite to ensure production parity and catch database-related issues early.

## Architecture Changes

### Before (Legacy Setup)
- **Development**: SQLite in-memory 
- **Testing**: SQLite in-memory
- **Production**: PostgreSQL

### After (Current Setup)
- **Development**: PostgreSQL 15.4 + Redis 7.2 (via Docker)
- **Testing**: SQLite in-memory (for speed)
- **Production**: PostgreSQL + Redis (with TLS)

## Prerequisites

### Required Software
- **Docker Desktop 4.0+**: For container management
- **Docker Compose 2.0+**: For multi-service orchestration  
- **Swift 5.9+**: For application development
- **Xcode 15+**: For iOS development (optional)

### Installation
```bash
# macOS with Homebrew
brew install --cask docker
brew install docker-compose

# Verify installation
docker --version
docker-compose --version
```

## Quick Start

### 1. Clone and Setup
```bash
git clone <repository-url>
cd project-rulebook

# Copy environment configuration
cp .env.example .env
# Edit .env with your API keys
```

### 2. Start Development Services
```bash
# Start PostgreSQL and Redis
docker-compose -f docker-compose.dev.yml up -d

# Verify services are running
docker-compose -f docker-compose.dev.yml ps
```

### 3. Run the Application
```bash
# Build and run
swift build
swift run App serve --hostname 0.0.0.0 --port 8080
```

## Docker Services

### PostgreSQL Service

**Container**: `project_rulebook_postgres_dev`  
**Image**: `postgres:15.4-alpine`  
**Port**: `5432` → `localhost:5432`

#### Configuration
- **User**: `vapor`  
- **Password**: `password`  
- **Database**: `project_rulebook_dev`
- **Data Volume**: `postgres_dev_data` (persistent)
- **Memory Limit**: 512MB (limit), 256MB (reservation)

#### Features
- UTF-8 encoding with C locale for performance
- Health checks every 10 seconds
- Automatic restart on failure
- Optimized for development workloads

### Redis Service

**Container**: `project_rulebook_redis_dev`  
**Image**: `redis:7.2-alpine`  
**Port**: `6379` → `localhost:6379`

#### Configuration
- **Authentication**: None (development only)
- **Database**: `0` (default)
- **Data Volume**: `redis_dev_data` (persistent)
- **Memory Limit**: 256MB (limit), 128MB (reservation)

#### Features
- Persistence enabled for cache durability
- Health checks with ping/pong
- Custom configuration via `docker/redis/redis.conf`
- Logging enabled for debugging

## Environment Configuration

### Required Environment Variables

The application loads these from your `.env` file:

```bash
# Database Configuration
DATABASE_HOST=localhost
DATABASE_NAME=project_rulebook_dev
DATABASE_USERNAME=vapor
DATABASE_PASSWORD=password
DATABASE_PORT=5432

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DATABASE=0
REDIS_POOL_SIZE=5
REDIS_CONNECTION_TIMEOUT=5.0
REDIS_COMMAND_TIMEOUT=10.0
REDIS_ENABLE_LOGGING=true
```

### Automatic Environment Detection

The application automatically detects the environment:
- **Development**: Uses Docker PostgreSQL + Redis
- **Testing**: Uses SQLite in-memory (no Docker required)
- **Production**: Uses production PostgreSQL + Redis with TLS

## Service Management

### Starting Services
```bash
# Start all development services
docker-compose -f docker-compose.dev.yml up -d

# Start only PostgreSQL
docker-compose -f docker-compose.dev.yml up -d postgres

# Start only Redis  
docker-compose -f docker-compose.dev.yml up -d redis
```

### Stopping Services
```bash
# Stop all services (keeps data)
docker-compose -f docker-compose.dev.yml down

# Stop and remove volumes (deletes data)
docker-compose -f docker-compose.dev.yml down -v
```

### Service Status
```bash
# Check service status
docker-compose -f docker-compose.dev.yml ps

# View service logs
docker-compose -f docker-compose.dev.yml logs -f postgres
docker-compose -f docker-compose.dev.yml logs -f redis

# Follow logs for all services
docker-compose -f docker-compose.dev.yml logs -f
```

### Restarting Services
```bash
# Restart all services
docker-compose -f docker-compose.dev.yml restart

# Restart specific service
docker-compose -f docker-compose.dev.yml restart postgres
docker-compose -f docker-compose.dev.yml restart redis
```

## Database Operations

### PostgreSQL Access

#### Command Line Access
```bash
# Connect to PostgreSQL
docker exec -it project_rulebook_postgres_dev psql -U vapor -d project_rulebook_dev

# Run single command
docker exec -it project_rulebook_postgres_dev psql -U vapor -d project_rulebook_dev -c "SELECT version();"
```

#### Common PostgreSQL Commands
```sql
-- List all tables
\dt

-- Describe a table
\d user_accounts

-- Show database size
SELECT pg_size_pretty(pg_database_size('project_rulebook_dev'));

-- Show active connections
SELECT * FROM pg_stat_activity WHERE datname = 'project_rulebook_dev';

-- Exit
\q
```

#### Database Reset
```bash
# Complete reset (deletes all data)
docker-compose -f docker-compose.dev.yml down -v
docker-compose -f docker-compose.dev.yml up -d postgres

# Wait for health check
docker-compose -f docker-compose.dev.yml ps
```

### Redis Access

#### Command Line Access
```bash
# Connect to Redis CLI
docker exec -it project_rulebook_redis_dev redis-cli

# Test connection
docker exec -it project_rulebook_redis_dev redis-cli ping
```

#### Common Redis Commands
```bash
# Inside Redis CLI
redis-cli

# Check info
INFO

# List all keys
KEYS *

# Get cache statistics
INFO stats

# Clear all cache
FLUSHDB

# Exit
EXIT
```

#### Redis Monitoring
```bash
# Monitor Redis commands in real-time
docker exec -it project_rulebook_redis_dev redis-cli MONITOR

# Check memory usage
docker exec -it project_rulebook_redis_dev redis-cli INFO memory
```

## Data Persistence

### Development Data Volumes

Both services use Docker named volumes for data persistence:

```bash
# List volumes
docker volume ls | grep project_rulebook

# Inspect volume
docker volume inspect project_rulebook_postgres_dev_data
docker volume inspect project_rulebook_redis_dev_data

# Remove volumes (deletes all data)
docker volume rm project_rulebook_postgres_dev_data
docker volume rm project_rulebook_redis_dev_data
```

### Backup and Restore

#### PostgreSQL Backup
```bash
# Create backup
docker exec -it project_rulebook_postgres_dev pg_dump -U vapor project_rulebook_dev > backup.sql

# Restore backup
docker exec -i project_rulebook_postgres_dev psql -U vapor project_rulebook_dev < backup.sql
```

#### Redis Backup
```bash
# Create Redis snapshot
docker exec -it project_rulebook_redis_dev redis-cli BGSAVE

# Copy snapshot from container
docker cp project_rulebook_redis_dev:/data/dump.rdb ./redis_backup.rdb
```

## Performance Tuning

### PostgreSQL Configuration

The PostgreSQL container is optimized for development:

```yaml
# Resource limits
deploy:
  resources:
    limits:
      memory: 512M
    reservations:
      memory: 256M

# Performance settings
POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
```

### Redis Configuration

Redis uses a custom configuration file at `docker/redis/redis.conf`:

```redis
# Memory optimization
maxmemory 200mb
maxmemory-policy allkeys-lru

# Persistence settings
save 900 1
save 300 10
save 60 10000

# Logging
loglevel notice
logfile /data/redis.log
```

## Networking

### Service Communication

Services communicate via the `dev_network` bridge network:

```yaml
networks:
  dev_network:
    driver: bridge
```

### Port Mapping

| Service | Container Port | Host Port | Purpose |
|---------|---------------|-----------|---------|
| PostgreSQL | 5432 | 5432 | Database connections |
| Redis | 6379 | 6379 | Cache connections |

### Host Access

Both services are accessible from the host machine:
- **PostgreSQL**: `localhost:5432`
- **Redis**: `localhost:6379`

## Development Workflow

### Daily Workflow

```bash
# 1. Start development session
docker-compose -f docker-compose.dev.yml up -d

# 2. Verify services are healthy
docker-compose -f docker-compose.dev.yml ps

# 3. Start development
swift run App serve

# 4. Develop your features...

# 5. Run tests (uses SQLite in-memory)
swift test

# 6. End session (optional - containers auto-restart)
docker-compose -f docker-compose.dev.yml down
```

### Migration Workflow

When adding new database migrations:

```bash
# 1. Start services
docker-compose -f docker-compose.dev.yml up -d

# 2. Run application (migrations run automatically)
swift run App serve

# 3. Verify migration in PostgreSQL
docker exec -it project_rulebook_postgres_dev psql -U vapor -d project_rulebook_dev -c "\dt"
```

### Testing Workflow

```bash
# Tests use SQLite in-memory (no Docker needed)
swift test

# For integration tests with real database
ENVIRONMENT=development swift test
```

## Troubleshooting

### Service Issues

#### Services Won't Start
```bash
# Check Docker daemon
docker ps

# Check service logs
docker-compose -f docker-compose.dev.yml logs postgres
docker-compose -f docker-compose.dev.yml logs redis

# Restart Docker Desktop if needed
```

#### Health Check Failures
```bash
# Check health status
docker-compose -f docker-compose.dev.yml ps

# Services showing "unhealthy":
docker-compose -f docker-compose.dev.yml restart <service-name>

# View detailed health check logs
docker inspect project_rulebook_postgres_dev
docker inspect project_rulebook_redis_dev
```

### Connection Issues

#### Cannot Connect to PostgreSQL
```bash
# Test connection from host
nc -zv localhost 5432

# Test from within container
docker exec -it project_rulebook_postgres_dev pg_isready -U vapor

# Check application logs
swift run App serve  # Look for database connection errors
```

#### Cannot Connect to Redis
```bash
# Test Redis connection
docker exec -it project_rulebook_redis_dev redis-cli ping

# Should respond with "PONG"

# Test from host
redis-cli -h localhost -p 6379 ping
```

### Performance Issues

#### High Memory Usage
```bash
# Check container resource usage
docker stats project_rulebook_postgres_dev project_rulebook_redis_dev

# Restart containers if needed
docker-compose -f docker-compose.dev.yml restart
```

#### Slow Database Queries
```bash
# Enable PostgreSQL query logging
docker exec -it project_rulebook_postgres_dev psql -U vapor -d project_rulebook_dev -c "ALTER SYSTEM SET log_statement = 'all';"
docker-compose -f docker-compose.dev.yml restart postgres

# View query logs
docker-compose -f docker-compose.dev.yml logs -f postgres
```

### Data Issues

#### Corrupted Data
```bash
# Reset all data (nuclear option)
docker-compose -f docker-compose.dev.yml down -v
docker-compose -f docker-compose.dev.yml up -d

# Wait for health checks
docker-compose -f docker-compose.dev.yml ps
```

#### Database Schema Issues
```bash
# Check migration status
swift run App migrate --dry-run

# Revert and re-run migrations
swift run App migrate --revert
swift run App migrate
```

## IDE Integration

### VS Code Integration
- See [VS Code Setup Guide](VSCODE_SETUP.md) for complete configuration
- Environment variables automatically configured
- Tasks include Docker service checks

### Xcode Integration  
- See [Xcode Setup Guide](XCODE_SETUP.md) for complete configuration
- Requires manual Docker service startup
- Environment loaded from `.env` file

## Production Considerations

### Differences from Production

| Aspect | Development | Production |
|--------|-------------|------------|
| Security | No password/TLS | Strong passwords + TLS |
| Persistence | Local volumes | Cloud storage |
| Backup | Manual snapshots | Automated backups |
| Monitoring | Basic logs | Full observability |
| Scaling | Single instance | Multi-instance clusters |

### Migration Path

To deploy to production:
1. Use production-grade database hosting (AWS RDS, Google Cloud SQL)
2. Enable TLS/SSL connections
3. Configure proper backup strategies
4. Implement monitoring and alerting
5. Use managed Redis (AWS ElastiCache, Redis Cloud)

## Advanced Configuration

### Custom PostgreSQL Configuration

Create `docker/postgres/postgresql.conf`:
```postgresql
# Custom settings
shared_preload_libraries = 'pg_stat_statements'
max_connections = 100
shared_buffers = 128MB
```

Mount in `docker-compose.dev.yml`:
```yaml
volumes:
  - ./docker/postgres/postgresql.conf:/etc/postgresql/postgresql.conf
```

### Custom Redis Configuration

Edit `docker/redis/redis.conf`:
```redis
# Custom cache policies
maxmemory-policy allkeys-lru
maxmemory 512mb

# Enable key expiration notifications
notify-keyspace-events Ex
```

### Multi-Environment Setup

Create environment-specific compose files:
- `docker-compose.dev.yml` - Development
- `docker-compose.test.yml` - Integration testing
- `docker-compose.staging.yml` - Staging environment

## Next Steps

1. **Read the complete setup guides**:
   - [VS Code Setup](VSCODE_SETUP.md)
   - [Xcode Setup](XCODE_SETUP.md)

2. **Explore the architecture**:
   - [Project Architecture Overview](../architecture/Project-Architecture-Overview.md)
   - [Clean Architecture Developer Guide](Clean-Architecture-Developer-Guide.md)

3. **Learn about testing**:
   - [Testing Standards and Patterns](../testing/Testing-Standards-and-Patterns.md)

4. **Deploy to production**:
   - [Deployment Guide](../documentation/Deployment-Guide.md)