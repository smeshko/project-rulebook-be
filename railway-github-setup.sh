#!/bin/bash

# Railway GitHub Integration Setup Script
# This script configures GitHub integration for automatic deployments

set -e

echo "🔗 Setting up GitHub integration for Railway project-rulebook"

# Check if railway CLI is available and user is logged in
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI is not installed. Please install it first"
    exit 1
fi

if ! railway whoami &> /dev/null; then
    echo "❌ Not logged into Railway. Please run 'railway login' first"
    exit 1
fi

echo "🔧 Configuring GitHub integration..."

# Configure staging environment for auto-deploy from staging branch
echo "⚙️ Setting up staging environment GitHub integration..."
railway environment staging

# Note: The actual GitHub connection needs to be done via Railway dashboard
# This script provides the commands and guidance

echo "📋 GitHub Integration Setup Instructions:"
echo ""
echo "1. Go to Railway Dashboard: https://railway.app/dashboard"
echo "2. Select your 'project-rulebook' project"
echo "3. For each environment (staging & production):"
echo ""
echo "   STAGING ENVIRONMENT:"
echo "   - Click on your app service"
echo "   - Go to Settings > Source"
echo "   - Click 'Connect GitHub'"
echo "   - Select repository: project-rulebook"
echo "   - Set branch: staging"
echo "   - Enable auto-deploy: ON"
echo "   - Set root directory: / (if different)"
echo ""
echo "   PRODUCTION ENVIRONMENT:"
echo "   - Click on your app service"
echo "   - Go to Settings > Source"
echo "   - Click 'Connect GitHub'"
echo "   - Select repository: project-rulebook"
echo "   - Set branch: main"
echo "   - Enable auto-deploy: ON"
echo "   - Set root directory: / (if different)"
echo ""
echo "4. Configure environment-specific domains:"
echo "   - Staging: Generate Railway domain (*.up.railway.app)"
echo "   - Production: Configure custom domain if needed"
echo ""

# Create GitHub Actions workflow for PR environments (optional)
echo "🤖 Creating GitHub Actions workflow for PR environments..."

mkdir -p .github/workflows

cat > .github/workflows/railway-pr-environments.yml << 'EOF'
name: Railway PR Environments

on:
  pull_request:
    types: [opened, closed]

env:
  RAILWAY_API_TOKEN: ${{ secrets.RAILWAY_API_TOKEN }}
  
jobs:
  pr_opened:
    if: github.event.action == 'opened'
    runs-on: ubuntu-latest
    container: ghcr.io/railwayapp/cli:latest
    steps:
      - name: Link to Railway project
        run: railway link --project ${{ secrets.RAILWAY_PROJECT_ID }} --environment staging
        
      - name: Create Railway Environment for PR
        run: |
          ENV_NAME="pr-${{ github.event.pull_request.number }}"
          railway environment new $ENV_NAME --copy staging
          echo "Created PR environment: $ENV_NAME"

  pr_closed:
    if: github.event.action == 'closed'
    runs-on: ubuntu-latest
    container: ghcr.io/railwayapp/cli:latest
    steps:
      - name: Link to Railway project
        run: railway link --project ${{ secrets.RAILWAY_PROJECT_ID }} --environment staging
        
      - name: Delete Railway Environment for PR
        run: |
          ENV_NAME="pr-${{ github.event.pull_request.number }}"
          railway environment delete $ENV_NAME || true
          echo "Deleted PR environment: $ENV_NAME"
EOF

echo "✅ GitHub Actions workflow created at .github/workflows/railway-pr-environments.yml"
echo ""
echo "🔐 Required GitHub Secrets (set in repository settings):"
echo "   - RAILWAY_API_TOKEN: Your Railway API token (get from Railway account settings)"
echo "   - RAILWAY_PROJECT_ID: Your Railway project ID"
echo ""

# Create deployment status script
cat > railway-deploy.sh << 'EOF'
#!/bin/bash

# Railway Deployment Script
# Usage: ./railway-deploy.sh [staging|production]

ENVIRONMENT=${1:-staging}

echo "🚀 Deploying to $ENVIRONMENT environment..."

# Switch to the specified environment
railway environment $ENVIRONMENT

# Deploy the application
railway up --detach

echo "✅ Deployment initiated for $ENVIRONMENT"
echo "📊 Check deployment status: railway status"
echo "📝 View logs: railway logs"
echo "🌐 Open in browser: railway open"
EOF

chmod +x railway-deploy.sh

echo "✅ Created deployment script: railway-deploy.sh"
echo ""
echo "🎯 Usage:"
echo "   Deploy to staging:    ./railway-deploy.sh staging"
echo "   Deploy to production: ./railway-deploy.sh production"
echo ""
echo "✅ GitHub integration setup completed!"