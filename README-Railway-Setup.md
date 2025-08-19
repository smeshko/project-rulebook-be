# Railway Deployment Quick Start

This guide provides step-by-step instructions to deploy the project-rulebook Vapor application to Railway with staging and production environments.

## 🚀 Quick Setup (5 minutes)

### Prerequisites
- Railway CLI installed and authenticated
- GitHub repository access
- Required environment variable values

### 1. Authenticate with Railway
```bash
# Install Railway CLI (if not already installed)
curl -fsSL https://railway.app/install.sh | sh

# Login to Railway (opens browser)
railway login
```

### 2. Run Automated Setup
```bash
# Execute the complete setup script
./railway-setup.sh
```

This creates:
- Railway project "project-rulebook"
- Staging environment with PostgreSQL + Redis
- Production environment with PostgreSQL + Redis
- Basic environment variables

### 3. Configure GitHub Integration
```bash
# Setup GitHub auto-deployment
./railway-github-setup.sh
```

Then complete the GitHub connection via Railway dashboard:
1. Go to [Railway Dashboard](https://railway.app/dashboard)
2. Select project-rulebook
3. Connect GitHub repository
4. Configure branches: `staging` → staging env, `main` → production env

### 4. Set Environment Variables

Copy and customize the environment files:
```bash
# Copy staging environment template
cp .env.staging.example .env.staging

# Copy production environment template  
cp .env.production.example .env.production

# Edit the files with your actual values
# Then upload to Railway:
railway environment staging && railway variables set -f .env.staging
railway environment production && railway variables set -f .env.production
```

### 5. Deploy
```bash
# Deploy to staging
./railway-deploy.sh staging

# Deploy to production (when ready)
./railway-deploy.sh production
```

## 🔧 Environment Structure

| Environment | Branch | Database | Redis | Domain |
|-------------|--------|----------|-------|---------|
| **Staging** | `staging` | PostgreSQL | Redis | `*.up.railway.app` |
| **Production** | `main` | PostgreSQL | Redis | Custom domain |

## 📊 Monitoring

```bash
# Check deployment status
railway status

# View logs
railway logs

# Open in browser
railway open
```

## 🛠️ Common Commands

```bash
# Switch environments
railway environment staging
railway environment production

# View variables
railway variables

# Connect to database
railway connect Postgres

# Connect to Redis
railway connect Redis

# Restart service
railway restart

# Scale replicas (production)
railway scale --replicas 3
```

## 📚 Full Documentation

For complete setup details, troubleshooting, and advanced configuration, see:
- [Full Railway Setup Guide](docs/infrastructure/Railway-Multi-Environment-Setup.md)
- [Railway Deployment Plan](docs/deployment/railway-deployment-plan.md)

## 🆘 Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| Build fails | Check `railway logs` for errors |
| Variables missing | Run `railway variables` to verify |
| Connection issues | Check service status with `railway status` |
| Deploy stuck | Try `railway restart` |

---

**Need Help?** Check the [full documentation](docs/infrastructure/Railway-Multi-Environment-Setup.md) or Railway's [official docs](https://docs.railway.app).