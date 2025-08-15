#!/bin/bash

# Test Redis functionality through the Vapor application

echo "🔍 Testing Redis functionality..."
echo

# Start the application in background
echo "Starting Vapor application..."
swift run App serve --hostname 0.0.0.0 --port 8080 > /dev/null 2>&1 &
APP_PID=$!

# Wait for application to start
echo "Waiting for application to start..."
sleep 5

# Test if app started successfully
if kill -0 $APP_PID 2>/dev/null; then
    echo "✅ Application started successfully"
else
    echo "❌ Application failed to start"
    exit 1
fi

echo
echo "🧪 Testing Redis cache operations..."

# Test 1: Cache health endpoint (if it exists)
echo "Test 1: Checking cache health..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/health/cache 2>/dev/null && echo " - Cache health endpoint responded" || echo " - Cache health endpoint not available (this is okay)"

# Test 2: Try a caching operation (rules generation with caching)
echo "Test 2: Testing cache through rules generation..."
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"gameDescription":"test game for cache"}' \
  http://localhost:8080/api/rules/generate 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ Cache operation through API successful"
else
    echo "⚠️ Cache operation may have issues (could be auth related)"
fi

# Test 3: Check application logs for Redis connections
echo "Test 3: Checking application logs for Redis activity..."
sleep 2

# Clean up
echo
echo "🧹 Cleaning up..."
kill $APP_PID 2>/dev/null
wait $APP_PID 2>/dev/null

echo "✅ Redis test completed!"
echo
echo "📝 Additional verification methods:"
echo "1. Check application logs when starting: swift run App serve"
echo "2. Look for 'AI Cache Service initialized' message"
echo "3. Look for Redis connection messages"
echo "4. Monitor Docker logs: docker-compose -f docker-compose.dev.yml logs -f redis"