# Comprehensive Deployment & Troubleshooting Guide

This guide provides complete instructions for deploying Project Rulebook in various environments, from development to production, including troubleshooting common issues and optimization recommendations.

## Table of Contents
1. [Environment Overview](#environment-overview)
2. [Local Development Setup](#local-development-setup)
3. [Docker Deployment](#docker-deployment)
4. [Production Deployment](#production-deployment)
5. [Environment Configuration](#environment-configuration)
6. [Database Setup](#database-setup)
7. [SSL/TLS Configuration](#ssltls-configuration)
8. [Monitoring & Health Checks](#monitoring--health-checks)
9. [Performance Optimization](#performance-optimization)
10. [Troubleshooting Guide](#troubleshooting-guide)
11. [Maintenance & Updates](#maintenance--updates)

---

## Environment Overview

The application supports multiple deployment environments with automatic configuration:

```
┌─────────────────┬─────────────────┬─────────────────┬─────────────────┐
│   Development   │     Testing     │     Staging     │   Production    │
├─────────────────┼─────────────────┼─────────────────┼─────────────────┤
│ SQLite Memory   │ SQLite Memory   │ PostgreSQL+TLS  │ PostgreSQL+TLS  │
│ Relaxed Limits  │ No Rate Limits  │ Prod-like Limits│ Strict Limits   │
│ Debug Logging   │ Test Logging    │ Info Logging    │ Error Logging   │
│ Local Files     │ Temp Files      │ Persistent Vol. │ Persistent Vol. │
│ HTTP OK         │ HTTP OK         │ HTTPS Required  │ HTTPS Required  │
└─────────────────┴─────────────────┴─────────────────┴─────────────────┘
```

### Environment Detection
The application automatically detects its environment:

```swift
// Environment-specific configuration
switch environment {
case .development:
    return DevelopmentConfiguration(environment: environment)
case .testing:
    return TestingConfiguration(environment: environment)  
case .staging, .production:
    return ProductionConfiguration(environment: environment)
default:
    return ProductionConfiguration(environment: environment)
}
```

---

## Local Development Setup

### Prerequisites

**System Requirements:**
- macOS 12+ or Ubuntu 20.04+
- Swift 5.9+ and Xcode 15+ (macOS)
- Docker and Docker Compose (optional)
- PostgreSQL 13+ (production testing)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/project-rulebook.git
cd project-rulebook

# Set up environment variables
cp .env.example .env
```

**Edit `.env` with your configuration:**
```bash
# Core Configuration
JWT_KEY=development_jwt_secret_key_minimum_32_characters_required_for_security
BASE_URL=http://localhost:8080
APPLICATION_IDENTIFIER=com.dev.project-rulebook

# External Services (get your own API keys)
OPENAI_KEY=your_openai_api_key_here
BREVO_API_KEY=your_brevo_api_key_here

# Cache Configuration
CACHE_MAX_ENTRIES=1000
CACHE_RULES_TTL=3600
CACHE_IMAGE_TTL=1800

# Rate Limiting (relaxed for development)
RATE_LIMIT_IMAGE_ANALYSIS=50
RATE_LIMIT_RULES_GENERATION=100
```

### Build and Run

```bash
# Build the application
swift build

# Run the application
swift run App serve --hostname 0.0.0.0 --port 8080
```

**Expected Output:**
```
[ INFO ] Configuration loaded for environment: development
[ INFO ] Database host: localhost
[ INFO ] AI Cache Service configured [max_entries: 1000, rules_ttl: 3600s]
[ INFO ] Services configured: Brevo, OpenAI  
[ INFO ] Server starting on http://0.0.0.0:8080
```

### Verification Steps

```bash
# Test server health
curl http://localhost:8080/health

# Test API endpoints
curl -X POST http://localhost:8080/api/rules-generation/rules-summary \
  -H "Content-Type: application/json" \
  -d '{"gameTitle":"Chess"}'

# Test admin login
curl -X POST http://localhost:8080/api/auth/sign-in \
  -H "Content-Type: application/json" \
  -d '{"email":"root@localhost.com","password":"ChangeMe1"}'
```

---

## Docker Deployment

### Development with Docker

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - ENVIRONMENT=development
      - JWT_KEY=development_jwt_secret_key_minimum_32_characters_required_for_security
      - BASE_URL=http://localhost:8080
      - OPENAI_KEY=${OPENAI_KEY}
      - BREVO_API_KEY=${BREVO_API_KEY}
    volumes:
      - .:/app
    depends_on:
      - db
    command: swift run App serve --hostname 0.0.0.0 --port 8080

  db:
    image: postgres:15
    environment:
      POSTGRES_DB: project_rulebook_dev
      POSTGRES_USER: vapor
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

**Dockerfile:**
```dockerfile
FROM swift:5.9-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy Package files
COPY Package.swift Package.resolved ./

# Resolve dependencies
RUN swift package resolve

# Copy source code
COPY Sources ./Sources
COPY Public ./Public
COPY Resources ./Resources

# Build the app
RUN swift build -c release

# Create non-root user
RUN useradd --user-group --system --no-create-home vapor

# Switch to non-root user
USER vapor:vapor

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Run the app
CMD ["./build/release/App", "serve", "--hostname", "0.0.0.0", "--port", "8080"]
```

### Docker Commands

```bash
# Build and run with Docker Compose
docker-compose up --build

# Run in background
docker-compose up -d

# View logs
docker-compose logs -f app

# Stop services
docker-compose down

# Rebuild after code changes
docker-compose build --no-cache app
docker-compose up app
```

---

## Production Deployment

### Server Requirements

**Minimum Specifications:**
- **CPU**: 2 vCPUs (4 vCPUs recommended)
- **RAM**: 2GB (4GB recommended)
- **Storage**: 20GB SSD (50GB recommended)
- **Network**: 1Gbps connection
- **OS**: Ubuntu 20.04 LTS or CentOS 8+

**Recommended Production Stack:**
- **Load Balancer**: nginx or HAProxy
- **Application**: Docker container or systemd service
- **Database**: PostgreSQL 15+ with read replicas
- **Cache**: Redis (future migration from in-memory)
- **Monitoring**: Prometheus + Grafana
- **Logging**: ELK Stack or similar

### Production Docker Configuration

**docker-compose.prod.yml:**
```yaml
version: '3.8'

services:
  app:
    build: 
      context: .
      dockerfile: Dockerfile.prod
    restart: unless-stopped
    environment:
      - ENVIRONMENT=production
      - JWT_KEY_FILE=/run/secrets/jwt_key
      - DATABASE_PASSWORD_FILE=/run/secrets/db_password
      - OPENAI_KEY_FILE=/run/secrets/openai_key
      - BREVO_API_KEY_FILE=/run/secrets/brevo_key
      - DATABASE_HOST=db
      - DATABASE_NAME=project_rulebook
      - DATABASE_USERNAME=vapor
      - DATABASE_PORT=5432
      - BASE_URL=https://your-domain.com
    networks:
      - app-network
    depends_on:
      - db
    secrets:
      - jwt_key
      - db_password
      - openai_key
      - brevo_key
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  db:
    image: postgres:15
    restart: unless-stopped
    environment:
      POSTGRES_DB: project_rulebook
      POSTGRES_USER: vapor
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    networks:
      - app-network
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    secrets:
      - db_password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U vapor -d project_rulebook"]
      interval: 30s
      timeout: 10s
      retries: 5

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      - nginx_logs:/var/log/nginx
    networks:
      - app-network
    depends_on:
      - app

networks:
  app-network:
    driver: bridge

volumes:
  postgres_data:
  nginx_logs:

secrets:
  jwt_key:
    external: true
  db_password:
    external: true
  openai_key:
    external: true
  brevo_key:
    external: true
```

**Dockerfile.prod:**
```dockerfile
FROM swift:5.9-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    libssl-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy and resolve dependencies
COPY Package.swift Package.resolved ./
RUN swift package resolve

# Copy source and build
COPY Sources ./Sources
COPY Public ./Public
COPY Resources ./Resources

RUN swift build -c release --static-swift-stdlib

# Production image
FROM ubuntu:20.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl1.1 \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app user
RUN useradd --user-group --system --no-create-home vapor

WORKDIR /app

# Copy binary and resources
COPY --from=builder /app/.build/release/App ./App
COPY --from=builder /app/Public ./Public
COPY --from=builder /app/Resources ./Resources

# Set ownership
RUN chown -R vapor:vapor /app

USER vapor:vapor

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

CMD ["./App", "serve", "--hostname", "0.0.0.0", "--port", "8080"]
```

### nginx Configuration

**nginx.conf:**
```nginx
events {
    worker_connections 1024;
}

http {
    upstream app {
        server app:8080;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=ai:10m rate=1r/s;

    # SSL Configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;

    server {
        listen 80;
        server_name your-domain.com;
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name your-domain.com;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-Frame-Options DENY always;

        # AI endpoints with stricter rate limiting
        location ~* ^/api/rules-generation/ {
            limit_req zone=ai burst=3 nodelay;
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 60s;
        }

        # General API endpoints
        location /api/ {
            limit_req zone=api burst=10 nodelay;
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Static files
        location /css/ {
            proxy_pass http://app;
            proxy_cache_valid 200 1h;
            add_header Cache-Control "public, max-age=3600";
        }

        # All other requests
        location / {
            proxy_pass http://app;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

### Deployment Commands

```bash
# Create Docker secrets
echo "your-secure-jwt-key-minimum-32-characters" | docker secret create jwt_key -
echo "your-secure-db-password" | docker secret create db_password -
echo "your-openai-api-key" | docker secret create openai_key -
echo "your-brevo-api-key" | docker secret create brevo_key -

# Deploy to production
docker stack deploy -c docker-compose.prod.yml project-rulebook

# Or use docker-compose (single server)
docker-compose -f docker-compose.prod.yml up -d

# Verify deployment
docker service ls
docker stack ps project-rulebook
```

---

## Environment Configuration

### Configuration Files

The application uses environment-specific configuration classes:

**Production Configuration:**
```swift
struct ProductionConfiguration: ConfigurationService {
    let environment: Environment
    
    var database: DatabaseConfig {
        get throws {
            DatabaseConfig(
                host: Environment.get("DATABASE_HOST") ?? "localhost",
                port: Int(Environment.get("DATABASE_PORT") ?? "5432") ?? 5432,
                name: Environment.get("DATABASE_NAME") ?? "project_rulebook",
                username: Environment.get("DATABASE_USERNAME") ?? "vapor",
                password: Environment.get("DATABASE_PASSWORD") ?? ""
            )
        }
    }
    
    var security: SecurityConfig {
        get throws {
            SecurityConfig(
                jwtKey: try getRequiredEnvVar("JWT_KEY"),
                baseURL: try getRequiredEnvVar("BASE_URL"),
                corsAllowedOrigins: Environment.get("CORS_ALLOWED_ORIGINS")?.split(separator: ",").map(String.init) ?? [],
                rateLimitEnabled: true,
                securityHeadersEnabled: true
            )
        }
    }
    
    // Additional configuration...
}
```

### Environment Variables Reference

#### Core Application
```bash
# Required
JWT_KEY=your-jwt-secret-minimum-32-characters
BASE_URL=https://your-domain.com
APPLICATION_IDENTIFIER=com.yourcompany.project-rulebook

# Environment Detection
ENVIRONMENT=production  # development, testing, staging, production
```

#### Database Configuration
```bash
# PostgreSQL (Production/Staging)
DATABASE_HOST=your-postgres-host
DATABASE_PORT=5432
DATABASE_NAME=project_rulebook
DATABASE_USERNAME=vapor
DATABASE_PASSWORD=your-secure-password

# Or use file-based secrets (Docker)
DATABASE_PASSWORD_FILE=/run/secrets/db_password
```

#### External Services
```bash
# OpenAI (Required for AI features)
OPENAI_KEY=sk-your-openai-api-key

# Brevo Email (Required for email features)  
BREVO_API_KEY=your-brevo-api-key
BREVO_URL=https://api.brevo.com
```

#### Performance Configuration
```bash
# Cache Settings
CACHE_MAX_ENTRIES=1000
CACHE_RULES_TTL=3600        # 1 hour
CACHE_IMAGE_TTL=1800        # 30 minutes
CACHE_CLEANUP_INTERVAL=600  # 10 minutes

# Rate Limiting
RATE_LIMIT_IMAGE_ANALYSIS=5    # requests/hour
RATE_LIMIT_RULES_GENERATION=10 # requests/hour
RATE_LIMIT_API_GENERAL=100     # requests/hour
RATE_LIMIT_ADMIN=50           # requests/hour
```

#### Security Configuration
```bash
# CORS (Production)
CORS_ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com

# Security Features
SECURITY_HEADERS_ENABLED=true
RATE_LIMITING_ENABLED=true
```

### Configuration Validation

The application validates all configuration on startup:

```swift
func validate() throws {
    // JWT key must be at least 32 characters
    let jwtKey = try getRequiredEnvVar("JWT_KEY")
    guard jwtKey.count >= 32 else {
        throw ConfigurationError.invalidJWTKey("JWT key must be at least 32 characters")
    }
    
    // Base URL must be valid
    let baseURL = try getRequiredEnvVar("BASE_URL")
    guard URL(string: baseURL) != nil else {
        throw ConfigurationError.invalidBaseURL("Invalid BASE_URL format")
    }
    
    // Additional validation...
}
```

---

## Database Setup

### PostgreSQL Installation

**Ubuntu/Debian:**
```bash
# Install PostgreSQL
sudo apt update
sudo apt install postgresql postgresql-contrib

# Start and enable service
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

**macOS (Homebrew):**
```bash
# Install PostgreSQL
brew install postgresql

# Start service
brew services start postgresql
```

### Database Configuration

```sql
-- Connect as postgres user
sudo -u postgres psql

-- Create database and user
CREATE DATABASE project_rulebook;
CREATE USER vapor WITH PASSWORD 'your-secure-password';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE project_rulebook TO vapor;
GRANT USAGE ON SCHEMA public TO vapor;
GRANT CREATE ON SCHEMA public TO vapor;

-- Exit psql
\q
```

### Production Database Security

```sql
-- Create limited privilege user
CREATE USER vapor_app WITH PASSWORD 'secure_random_password';

-- Grant minimal required privileges
GRANT CONNECT ON DATABASE project_rulebook TO vapor_app;
GRANT USAGE ON SCHEMA public TO vapor_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO vapor_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO vapor_app;

-- Set default privileges for new tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO vapor_app;

ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT USAGE, SELECT ON SEQUENCES TO vapor_app;
```

### Database Backups

**Backup Script (backup.sh):**
```bash
#!/bin/bash

# Configuration
DB_NAME="project_rulebook"
DB_USER="vapor"
BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Create backup
pg_dump -h localhost -U $DB_USER -d $DB_NAME | gzip > $BACKUP_DIR/backup_$DATE.sql.gz

# Keep only last 7 days of backups
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +7 -delete

echo "Backup completed: backup_$DATE.sql.gz"
```

**Automated Backups (Crontab):**
```bash
# Run backup daily at 2 AM
0 2 * * * /path/to/backup.sh
```

---

## SSL/TLS Configuration

### Let's Encrypt Certificate

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Auto-renewal (already configured by certbot)
sudo crontab -l | grep certbot
```

### Manual Certificate Setup

**Generate Certificate (Development):**
```bash
# Self-signed certificate for development
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout key.pem -out cert.pem \
  -config <(cat > cert.conf <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = localhost

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
IP.1 = 127.0.0.1
EOF
)
```

### TLS Best Practices

**nginx TLS Configuration:**
```nginx
# TLS versions and ciphers
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384;
ssl_prefer_server_ciphers off;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;

# Session settings
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_session_tickets off;

# DH parameters (generate with: openssl dhparam -out dhparam.pem 2048)
ssl_dhparam /etc/nginx/ssl/dhparam.pem;
```

---

## Monitoring & Health Checks

### Application Health Endpoint

**Health Check Response:**
```json
{
  "status": "ok",
  "timestamp": "2024-01-20T15:30:45Z",
  "services": {
    "database": "connected",
    "cache": "healthy",
    "external_services": {
      "openai": "available",
      "brevo": "available"
    }
  },
  "version": "1.0.0",
  "environment": "production"
}
```

### Docker Health Checks

**Dockerfile Health Check:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 --start-period=60s \
  CMD curl -f http://localhost:8080/health || exit 1
```

**Docker Compose Health Check:**
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### Monitoring Setup

**Prometheus Configuration (prometheus.yml):**
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'project-rulebook'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: /metrics
    scrape_interval: 30s

  - job_name: 'nginx'
    static_configs:
      - targets: ['localhost:9113']
```

**Log Monitoring (rsyslog):**
```bash
# Ship application logs to centralized logging
*.* @@logserver.example.com:514

# Local log rotation
/var/log/project-rulebook/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    postrotate
        systemctl reload project-rulebook
    endscript
}
```

---

## Performance Optimization

### Application Performance

**JVM-equivalent Memory Settings:**
```bash
# Swift equivalent environment variables
export MALLOC_ARENA_MAX=2
export MALLOC_MMAP_THRESHOLD_=131072
```

**Connection Pooling:**
```swift
// Configure database connection pool
databases.use(.postgres(
    configuration: postgresConfig,
    poolConfiguration: .init(
        minConnections: 2,
        maxConnections: 20,
        connectionIdleTimeout: .seconds(30)
    )
), as: .psql)
```

### Caching Strategy

**Cache Configuration:**
```bash
# Optimal cache settings for production
CACHE_MAX_ENTRIES=2000
CACHE_RULES_TTL=3600        # 1 hour (high hit rate)
CACHE_IMAGE_TTL=1800        # 30 minutes (moderate hit rate)
CACHE_CLEANUP_INTERVAL=300  # 5 minutes (more frequent cleanup)
```

**Cache Performance Monitoring:**
```swift
// Monitor cache hit rates
let stats = await cacheService.getStatistics()
logger.info("Cache performance", metadata: [
    "hit_ratio": .string(String(format: "%.1f%%", stats.hitRatio)),
    "utilization": .string(String(format: "%.1f%%", stats.utilization)),
    "cost_savings": .string("$\(calculateCostSavings(stats))")
])
```

### Database Optimization

**Index Recommendations:**
```sql
-- User lookup optimization
CREATE INDEX idx_users_email ON user_accounts(email);
CREATE INDEX idx_users_created_at ON user_accounts(created_at);

-- Token lookup optimization
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
CREATE INDEX idx_email_tokens_token ON email_tokens(token);
CREATE INDEX idx_password_tokens_token ON password_tokens(token);

-- Cleanup optimization
CREATE INDEX idx_email_tokens_expires_at ON email_tokens(expires_at);
CREATE INDEX idx_password_tokens_expires_at ON password_tokens(expires_at);
```

**Database Connection Tuning (postgresql.conf):**
```ini
# Connection settings
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB

# Logging
log_min_duration_statement = 1000  # Log slow queries
log_statement = 'mod'              # Log modifications
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
```

---

## Troubleshooting Guide

### Common Issues

#### 1. Server Won't Start

**Symptom:** Application exits immediately or fails to bind to port

**Diagnostics:**
```bash
# Check if port is already in use
lsof -i :8080
netstat -tlnp | grep :8080

# Check logs
docker-compose logs app
journalctl -u project-rulebook

# Verify environment variables
env | grep -E "(JWT_KEY|DATABASE_|OPENAI_)"
```

**Solutions:**
- **Port conflict:** Change port or kill conflicting process
- **Missing environment variables:** Verify `.env` file or Docker secrets
- **Invalid JWT key:** Ensure JWT_KEY is at least 32 characters
- **Database connection:** Verify database is running and accessible

#### 2. Authentication Issues

**Symptom:** "Request is missing JWT bearer header" or "Invalid token"

**Diagnostics:**
```bash
# Test admin login
curl -v -X POST http://localhost:8080/api/auth/sign-in \
  -H "Content-Type: application/json" \
  -d '{"email":"root@localhost.com","password":"ChangeMe1"}'

# Check JWT key configuration
echo $JWT_KEY | wc -c  # Should be 32+ characters

# Verify database contains admin user
docker-compose exec db psql -U vapor -d project_rulebook -c "SELECT email, is_admin FROM user_accounts WHERE email = 'root@localhost.com';"
```

**Solutions:**
- **Admin user missing:** Run application once to create default admin user
- **Wrong password:** Use default password "ChangeMe1" or update environment
- **JWT key issue:** Generate new JWT key with at least 32 characters
- **Token expired:** Re-authenticate to get new tokens

#### 3. Database Connection Errors

**Symptom:** "Failed to connect to database" or connection timeouts

**Diagnostics:**
```bash
# Test database connectivity
docker-compose exec app pg_isready -h db -p 5432 -U vapor

# Check database status
docker-compose exec db pg_ctl status

# Verify credentials
docker-compose exec db psql -U vapor -d project_rulebook -c "SELECT version();"
```

**Solutions:**
- **Database not running:** Start database service: `docker-compose up db`
- **Wrong credentials:** Verify DATABASE_* environment variables
- **Network issues:** Check Docker network connectivity
- **Permission issues:** Verify user has required database privileges

#### 4. AI Service Failures

**Symptom:** "External service temporarily unavailable" or AI endpoint errors

**Diagnostics:**
```bash
# Test OpenAI API key
curl -H "Authorization: Bearer $OPENAI_KEY" \
  https://api.openai.com/v1/models

# Check AI endpoint directly
curl -X POST http://localhost:8080/api/rules-generation/rules-summary \
  -H "Content-Type: application/json" \
  -d '{"gameTitle":"Test Game"}' -v

# Monitor AI service logs
docker-compose logs app | grep -E "(OpenAI|LLM|AI)"
```

**Solutions:**
- **Invalid API key:** Verify OPENAI_KEY is valid and has sufficient credits
- **Rate limiting:** Check OpenAI usage limits and billing
- **Network issues:** Verify outbound HTTPS connectivity
- **Input validation:** Ensure game titles don't contain injection patterns

#### 5. Cache Performance Issues

**Symptom:** High response times or low cache hit rates

**Diagnostics:**
```bash
# Check cache statistics (requires admin authentication)
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/sign-in \
  -H "Content-Type: application/json" \
  -d '{"email":"root@localhost.com","password":"ChangeMe1"}' | \
  jq -r '.token.accessToken')

curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/admin/cache/stats | jq

# Monitor cache health
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/admin/cache/health | jq
```

**Solutions:**
- **Low hit rate (<50%):** Increase TTL values or check for cache key issues
- **High utilization (>90%):** Increase CACHE_MAX_ENTRIES
- **Memory issues:** Monitor system memory usage
- **Cleanup problems:** Check cache cleanup interval and expired entry removal

#### 6. Rate Limiting Issues

**Symptom:** "Rate limit exceeded" errors or 429 responses

**Diagnostics:**
```bash
# Test rate limits
for i in {1..12}; do
  echo "Request $i:"
  curl -w "%{http_code} - %{header_json}\n" -s \
    -X POST http://localhost:8080/api/rules-generation/rules-summary \
    -H "Content-Type: application/json" \
    -d '{"gameTitle":"Test '$i'"}'
done
```

**Solutions:**
- **Development:** Increase rate limits in environment variables
- **Production:** Implement request queuing or user education
- **IP issues:** Check if IP extraction is working correctly
- **Time-based:** Wait for rate limit window to reset

### Performance Troubleshooting

#### High Memory Usage

**Diagnostics:**
```bash
# Check container memory usage
docker stats

# Monitor Swift memory usage
docker-compose exec app ps aux | grep App

# Check for memory leaks
docker-compose exec app cat /proc/meminfo
```

**Solutions:**
- **Cache size:** Reduce CACHE_MAX_ENTRIES
- **Connection pool:** Reduce database max connections
- **Memory leaks:** Restart application periodically
- **Resource limits:** Set Docker memory limits

#### Slow Response Times

**Diagnostics:**
```bash
# Test endpoint response times
time curl -X POST http://localhost:8080/api/rules-generation/rules-summary \
  -H "Content-Type: application/json" \
  -d '{"gameTitle":"Chess"}'

# Check database query performance
docker-compose exec db psql -U vapor -d project_rulebook \
  -c "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"

# Monitor cache hit rates
# (Use cache admin endpoints as shown above)
```

**Solutions:**
- **Database optimization:** Add indexes, tune queries
- **Cache improvement:** Increase TTL values, pre-warm cache
- **External services:** Check OpenAI API response times
- **Connection pooling:** Optimize database connection settings

### Logging & Debugging

#### Enable Debug Logging

**Development:**
```bash
# Set log level
export LOG_LEVEL=debug

# Run with verbose output
swift run App serve --log-level debug
```

**Production:**
```yaml
# docker-compose.prod.yml
environment:
  - LOG_LEVEL=info  # or debug for troubleshooting
```

#### Structured Logging

**Log Format:**
```json
{
  "level": "INFO",
  "timestamp": "2024-01-20T15:30:45.123Z",
  "logger": "app.security",
  "message": "User authentication successful",
  "metadata": {
    "user_id": "123e4567-e89b-12d3-a456-426614174000",
    "client_ip": "192.168.1.100",
    "correlation_id": "req-abc123def456"
  }
}
```

**Log Monitoring Commands:**
```bash
# Follow application logs
docker-compose logs -f app

# Search for specific patterns
docker-compose logs app | grep -E "(ERROR|WARN|security)"

# Export logs for analysis
docker-compose logs app > application.log
```

---

## Maintenance & Updates

### Regular Maintenance Tasks

#### Daily Tasks
```bash
#!/bin/bash
# daily-maintenance.sh

# Check service health
curl -f http://localhost:8080/health || echo "Health check failed"

# Check disk usage
df -h | grep -E "(/$|/var/lib/docker)"

# Monitor error logs
docker-compose logs --since 24h app | grep -c ERROR

# Backup database (if not automated)
./backup.sh
```

#### Weekly Tasks
```bash
#!/bin/bash
# weekly-maintenance.sh

# Update system packages
sudo apt update && sudo apt list --upgradable

# Clean up Docker images
docker system prune -f

# Check SSL certificate expiration
openssl x509 -in /path/to/cert.pem -noout -dates

# Review security logs
docker-compose logs app | grep -E "(injection|rate.limit|authentication)" | tail -100
```

#### Monthly Tasks
- Security patch assessment and deployment
- Performance review and optimization
- Backup verification and restore testing
- SSL certificate renewal (if not automated)
- Log rotation and cleanup
- Dependency updates and security scanning

### Application Updates

#### Zero-Downtime Deployment

**Blue-Green Deployment:**
```bash
#!/bin/bash
# deploy.sh

set -e

# Build new version
docker-compose -f docker-compose.prod.yml build app

# Start new version alongside current
docker-compose -f docker-compose.prod.yml up -d --scale app=2 app

# Health check new instances
sleep 30
curl -f http://localhost:8080/health

# Update load balancer to point to new instances
# (Implementation depends on your load balancer)

# Stop old instances
docker-compose -f docker-compose.prod.yml up -d --scale app=1 app

echo "Deployment completed successfully"
```

#### Rolling Updates (Docker Swarm)

```bash
# Update with rolling deployment
docker service update --image your-registry/project-rulebook:latest \
  --update-parallelism 1 \
  --update-delay 30s \
  project-rulebook_app
```

### Database Migrations

**Migration Workflow:**
```bash
# 1. Create database backup
./backup.sh

# 2. Test migration in staging
ENVIRONMENT=staging swift run App migrate

# 3. Apply to production (if staging successful)
ENVIRONMENT=production swift run App migrate --auto-migrate

# 4. Verify migration success
docker-compose exec db psql -U vapor -d project_rulebook -c "\dt"
```

### Security Updates

#### Vulnerability Assessment

```bash
# Check for security updates
sudo apt list --upgradable | grep -i security

# Scan Docker images for vulnerabilities
docker scan your-image:latest

# Check Swift dependencies
swift package audit
```

#### Emergency Security Response

1. **Immediate Response:**
   ```bash
   # Stop affected services
   docker-compose stop app
   
   # Apply security patches
   # (Implementation specific)
   
   # Restart with fixes
   docker-compose up -d app
   ```

2. **Validation:**
   ```bash
   # Verify fix is applied
   curl -f http://localhost:8080/health
   
   # Check security logs
   docker-compose logs app | tail -100 | grep -E "(error|security)"
   ```

3. **Communication:**
   - Notify stakeholders of issue and resolution
   - Document incident and response
   - Update monitoring and alerting if needed

---

This comprehensive deployment and troubleshooting guide provides everything needed to successfully deploy, maintain, and troubleshoot the Project Rulebook application in any environment. The guide emphasizes security, monitoring, and automation to ensure reliable operation in production environments.

For additional support or specific deployment scenarios not covered here, refer to the detailed architecture documentation and API guides, or create an issue in the project repository.