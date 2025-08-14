# Docker Development Environment

This directory contains Docker configurations for local development.

## Files

- `docker-compose.dev.yml` - Development services (PostgreSQL + Redis)
- `redis/redis.conf` - Redis configuration optimized for development
- `postgres/init/01-init-dev.sql` - PostgreSQL initialization script

## Usage

### Start Development Services

```bash
# Start PostgreSQL and Redis services
docker-compose -f docker-compose.dev.yml up -d

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Stop services
docker-compose -f docker-compose.dev.yml down
```

### Clean Up Development Data

```bash
# Stop services and remove volumes (WARNING: This will delete all data)
docker-compose -f docker-compose.dev.yml down -v
```

## Service Information

### PostgreSQL
- **Host:** localhost
- **Port:** 5432 (configurable via DATABASE_PORT in .env)
- **Database:** project_rulebook_dev (configurable via DATABASE_NAME in .env)
- **Username:** vapor (configurable via DATABASE_USERNAME in .env)
- **Password:** password (configurable via DATABASE_PASSWORD in .env)
- **Data Volume:** db_data_dev

### Redis
- **Host:** localhost  
- **Port:** 6379
- **Data Volume:** redis_data_dev
- **Memory Limit:** 256MB (development optimized)
- **Configuration:** See `redis/redis.conf`

## Health Checks

Both services include health checks:
- PostgreSQL: Checks connection with pg_isready
- Redis: Checks with redis-cli ping

Services will show as "healthy" when ready to accept connections.

## Configuration

Services use environment variables from `.env` file. See `.env.example` for required variables.

## Development Tips

1. Services restart automatically unless manually stopped
2. Data persists between container restarts via named volumes
3. Logs are limited to 10MB with 3 file rotation for development
4. Redis is configured for development speed over durability
5. PostgreSQL includes development-optimized performance settings