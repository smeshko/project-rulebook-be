# 🚂 Railway Deployment Plan for Vapor Project-Rulebook

## Overview

This document outlines the comprehensive deployment strategy for migrating the project-rulebook Vapor application to Railway. Railway was selected for its simplicity, excellent developer experience, built-in CI/CD capabilities, and usage-based pricing model.

## Project Context

**Current Setup:**
- Swift Vapor 4 application
- PostgreSQL database
- Redis caching layer  
- Docker containerized
- Multiple external integrations (OpenAI, Brevo)

**Target Platform:** Railway
- Simplicity-first deployment
- Built-in database services
- GitHub auto-deployment
- Usage-based pricing

## 🎯 Implementation Status

**Current Phase**: Phase 1 & 3 Complete ✅  
**Branch**: `deployment/railway-setup`  
**Last Updated**: August 19, 2025  

### Completed Work ✅
- ✅ **Railway CLI Setup**: Installation and project initialization complete
- ✅ **Configuration Files**: `railway.toml` and `.railway/railway.json` created
- ✅ **Dockerfile Updates**: PORT environment variable support added
- ✅ **Database Configuration**: Railway DATABASE_URL and REDIS_URL support implemented
- ✅ **Health Check Endpoint**: `/health` endpoint added for Railway healthchecks
- ✅ **Deployment Scripts**: Migration and deployment automation scripts created
- ✅ **Build Verification**: Local compilation successful with `swift build`
- ✅ **Backward Compatibility**: Local development setup preserved

### Next Steps
- **Phase 2**: Database & Redis setup on Railway platform
- **Phase 4**: CI/CD & GitHub integration
- **Phase 5**: Testing & validation

---

## Phase 1: Railway Setup & Configuration ✅ COMPLETED

### 1.1 Railway Account & CLI Setup ✅

**Prerequisites:** ✅ **COMPLETED**
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Verify installation
railway --version
```

**Project Initialization:** ✅ **COMPLETED**
```bash
# Navigate to project directory
cd /path/to/project-rulebook

# Initialize Railway project
railway init

# Link to existing project (if created via web)
railway link [project-id]
```

### 1.2 Create Railway Configuration Files ✅

**railway.toml** ✅ **CREATED**:
```toml
[build]
builder = "DOCKERFILE"
dockerfile = "Dockerfile"

[deploy]
startCommand = "./App serve --hostname 0.0.0.0 --port $PORT"
healthcheckPath = "/health"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

[environment]
PORT = "8080"
```

**.railway/railway.json** ✅ **CREATED**: Complete Railway project configuration

### 1.3 Update Dockerfile for Railway ✅

**Required Changes:** ✅ **COMPLETED**
- ✅ Dockerfile updated to use PORT environment variable
- ✅ Health check endpoint added
- ✅ Optimized for Railway's container runtime

**Updated CMD in Dockerfile:** ✅ **IMPLEMENTED**
```dockerfile
# Updated to use environment variable
CMD ["serve", "--hostname", "0.0.0.0", "--port", "$PORT"]
```

---

## Phase 2: Database & Redis Setup

### 2.1 PostgreSQL Configuration

**Railway Database Setup:**
1. Add PostgreSQL service via Railway dashboard
2. Railway automatically provides `DATABASE_URL` environment variable
3. Update application configuration

**Database Connection Format:**
```
DATABASE_URL=postgresql://username:password@hostname:port/database
```

**Migration Strategy:**
- Configure automatic migrations on deploy
- Set up release command in Railway
- Create backup strategy

### 2.2 Redis Configuration  

**Railway Redis Setup:**
1. Add Redis service via Railway dashboard
2. Railway provides `REDIS_URL` environment variable
3. Configure connection pooling

**Redis Connection Format:**
```
REDIS_URL=redis://hostname:port
```

### 2.3 Environment Variables Migration

**Environment Variable Mapping:**

| Local Variable | Railway Variable | Notes |
|---------------|------------------|-------|
| `DATABASE_HOST` | `DATABASE_URL` | Railway provides full URL |
| `DATABASE_NAME` | `DATABASE_URL` | Included in URL |
| `DATABASE_USERNAME` | `DATABASE_URL` | Included in URL |
| `DATABASE_PASSWORD` | `DATABASE_URL` | Included in URL |
| `REDIS_HOST` | `REDIS_URL` | Railway provides full URL |
| `REDIS_PORT` | `REDIS_URL` | Included in URL |
| `BASE_URL` | `RAILWAY_PUBLIC_DOMAIN` | Auto-generated |
| All other vars | Direct copy | Same name |

**Required Environment Variables for Railway:**
```bash
# Automatically provided by Railway
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
PORT=8080
RAILWAY_PUBLIC_DOMAIN=your-app.up.railway.app

