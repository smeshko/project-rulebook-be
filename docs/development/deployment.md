---
title: "Deployment Guide"
description: "Deployment procedures for project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Deployment Guide - project-rulebook-be

**Generated:** 2026-01-19
**Platform:** Railway (primary), Docker (containerized)

---

## Deployment Options

### 1. Railway (Recommended)

The project includes Railway configuration for streamlined deployment.

**Configuration File:** `railway.toml`

```toml
[build]
builder = "DOCKERFILE"
dockerfile = "Dockerfile"

[deploy]
startCommand = "./App serve --hostname 0.0.0.0"
healthcheckPath = "/health"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

[environment]
PORT = "8080"
```

**Deployment Steps:**
1. Connect your GitHub repository to Railway
2. Set environment variables in Railway dashboard
3. Railway automatically builds and deploys on push

### 2. Docker

**Build and Run:**

```bash
# Build production image
docker build -t project-rulebook-be .

# Run container
docker run -p 8080:8080 \
  -e DATABASE_HOST=your-db-host \
  -e DATABASE_NAME=your-db-name \
  -e DATABASE_USERNAME=your-db-user \
  -e DATABASE_PASSWORD=your-db-password \
  -e REDIS_HOST=your-redis-host \
  -e JWT_KEY=your-jwt-secret \
  project-rulebook-be
```

### 3. Docker Compose (Production)

**File:** `docker-compose.yml`

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f app
```

---

## Dockerfile Overview

```dockerfile
# Multi-stage build
FROM swift:6.0-jammy as build
# Build with optimizations
RUN swift build -c release --static-swift-stdlib

FROM swift:6.0-jammy-slim
# Production-ready minimal image
USER vapor:vapor
CMD ["./App", "serve", "--hostname", "0.0.0.0"]
```

**Key Features:**
- Multi-stage build for minimal image size
- Static Swift stdlib for portability
- Non-root user for security
- Automatic PORT detection from environment

---

## Environment Configuration

### Production Environment Variables

```bash
# Core Configuration
ENVIRONMENT=production
BASE_URL=https://your-domain.com
APPLICATION_IDENTIFIER=com.yourcompany.app
JWT_KEY=<strong_secret_minimum_32_characters>

# Database (PostgreSQL with TLS)
DATABASE_HOST=your-postgres-host.com
DATABASE_NAME=project_rulebook_prod
DATABASE_USERNAME=postgres_user
DATABASE_PASSWORD=strong_password
DATABASE_PORT=5432

# Redis Cache (with TLS)
REDIS_HOST=your-redis-host.com
REDIS_PORT=6379
REDIS_PASSWORD=redis_password
REDIS_DATABASE=0
REDIS_POOL_SIZE=10

# AI Services
OPENAI_KEY=sk-your-production-key
# OR
GEMINI_API_KEY=your-gemini-key

# Email Service
BREVO_API_KEY=your-brevo-key
BREVO_URL=https://api.brevo.com

# Cache Settings (production optimized)
CACHE_MAX_ENTRIES=5000
CACHE_RULES_TTL=7200
CACHE_IMAGE_TTL=3600
CACHE_CLEANUP_INTERVAL=1800

# Rate Limiting (production)
RATE_LIMIT_IMAGE_ANALYSIS=3
RATE_LIMIT_RULES_GENERATION=10
RATE_LIMIT_API_GENERAL=100

# CORS (production domains only)
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
```

---

## Health Checks

### Endpoint

```
GET /health
```

**Response:**
```json
{"status": "healthy"}
```

### Railway Health Check

- Path: `/health`
- Timeout: 300 seconds
- Restart on failure: Yes (max 10 retries)

---

## Database Migration

Migrations run automatically on application startup. No manual migration commands needed.

### Production Database Setup

1. Create PostgreSQL database
2. Set connection environment variables
3. Deploy application (migrations run automatically)

---

## Security Checklist

### Pre-Deployment

- [ ] Change default admin password
- [ ] Generate strong JWT_KEY (32+ characters)
- [ ] Configure CORS for production domains only
- [ ] Set appropriate rate limits
- [ ] Enable TLS for database connections
- [ ] Enable TLS for Redis connections
- [ ] Review security headers configuration

### Environment Variables

- [ ] Never commit secrets to repository
- [ ] Use Railway/platform secret management
- [ ] Rotate API keys periodically
- [ ] Use different keys for staging/production

---

## Environments

| Environment | Database | Cache | Security | Logging |
|-------------|----------|-------|----------|---------|
| Development | PostgreSQL (Docker) | Redis (Docker) | Relaxed CORS | Verbose |
| Testing | SQLite (memory) | Mock | None | Minimal |
| Staging | PostgreSQL + TLS | Redis + TLS | Production-like | Comprehensive |
| Production | PostgreSQL + TLS | Redis + TLS | Strict | Structured JSON |

---

## Scaling Considerations

### Application

- Stateless design supports horizontal scaling
- Session state stored in Redis
- Database connection pooling configured

### Database

- PostgreSQL connection pooling (default: 10 connections)
- Consider read replicas for high read loads

### Cache

- Redis handles high throughput
- Configure Redis cluster for high availability
- Adjust `REDIS_POOL_SIZE` based on load

---

## Monitoring

### Application Logs

- Structured JSON logging in production
- Correlation IDs for request tracing
- Security event tracking

### Health Endpoints

| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /health` | None | Basic health check |
| `GET /api/admin/cache/health` | Admin | Cache health status |
| `GET /api/admin/cache/stats` | Admin | Cache statistics |

---

## Rollback Procedure

### Railway

1. Go to Railway dashboard
2. Select deployment
3. Click "Rollback" to previous version

### Docker

```bash
# Tag current version before update
docker tag project-rulebook-be:latest project-rulebook-be:previous

# Rollback if needed
docker stop project-rulebook-container
docker run project-rulebook-be:previous
```

---

## Troubleshooting

### Application Won't Start

```bash
# Check container logs
docker logs <container-id>

# Verify environment variables
docker exec <container-id> env

# Test health endpoint
curl https://your-domain.com/health
```

### Database Connection Issues

```bash
# Test PostgreSQL connectivity
psql -h your-host -U your-user -d your-db

# Check connection string format
# DATABASE_HOST, DATABASE_PORT, DATABASE_NAME, DATABASE_USERNAME, DATABASE_PASSWORD
```

### Redis Connection Issues

```bash
# Test Redis connectivity
redis-cli -h your-host -p 6379 ping

# Verify Redis environment variables
# REDIS_HOST, REDIS_PORT, REDIS_PASSWORD
```

---

## CI/CD Integration

The project supports CI/CD integration:

- **Railway**: Auto-deploy on push to configured branch
- **GitHub Actions**: `.github/workflows/` (if configured)
- **Docker Hub**: Push images for container deployments

---

## Support

For deployment issues:
1. Check application logs
2. Verify all environment variables are set
3. Test health endpoint
4. Review Railway/platform dashboard for errors
