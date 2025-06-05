#!/bin/bash

# Simple MCP Test Script
# Quick test of both ash_ai and tidewave MCP servers

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
HOST="localhost"
PORT="4000"
AUTH_USERNAME=${AUTH_USERNAME:-"admin"}
AUTH_PASSWORD=${AUTH_PASSWORD:-"password"}

ASH_AI_ENDPOINT="http://${HOST}:${PORT}/ash_ai/mcp"
TIDEWAVE_ENDPOINT="http://${HOST}:${PORT}/tidewave/mcp"

echo -e "${YELLOW}Testing MCP Servers${NC}"
echo "==================="

# Function to test endpoint
test_endpoint() {
    local name=$1
    local url=$2

    echo -n "Testing $name... "

    if curl -s -f -u "$AUTH_USERNAME:$AUTH_PASSWORD" -H "Accept: application/json" "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Working${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed${NC}"
        return 1
    fi
}

# Check if server is running
echo -n "Checking Phoenix server... "
if curl -s -f -u "$AUTH_USERNAME:$AUTH_PASSWORD" "http://$HOST:$PORT" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Running${NC}"
else
    echo -e "${RED}❌ Not running${NC}"
    echo "Start with: ./dev.sh"
    exit 1
fi

# Test endpoints
test_endpoint "Ash AI MCP" "$ASH_AI_ENDPOINT"
ash_ai_status=$?

test_endpoint "Tidewave MCP" "$TIDEWAVE_ENDPOINT"
tidewave_status=$?

# Summary
echo ""
if [ $ash_ai_status -eq 0 ] && [ $tidewave_status -eq 0 ]; then
    echo -e "${GREEN}🎉 All MCP servers are working!${NC}"
    echo ""
    echo "Use with mcp-proxy:"
    echo "  mcp-proxy $ASH_AI_ENDPOINT"
    echo "  mcp-proxy $TIDEWAVE_ENDPOINT"
else
    echo -e "${RED}❌ Some MCP servers are not working${NC}"
    exit 1
fi