# Manually configured
APPLICATION_IDENTIFIER=com.yourapp.identifier
JWT_KEY=[secure-key-32-chars-minimum]
OPENAI_KEY=[your-openai-key]
BREVO_API_KEY=[your-brevo-key]

# Optional (if using)
AWS_ACCESS_KEY=[key]
AWS_SECRET_ACCESS_KEY=[key]  
AWS_REGION=us-west-2
APNS_KEY=[key]
APNS_PRIVATE_KEY=[private-key]
APNS_TEAM_ID=[team-id]
```

---

## Phase 3: Application Configuration ✅ COMPLETED

### 3.1 Update Application Code ✅

**configure.swift Updates:** ✅ **IMPLEMENTED**

**Architectural Decision**: Enhanced `ProductionConfiguration.swift` to support Railway's DATABASE_URL and REDIS_URL format while maintaining backward compatibility with existing local development setup.

```swift
// ✅ IMPLEMENTED: Railway database configuration
if let databaseURL = Environment.get("DATABASE_URL") {
    try app.databases.use(.postgres(url: databaseURL), as: .psql)
} else {
    // Fallback to individual environment variables for local development
    try app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? 5432,
        username: Environment.get("DATABASE_USERNAME") ?? "vapor",
        password: Environment.get("DATABASE_PASSWORD") ?? "password",
        database: Environment.get("DATABASE_NAME") ?? "project_rulebook_dev"
    ), as: .psql)
}

// ✅ IMPLEMENTED: Railway Redis configuration
if let redisURL = Environment.get("REDIS_URL") {
    try app.redis.use(.init(url: redisURL))
} else {
    // Fallback for local development
    try app.redis.use(.init(
        hostname: Environment.get("REDIS_HOST") ?? "localhost",
        port: Environment.get("REDIS_PORT").flatMap(Int.init(_:)) ?? 6379
    ))
}

// ✅ IMPLEMENTED: PORT environment variable support
let port = Environment.get("PORT").flatMap(Int.init(_:)) ?? 8080
app.http.server.configuration.port = port
```

### 3.2 Health Check Endpoint ✅

**Health Check Route:** ✅ **IMPLEMENTED**
```swift
// ✅ ADDED: Health check endpoint at /health in configure.swift
app.get("health") { req in
    return [
        "status": "healthy",
        "timestamp": Date().timeIntervalSince1970,
        "version": "1.0.0"
    ]
}
```

### 3.3 Create Railway-Specific Files ✅

**Files Created:** ✅ **ALL COMPLETED**

1. ✅ **.railway/railway.json** - Complete Railway project configuration
2. ✅ **scripts/migrate.sh** - Database migration script for Railway
3. ✅ **scripts/deploy.sh** - Deployment automation script

**Build Verification**: ✅ **PASSED** - Local compilation successful with `swift build`

---

## Phase 4: CI/CD & GitHub Integration

### 4.1 GitHub Connection

**Setup Steps:**
1. Connect GitHub repository to Railway dashboard
2. Select `staging` branch for automatic deployments
3. Configure webhook for push events

**Branch Strategy:**
- `main` → Production environment
- `staging` → Staging environment
- Feature branches → Preview environments (via PR)

### 4.2 Environment Management

**Environment Configuration:**

| Environment | Branch | Domain | Database | Purpose |
|-------------|--------|--------|----------|---------|
| Production | `main` | `project-rulebook.up.railway.app` | Prod DB | Live app |
| Staging | `staging` | `staging-project-rulebook.up.railway.app` | Staging DB | Testing |
| Preview | PR branches | `pr-123-project-rulebook.up.railway.app` | Temp DB | Code review |

### 4.3 Deployment Pipeline

**Automatic Deployment Triggers:**
- Push to `staging` → Deploy to staging
- Push to `main` → Deploy to production  
- Open PR → Create preview environment
- Close PR → Destroy preview environment

**Release Commands:**
```bash
# Run migrations before deployment
swift run App migrate --yes

# Optional: Seed data
swift run App seed
```

---

## Phase 5: Testing & Validation

### 5.1 Local Testing with Railway

**Local Development Commands:**
```bash
# Test with Railway environment variables
railway run swift run App serve

# Run migrations locally with Railway DB
railway run swift run App migrate --yes

# Access Railway shell
railway shell

