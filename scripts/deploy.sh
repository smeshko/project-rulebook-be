#!/bin/bash

# Railway Deployment Script
# Handles deployment to Railway with proper checks

set -e

echo "🚀 Starting Railway deployment..."

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI is not installed. Please run: npm install -g @railway/cli"
    exit 1
fi

# Check if we're logged in to Railway
if ! railway whoami &> /dev/null; then
    echo "❌ Not logged in to Railway. Please run: railway login"
    exit 1
fi

# Build and test locally first
echo "🔨 Building application locally..."
swift build

echo "🧪 Running tests..."
swift test

echo "🚀 Deploying to Railway..."
railway up

echo "🏥 Checking health endpoint..."
sleep 10  # Wait for deployment

# Get the Railway public domain
DOMAIN=$(railway variables get RAILWAY_PUBLIC_DOMAIN)
if [ -n "$DOMAIN" ]; then
    echo "📊 Testing health endpoint at https://$DOMAIN/health"
    curl -f "https://$DOMAIN/health" || echo "⚠️ Health check failed - deployment may still be starting"
else
    echo "⚠️ Could not retrieve Railway domain - check deployment manually"
fi

echo "✅ Deployment script completed!"