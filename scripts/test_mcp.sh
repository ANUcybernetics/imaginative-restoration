#!/bin/bash

# MCP Server Test Script
# This script tests both ash_ai and tidewave MCP servers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
HOST="localhost"
PORT="4000"
ASH_AI_ENDPOINT="http://${HOST}:${PORT}/ash_ai/mcp"
TIDEWAVE_ENDPOINT="http://${HOST}:${PORT}/tidewave/mcp"

echo -e "${YELLOW}Testing MCP Servers for Imaginative Restoration${NC}"
echo "================================================"

# Function to test endpoint
test_endpoint() {
    local name=$1
    local url=$2

    echo -e "\n${YELLOW}Testing $name...${NC}"
    echo "URL: $url"

    # Test if endpoint responds
    if curl -s -f -H "Accept: application/json" "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $name endpoint is responding${NC}"

        # Try to get response content
        response=$(curl -s -H "Accept: application/json" "$url" 2>/dev/null || echo "")
        if [ ! -z "$response" ]; then
            echo "Response preview:"
            echo "$response" | head -c 200
            if [ ${#response} -gt 200 ]; then
                echo "..."
            fi
        fi
    else
        echo -e "${RED}✗ $name endpoint is not responding${NC}"
        return 1
    fi
}

# Function to test with mcp-proxy
test_with_proxy() {
    local name=$1
    local url=$2

    echo -e "\n${YELLOW}Testing $name with mcp-proxy...${NC}"

    if command -v mcp-proxy > /dev/null 2>&1; then
        echo "Found mcp-proxy in PATH"

        # Test basic connection
        if timeout 10s mcp-proxy "$url" --help > /dev/null 2>&1; then
            echo -e "${GREEN}✓ mcp-proxy can connect to $name${NC}"
        else
            echo -e "${RED}✗ mcp-proxy cannot connect to $name${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ mcp-proxy not found in PATH${NC}"
        echo "Please install mcp-proxy to test full MCP functionality"
        return 1
    fi
}

# Check if Phoenix server is running
echo -e "\n${YELLOW}Checking if Phoenix server is running...${NC}"
if curl -s -f "http://${HOST}:${PORT}" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Phoenix server is running on port $PORT${NC}"
else
    echo -e "${RED}✗ Phoenix server is not running on port $PORT${NC}"
    echo "Please start your Phoenix server with: mix phx.server"
    exit 1
fi

# Test Ash AI MCP Server
test_endpoint "Ash AI MCP Server" "$ASH_AI_ENDPOINT"
ash_ai_status=$?

# Test Tidewave MCP Server
test_endpoint "Tidewave MCP Server" "$TIDEWAVE_ENDPOINT"
tidewave_status=$?

# Test with mcp-proxy if available
echo -e "\n${YELLOW}Testing MCP Proxy Integration${NC}"
echo "=============================="

test_with_proxy "Ash AI" "$ASH_AI_ENDPOINT"
proxy_ash_ai_status=$?

test_with_proxy "Tidewave" "$TIDEWAVE_ENDPOINT"
proxy_tidewave_status=$?

# Summary
echo -e "\n${YELLOW}Test Summary${NC}"
echo "============"

if [ $ash_ai_status -eq 0 ]; then
    echo -e "${GREEN}✓ Ash AI MCP Server: Working${NC}"
else
    echo -e "${RED}✗ Ash AI MCP Server: Failed${NC}"
fi

if [ $tidewave_status -eq 0 ]; then
    echo -e "${GREEN}✓ Tidewave MCP Server: Working${NC}"
else
    echo -e "${RED}✗ Tidewave MCP Server: Failed${NC}"
fi

if [ $proxy_ash_ai_status -eq 0 ]; then
    echo -e "${GREEN}✓ MCP Proxy + Ash AI: Working${NC}"
else
    echo -e "${RED}✗ MCP Proxy + Ash AI: Failed${NC}"
fi

if [ $proxy_tidewave_status -eq 0 ]; then
    echo -e "${GREEN}✓ MCP Proxy + Tidewave: Working${NC}"
else
    echo -e "${RED}✗ MCP Proxy + Tidewave: Failed${NC}"
fi

# Final status
if [ $ash_ai_status -eq 0 ] && [ $tidewave_status -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All MCP servers are working!${NC}"
    echo -e "\nNext steps:"
    echo "1. Configure your MCP client (Zed, Claude Desktop, etc.)"
    echo "2. Use these endpoints with mcp-proxy:"
    echo "   - Ash AI: mcp-proxy $ASH_AI_ENDPOINT"
    echo "   - Tidewave: mcp-proxy $TIDEWAVE_ENDPOINT"
    exit 0
else
    echo -e "\n${RED}❌ Some MCP servers are not working${NC}"
    echo -e "\nTroubleshooting:"
    echo "1. Make sure your Phoenix server is running: mix phx.server"
    echo "2. Check the server logs for any errors"
    echo "3. Verify your configuration in router.ex and endpoint.ex"
    exit 1
fi
