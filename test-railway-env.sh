#!/bin/bash

# Test Railway environment variables locally
# This script simulates Railway's environment to test database connectivity

echo "Testing Railway environment variables locally..."

# Set Railway environment variables
export DATABASE_URL="postgresql://postgres:DfftqqmSAqhVdYkPpMHwfdDWUUsyBTBi@postgres.railway.internal:5432/railway"
export REDIS_URL="redis://default:BOVvPoizpBBmssTwVqShIxONFqudXifC@redis.railway.internal:6379"
export BREVO_API_KEY="brevo_api_key"
export BREVO_URL="https://api.brevo.com"
export OPENAI_KEY="open_ai_key"
export JWT_KEY="development_jwt_secret_key_minimum_32_characters_required_for_security"
export BASE_URL="https://project-rulebook.up.railway.app"
export APPLICATION_IDENTIFIER="com.tsonev.project-rulebook"
export CORS_ALLOWED_ORIGINS="https://project-rulebook.up.railway.app"

# AWS Configuration (required by ProductionConfiguration)
export AWS_ACCESS_KEY="dev_access_key"
export AWS_SECRET_ACCESS_KEY="dev_secret_key"
export AWS_REGION="us-west-2"
export AWS_S3_BUCKET_NAME="dev-bucket"

# APNS Configuration (required by ProductionConfiguration)
export APNS_KEY="dev_apns_key"
export APNS_PRIVATE_KEY="dev_private_key"
export APNS_TEAM_ID="DEV_TEAM_ID"

# Railway system variables
export RAILWAY_ENVIRONMENT="staging"
export RAILWAY_PROJECT_NAME="project-rulebook"
export RAILWAY_SERVICE_NAME="project-rulebook"

# Redis configuration from Railway
export REDIS_COMMAND_TIMEOUT="10.0"
export REDIS_CONNECTION_TIMEOUT="5.0" 
export REDIS_ENABLE_LOGGING="true"
export REDIS_POOL_SIZE="5"

# Override the Vapor environment to ensure we use ProductionConfiguration
# Vapor looks for these environment variables in this order: VAPOR_ENV, ENVIRONMENT, ENV
export VAPOR_ENV="staging"

echo "Environment variables set. Testing application startup..."
echo "VAPOR_ENV: ${VAPOR_ENV}"
echo "DATABASE_URL: ${DATABASE_URL:0:30}..."
echo "REDIS_URL: ${REDIS_URL:0:30}..."

# Test that the DATABASE_URL can be parsed
echo "Testing DATABASE_URL parsing..."
echo "URL: postgresql://postgres:DfftqqmSAqhVdYkPpMHwfdDWUUsyBTBi@postgres.railway.internal:5432/railway"

# Try to start the application with Railway environment
echo "Starting application with Railway configuration..."
swift run App serve --hostname 0.0.0.0 --port 8080