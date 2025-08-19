#!/bin/bash

# Railway Multi-Environment Setup Script for project-rulebook
# This script sets up staging and production environments with PostgreSQL and Redis

set -e

echo "🚀 Setting up Railway multi-environment deployment for project-rulebook"

# Check if railway CLI is available
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI is not installed. Please install it first:"
    echo "curl -fsSL https://railway.app/install.sh | sh"
    exit 1
fi

# Check if user is logged in
if ! railway whoami &> /dev/null; then
    echo "❌ Not logged into Railway. Please run 'railway login' first"
    exit 1
fi

echo "✅ Railway CLI is ready"

# Create new Railway project
echo "📁 Creating Railway project..."
railway new "project-rulebook" --name "project-rulebook"

# Link to the project
echo "🔗 Linking project to current directory..."
railway link

# Create staging environment
echo "🏗️ Creating staging environment..."
railway environment new staging

# Create production environment
echo "🏭 Creating production environment..."
railway environment new production

# Switch to staging environment and set up services
echo "⚙️ Setting up staging environment..."
railway environment staging

# Add PostgreSQL to staging
echo "🐘 Adding PostgreSQL to staging..."
railway add --database postgres

# Add Redis to staging
echo "🟥 Adding Redis to staging..."
railway add --database redis

# Add main app service to staging
echo "📱 Adding main app service to staging..."
railway add

# Set staging environment variables
echo "🔧 Setting staging environment variables..."
railway variables set DATABASE_URL='${{Postgres.DATABASE_URL}}'
railway variables set REDIS_URL='${{Redis.REDIS_URL}}'
railway variables set ENVIRONMENT=staging
railway variables set LOG_LEVEL=debug

# Switch to production environment and set up services
echo "⚙️ Setting up production environment..."
railway environment production

# Add PostgreSQL to production
echo "🐘 Adding PostgreSQL to production..."
railway add --database postgres

# Add Redis to production
echo "🟥 Adding Redis to production..."
railway add --database redis

# Add main app service to production
echo "📱 Adding main app service to production..."
railway add

# Set production environment variables
echo "🔧 Setting production environment variables..."
railway variables set DATABASE_URL='${{Postgres.DATABASE_URL}}'
railway variables set REDIS_URL='${{Redis.REDIS_URL}}'
railway variables set ENVIRONMENT=production
railway variables set LOG_LEVEL=info

echo "✅ Railway multi-environment setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Set up GitHub integration for automatic deployments"
echo "2. Configure additional environment variables as needed"
echo "3. Deploy to staging: railway up --environment staging"
echo "4. Deploy to production: railway up --environment production"
echo ""
echo "🌐 Access your Railway dashboard at: https://railway.app/dashboard"