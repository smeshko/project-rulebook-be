# Railway Multi-Environment Deployment Setup

This document provides comprehensive guidance for setting up staging and production environments for the project-rulebook Vapor application on Railway.

## Architecture Overview

### Deployment Strategy: Single Project, Multiple Environments

We use a **single Railway project** with separate **staging** and **production** environments. This approach provides:

- **Resource Efficiency**: Shared project infrastructure with environment isolation
- **Environment Parity**: Consistent configuration patterns across environments
- **Simplified Management**: Single project dashboard with clear environment separation
- **Cost Optimization**: Efficient resource allocation and billing
- **Easy Promotion**: Streamlined promotion workflow from staging to production

### Environment Configuration

| Environment | Branch | Auto-Deploy | Database | Redis | Domain |
|-------------|--------|-------------|----------|-------|---------|
| **Staging** | `staging` | ✅ Enabled | PostgreSQL | Redis | `*.up.railway.app` |
| **Production** | `main` | ✅ Enabled | PostgreSQL | Redis | Custom domain |

## Setup Instructions

### Prerequisites

1. **Railway CLI**: Install and authenticate
   ```bash
   curl -fsSL https://railway.app/install.sh | sh
   railway login
   ```

2. **GitHub Repository**: Ensure your repository is accessible to Railway
3. **Environment Variables**: Prepare secrets for staging and production

### Step 1: Initial Project Setup

Execute the automated setup script:

```bash
# Make the setup script executable
chmod +x railway-setup.sh

# Run the complete setup
./railway-setup.sh
```

This script will:
- Create the Railway project "project-rulebook"
- Set up staging and production environments
- Add PostgreSQL and Redis services to both environments
- Configure basic environment variables

### Step 2: GitHub Integration

Configure automatic deployments from GitHub:

```bash
# Run GitHub integration setup
./railway-github-setup.sh
```

