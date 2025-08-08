#!/bin/bash

echo "🚀 Roomies Backend - Comprehensive API Test Suite"
echo "================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

API_BASE="http://localhost:3000/api"
TOKEN=""
USER_ID=""
HOUSEHOLD_ID=""
EMAIL="test$(date +%s)@example.com"

# Function to make API calls and check status
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local expected_status=$4
    local description=$5
    local auth_header=""
    
    if [ ! -z "$TOKEN" ]; then
        auth_header="-H \"Authorization: Bearer $TOKEN\""
    fi
    
    echo -n "Testing: $description... "
    
    if [ -z "$data" ]; then
        response=$(eval "curl -s -w \"HTTPSTATUS:%{http_code}\" -X $method $auth_header \"$API_BASE$endpoint\"")
    else
        response=$(eval "curl -s -w \"HTTPSTATUS:%{http_code}\" -X $method $auth_header -H \"Content-Type: application/json\" -d '$data' \"$API_BASE$endpoint\"")
    fi
    
    status_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    body=$(echo "$response" | sed 's/HTTPSTATUS:[0-9]*$//')
    
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✅ PASS${NC} ($status_code)"
        if [[ "$body" == *"\"success\":true"* ]]; then
            # Extract useful data for later tests
            if [[ "$endpoint" == "/auth/register" || "$endpoint" == "/auth/login" ]]; then
                TOKEN=$(echo "$body" | jq -r '.data.token // empty')
                USER_ID=$(echo "$body" | jq -r '.data.user.id // empty')
            elif [[ "$endpoint" == "/households" && "$method" == "POST" ]]; then
                HOUSEHOLD_ID=$(echo "$body" | jq -r '.data.id // empty')
            fi
        fi
    else
        echo -e "${RED}❌ FAIL${NC} (Expected: $expected_status, Got: $status_code)"
        if [ ! -z "$body" ]; then
            echo "Response: $(echo "$body" | jq '.' 2>/dev/null || echo "$body")"
        fi
    fi
}

# Wait for server to start
echo "⏳ Waiting for server to start..."
sleep 5

echo -e "\n${BLUE}1. Health Check${NC}"
test_endpoint "GET" "/../../health" "" "200" "Health endpoint"

echo -e "\n${BLUE}2. Authentication Tests${NC}"
test_endpoint "POST" "/auth/register" '{"email":"'$EMAIL'","password":"Testpass123","name":"Test User"}' "201" "User registration"
test_endpoint "POST" "/auth/login" '{"email":"'$EMAIL'","password":"Testpass123"}' "200" "User login"
test_endpoint "GET" "/auth/me" "" "200" "Get current user (authenticated)"
test_endpoint "POST" "/auth/register" '{"email":"'$EMAIL'","password":"Testpass123","name":"Test User"}' "409" "Duplicate user registration (should fail)"

echo -e "\n${BLUE}3. User Profile Tests${NC}"
test_endpoint "GET" "/users/profile" "" "200" "Get user profile"
test_endpoint "PUT" "/users/profile" '{"name":"Updated Test User","avatarColor":"green"}' "200" "Update user profile"
test_endpoint "GET" "/users/statistics" "" "200" "Get user statistics"
test_endpoint "GET" "/users/badges" "" "200" "Get user badges"

echo -e "\n${BLUE}4. Household Management Tests${NC}"
test_endpoint "POST" "/households" '{"name":"Test Household","description":"A test household for API testing"}' "201" "Create household"
test_endpoint "GET" "/households/current" "" "200" "Get current household"
# Fallback: capture household ID from current household if not set by creation
if [ -z "$HOUSEHOLD_ID" ] && [ ! -z "$TOKEN" ]; then
    body=$(curl -s -H "Authorization: Bearer $TOKEN" "$API_BASE/households/current")
    HOUSEHOLD_ID=$(echo "$body" | jq -r '.data.id // empty')
fi
test_endpoint "POST" "/households" '{"name":"Another Household"}' "409" "Create second household (should fail - user already in household)"

if [ ! -z "$HOUSEHOLD_ID" ]; then
    test_endpoint "GET" "/households/$HOUSEHOLD_ID/members" "" "200" "Get household members"
    test_endpoint "PUT" "/households/$HOUSEHOLD_ID" '{"name":"Updated Test Household","description":"Updated description"}' "200" "Update household"
fi

echo -e "\n${BLUE}5. Task Management Tests${NC}"
if [ ! -z "$HOUSEHOLD_ID" ]; then
    test_endpoint "POST" "/tasks" '{"title":"Test Task","description":"A test task","priority":"medium","points":10,"householdId":"'$HOUSEHOLD_ID'"}' "201" "Create task"
    test_endpoint "GET" "/tasks/household/$HOUSEHOLD_ID" "" "200" "Get household tasks"
    test_endpoint "GET" "/tasks/household/$HOUSEHOLD_ID?completed=false&assignedToMe=true" "" "200" "Get filtered tasks"
else
    echo "⚠️  Skipping task tests - no household ID available"
fi

echo -e "\n${BLUE}6. Error Handling Tests${NC}"
TOKEN=""
test_endpoint "GET" "/auth/me" "" "401" "Unauthenticated request (after token reset)"
test_endpoint "GET" "/users/profile" "" "401" "Protected route without auth"
test_endpoint "POST" "/auth/login" '{"email":"wrong@email.com","password":"wrongpass"}' "401" "Invalid login"
test_endpoint "POST" "/households" '{"name":"A"}' "401" "Unauthenticated create household"

echo -e "\n${BLUE}7. Validation Tests${NC}"
# Re-login for validation tests
test_endpoint "POST" "/auth/login" '{"email":"'$EMAIL'","password":"Testpass123"}' "200" "Re-login for validation tests"
test_endpoint "POST" "/auth/register" '{}' "400" "Empty registration data"
test_endpoint "POST" "/households" '{}' "400" "Empty household data"
if [ ! -z "$HOUSEHOLD_ID" ]; then
    test_endpoint "POST" "/tasks" '{"householdId":"'$HOUSEHOLD_ID'"}' "400" "Create task without title"
fi

echo -e "\n${BLUE}8. Database Validation${NC}"
echo "📊 Checking database records..."
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"
user_count=$(psql -d roomies_dev -t -c "SELECT COUNT(*) FROM users;" | tr -d ' ')
household_count=$(psql -d roomies_dev -t -c "SELECT COUNT(*) FROM households;" | tr -d ' ')
badge_count=$(psql -d roomies_dev -t -c "SELECT COUNT(*) FROM badges;" | tr -d ' ')

echo "👥 Users in database: $user_count"
echo "🏠 Households in database: $household_count"
echo "🏆 Badges in database: $badge_count"

# Cleanup
echo -e "\n${BLUE}9. Cleanup${NC}"
jobs -p | xargs kill 2>/dev/null || echo "No background jobs to kill"

echo -e "\n${GREEN}🎉 API Test Suite Complete!${NC}"
echo "If most tests passed, your backend is working correctly!"
echo "Check the detailed output above for any failures."