# View Railway logs
railway logs
```

### 5.2 Staging Deployment Checklist

**Pre-deployment Testing:**
- [ ] All tests pass locally
- [ ] Docker build succeeds
- [ ] Environment variables configured
- [ ] Database migrations ready
- [ ] External API keys configured

**Post-deployment Validation:**
- [ ] Application starts successfully
- [ ] Database connection established
- [ ] Redis connection working
- [ ] Health check endpoint responds
- [ ] All API endpoints functional
- [ ] OpenAI integration working
- [ ] Brevo email service working

### 5.3 Production Readiness

**Production Checklist:**
- [ ] SSL certificate configured
- [ ] Custom domain setup (optional)
- [ ] Error tracking configured
- [ ] Performance monitoring enabled
- [ ] Backup strategy implemented
- [ ] Rollback procedure documented

---

## Phase 6: Optimization & Monitoring

### 6.1 Performance Optimization

**Railway Configuration:**
- **Memory**: Start with 1GB, adjust based on usage
- **CPU**: Shared CPU sufficient for most loads
- **Auto-scaling**: Enable horizontal scaling
- **Health checks**: 30-second intervals

**Docker Optimization:**
- Use multi-stage builds (already implemented)
- Minimize image size
- Cache dependency layers
- Use static linking (already configured)

### 6.2 Monitoring Setup

**Railway Built-in Monitoring:**
- CPU and memory usage
- Request/response metrics  
- Error rates and logs
- Database connection monitoring

**Application Logging:**
```swift
// Ensure proper logging configuration
app.logger.logLevel = .info
app.environment.isRelease ? .info : .debug
```

**Alerts Configuration:**
- High error rates
- Memory usage > 80%
- Database connection failures
- External API failures

---

## Deployment Commands Reference

### Initial Setup
```bash
# Install and login
npm install -g @railway/cli
railway login

# Initialize project
cd /path/to/project-rulebook
railway init
```

### Daily Development
```bash
# Deploy current branch
railway up

# Run commands in Railway environment
railway run swift run App migrate --yes

# View logs
railway logs --tail

# Access database
railway connect postgres

# Access Redis
railway connect redis
```

### Environment Management
```bash
# List environments
railway environment

# Switch environment
railway environment staging

# Set environment variables
railway variables set JWT_KEY=your-secure-key
```

---

## Migration Timeline

### Week 1: Setup & Configuration
- Days 1-2: Railway account setup, CLI installation
- Days 3-4: Database and Redis service creation
- Days 5-7: Application configuration updates

### Week 2: Testing & Deployment
- Days 1-3: Local testing with Railway services
- Days 4-5: Staging environment deployment
- Days 6-7: Production deployment and validation

### Week 3: Optimization & Monitoring
- Days 1-2: Performance monitoring setup
- Days 3-4: Load testing and optimization
- Days 5-7: Documentation and team training

---

## Rollback Strategy

### Automated Rollback
```bash
# Rollback to previous deployment
railway rollback

# Rollback to specific deployment
railway rollback --deployment [deployment-id]
```

### Manual Rollback
1. Switch to previous Git commit
2. Deploy manually: `railway up`
3. Run database migrations if needed
4. Verify application functionality

---

## Cost Estimation

### Railway Pricing (Usage-Based)
- **Free Trial**: $5 credit
- **Hobby Plan**: $5/month included usage
- **Expected Monthly Cost**: $8-15/month
  - App hosting: $3-5
  - PostgreSQL: $2-5  
  - Redis: $1-3
  - Bandwidth: $1-2

### Cost Comparison
- **Heroku**: ~$25-35/month (Basic + DB + Redis)
- **Railway**: ~$8-15/month (usage-based)
- **Fly.io**: ~$10-20/month (global deployment)

---

## Support & Documentation

### Railway Resources
- [Railway Documentation](https://docs.railway.com)
- [Railway Community](https://discord.gg/railway)
- [Railway Status](https://status.railway.com)

### Project Documentation
- Update `README.md` with Railway deployment instructions
- Create deployment troubleshooting guide
- Document environment variable management

---

## Success Metrics

### Deployment Success Criteria
- [ ] Zero-downtime deployment
- [ ] All tests passing in production
- [ ] Sub-2-second response times maintained
- [ ] Database migrations successful
- [ ] External integrations functional

### Long-term Goals
- [ ] 99.9% uptime achieved
- [ ] Deployment time < 3 minutes
- [ ] Monthly hosting costs < $20
- [ ] Team productivity improved

---

*Last Updated: August 19, 2025*
*Next Review: After Phase 2 completion (Database & Redis setup)*

## Implementation Notes

**Architectural Decisions Made:**
1. **Backward Compatibility**: All Railway configurations maintain compatibility with existing local development setup
2. **Configuration Strategy**: Enhanced `ProductionConfiguration.swift` rather than modifying `configure.swift` directly
3. **Health Check Integration**: Added Railway-specific health endpoint without disrupting existing routes
4. **Environment Variable Strategy**: Implemented Railway URL-based config with graceful fallback to individual variables

**Branch Status**: `deployment/railway-setup` ready for Phase 2 implementation