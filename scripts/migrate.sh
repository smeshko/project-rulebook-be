#!/bin/bash

# Railway Migration Script
# Runs database migrations before deployment

set -e

echo "🚀 Starting database migrations..."

# Run migrations
swift run App migrate --yes

echo "✅ Database migrations completed successfully"

# Optional: Run seed data (uncomment if needed)
# echo "📝 Running seed data..."
# swift run App seed
# echo "✅ Seed data completed"

echo "🎉 Migration script completed!"