**Manual Steps Required:**
1. Visit [Railway Dashboard](https://railway.app/dashboard)
2. Select your project-rulebook project
3. For each environment:
   - Navigate to app service → Settings → Source
   - Connect GitHub repository
   - Set appropriate branch (staging/main)
   - Enable auto-deploy

### Step 3: Environment Variables Configuration

#### Staging Environment Variables
```bash
railway environment staging
railway variables set -f .env.staging.example
```

#### Production Environment Variables
```bash
railway environment production
railway variables set -f .env.production.example
```

#### Required Variables

| Variable | Description | Staging | Production |
|----------|-------------|---------|------------|
| `DATABASE_URL` | PostgreSQL connection | `${{Postgres.DATABASE_URL}}` | `${{Postgres.DATABASE_URL}}` |
| `REDIS_URL` | Redis connection | `${{Redis.REDIS_URL}}` | `${{Redis.REDIS_URL}}` |
| `ENVIRONMENT` | App environment | `staging` | `production` |
| `LOG_LEVEL` | Logging level | `debug` | `info` |
| `JWT_SECRET` | JWT signing key | Generate unique | Generate unique |
| `BREVO_API_KEY` | Email service API key | Staging key | Production key |
| `OPENAI_API_KEY` | OpenAI API key | Shared or separate | Production key |

### Step 4: Domain Configuration

#### Staging Domain
- **Type**: Railway-provided domain
- **Format**: `project-rulebook-staging.up.railway.app`
- **Setup**: Auto-generated via Railway dashboard

#### Production Domain
- **Type**: Custom domain (recommended)
- **Setup**: Configure DNS records via Railway dashboard
- **Fallback**: Railway-provided domain if custom not available

## Deployment Workflow

### Automatic Deployments

1. **Staging**: Triggered by pushes to `staging` branch
2. **Production**: Triggered by pushes to `main` branch

### Manual Deployments

```bash
# Deploy to staging
./railway-deploy.sh staging

# Deploy to production
./railway-deploy.sh production
```

### Promotion Workflow

1. **Development**: Work on feature branches
2. **Staging**: Merge to `staging` branch → Auto-deploy to staging
3. **Testing**: Test on staging environment
4. **Production**: Merge to `main` branch → Auto-deploy to production

## Monitoring and Operations

### Health Checks

- **Endpoint**: `/health`
- **Timeout**: 300 seconds
- **Restart Policy**: ON_FAILURE (max 10 retries)

### Logging

```bash
# View staging logs
railway environment staging && railway logs

# View production logs
railway environment production && railway logs

# Follow logs in real-time
railway logs --follow
```

### Database Management

#### Staging Database
```bash
railway environment staging
railway connect Postgres  # Direct database access
```

#### Production Database
```bash
railway environment production
railway connect Postgres  # Direct database access (use with caution)
```

### Redis Cache Management

```bash
# Connect to Redis
railway environment [staging|production]
railway connect Redis
```

## Security Considerations

### Environment Isolation
- **Network**: Environments are network-isolated
- **Data**: Separate databases and Redis instances
- **Secrets**: Environment-specific secret management

### Access Control
- **Railway Access**: Use teams and role-based access
- **Database Access**: Restrict direct production access
- **API Keys**: Separate keys for staging and production

### SSL/TLS
- **Staging**: Automatic HTTPS via Railway
- **Production**: Automatic HTTPS + custom domain TLS

## Scaling Configuration

### Vertical Scaling
```bash
# Increase memory/CPU for production
railway environment production
railway run --memory 2048 --cpu 2
```

### Horizontal Scaling
```bash
# Enable replicas for production
railway environment production
railway scale --replicas 3
```

### Multi-Region Deployment
- **Available Regions**: US West, US East, EU West, Asia Southeast
- **Configuration**: Via Railway dashboard → Service Settings → Regions
- **Load Balancing**: Automatic traffic routing to nearest region

## Troubleshooting

### Common Issues

1. **Build Failures**
   ```bash
   railway logs --deployment <deployment-id>
   ```

2. **Environment Variable Issues**
   ```bash
   railway variables
   ```

3. **Service Connection Issues**
   ```bash
   railway status
   railway restart
   ```

### Emergency Procedures

#### Rollback Deployment
```bash
railway environment production
railway rollback <previous-deployment-id>
```

#### Emergency Maintenance Mode
```bash
# Scale down to 0 replicas temporarily
railway scale --replicas 0
```

## Performance Optimization

### Database Optimization
- **Connection Pooling**: Configured in Vapor application
- **Connection Limits**: Monitor via Railway metrics
- **Query Performance**: Use slow query logs

### Redis Optimization
- **Memory Usage**: Monitor via Railway dashboard
- **Eviction Policy**: Configure based on usage patterns
- **Persistence**: Configured for production durability

### Application Performance
- **Health Check Tuning**: Optimize timeout values
- **Graceful Shutdown**: Configure `RAILWAY_DEPLOYMENT_DRAINING_SECONDS`
- **Zero-Downtime Deployments**: Configure `RAILWAY_DEPLOYMENT_OVERLAP_SECONDS`

## Cost Management

### Resource Monitoring
- **CPU/Memory Usage**: Track via Railway dashboard
- **Database Storage**: Monitor growth trends
- **Network Usage**: Track ingress/egress

### Cost Optimization
- **Environment Sleep**: Configure app sleep for staging during off-hours
- **Resource Right-Sizing**: Adjust based on actual usage
- **Service Consolidation**: Share Redis between environments if appropriate

## Backup and Recovery

### Database Backups
- **Automatic**: Railway provides automatic PostgreSQL backups
- **Manual**: Use `pg_dump` for additional backups
- **Retention**: Configure backup retention policies

### Application State
- **Code**: Git repository serves as source of truth
- **Configuration**: Environment variables backed up in documentation
- **Deployments**: Railway maintains deployment history

## Contact and Support

### Railway Support
- **Dashboard**: [Railway Dashboard](https://railway.app/dashboard)
- **Documentation**: [Railway Docs](https://docs.railway.app)
- **Community**: [Railway Discord](https://discord.gg/railway)

### Project Resources
- **Repository**: [GitHub Repository](https://github.com/smeshko/project-rulebook)
- **Railway Project**: Access via Railway dashboard
- **Documentation**: This repository's `/docs` directory

---

**Last Updated**: 2025-08-19  
**Version**: 1.0  
**Maintained By**: DevOps Team