#!/bin/bash

echo "🚀 Starting Roomies Backend Test Suite..."
echo "======================================="

# Set PostgreSQL path
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"

# Kill any existing processes on port 3000
echo "1️⃣  Cleaning up existing processes..."
lsof -ti:3000 | xargs kill -9 2>/dev/null || echo "   Port 3000 is free"

# Start the server in background
echo ""
echo "2️⃣  Starting backend server..."
cd /Users/Max/Roomies/roomies-backend
npm run dev &
SERVER_PID=$!

# Wait for server to start
echo "   Waiting for server to start..."
sleep 5

# Test server health
echo ""
echo "3️⃣  Testing server health..."
curl -s http://localhost:3000/health | jq '.' || echo "   ❌ Health check failed"

# Test auth endpoint (should return validation error)
echo ""
echo "4️⃣  Testing authentication endpoints..."
echo "   Testing registration (should return 400 - validation error):"
curl -s -X POST http://localhost:3000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.' || echo "   ❌ Auth test failed"

# Test protected endpoint (should return 401 - unauthorized)
echo ""
echo "5️⃣  Testing protected endpoints..."
echo "   Testing user profile (should return 401 - unauthorized):"
curl -s http://localhost:3000/api/users/profile | jq '.' || echo "   ❌ Protected endpoint test failed"

echo ""
echo "6️⃣  Testing database connection..."
echo "   Checking if tables exist:"
psql -d roomies_dev -c "SELECT tablename FROM pg_tables WHERE schemaname = 'public';" | head -15

echo ""
echo "7️⃣  Checking default badges..."
psql -d roomies_dev -c "SELECT name, description FROM badges;" | head -10

# Clean up
echo ""
echo "8️⃣  Cleaning up..."
kill $SERVER_PID 2>/dev/null
sleep 2
lsof -ti:3000 | xargs kill -9 2>/dev/null || echo "   Server stopped"

echo ""
echo "✅ Backend test suite completed!"
echo "🎉 If you saw JSON responses above, the backend is working correctly!"
