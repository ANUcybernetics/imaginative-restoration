#!/bin/bash

# Imaginative Restoration MCP Development Script
# This script starts Phoenix server with both ash_ai and tidewave MCP servers
# and optionally starts mcp-proxy for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HOST="localhost"
PORT="4000"
ASH_AI_ENDPOINT="http://${HOST}:${PORT}/ash_ai/mcp"
TIDEWAVE_ENDPOINT="http://${HOST}:${PORT}/tidewave/mcp"

# Default credentials (can be overridden with environment variables)
AUTH_USERNAME=${AUTH_USERNAME:-"admin"}
AUTH_PASSWORD=${AUTH_PASSWORD:-"password"}

# PID files for cleanup
PHOENIX_PID_FILE="/tmp/imaginative_restoration_phoenix.pid"
MCP_PROXY_ASH_PID_FILE="/tmp/imaginative_restoration_mcp_ash.pid"
MCP_PROXY_TIDEWAVE_PID_FILE="/tmp/imaginative_restoration_mcp_tidewave.pid"

echo -e "${BLUE}🚀 Imaginative Restoration MCP Development Environment${NC}"
echo "======================================================="

# Function to cleanup processes
cleanup() {
    echo -e "\n${YELLOW}🧹 Cleaning up processes...${NC}"

    # Kill Phoenix server
    if [ -f "$PHOENIX_PID_FILE" ]; then
        PHOENIX_PID=$(cat "$PHOENIX_PID_FILE")
        if kill -0 "$PHOENIX_PID" 2>/dev/null; then
            echo "Stopping Phoenix server (PID: $PHOENIX_PID)"
            kill "$PHOENIX_PID" 2>/dev/null || true
            sleep 2
            kill -9 "$PHOENIX_PID" 2>/dev/null || true
        fi
        rm -f "$PHOENIX_PID_FILE"
    fi

    # Kill mcp-proxy processes
    if [ -f "$MCP_PROXY_ASH_PID_FILE" ]; then
        MCP_ASH_PID=$(cat "$MCP_PROXY_ASH_PID_FILE")
        if kill -0 "$MCP_ASH_PID" 2>/dev/null; then
            echo "Stopping mcp-proxy for ash_ai (PID: $MCP_ASH_PID)"
            kill "$MCP_ASH_PID" 2>/dev/null || true
        fi
        rm -f "$MCP_PROXY_ASH_PID_FILE"
    fi

    if [ -f "$MCP_PROXY_TIDEWAVE_PID_FILE" ]; then
        MCP_TIDEWAVE_PID=$(cat "$MCP_PROXY_TIDEWAVE_PID_FILE")
        if kill -0 "$MCP_TIDEWAVE_PID" 2>/dev/null; then
            echo "Stopping mcp-proxy for tidewave (PID: $MCP_TIDEWAVE_PID)"
            kill "$MCP_TIDEWAVE_PID" 2>/dev/null || true
        fi
        rm -f "$MCP_PROXY_TIDEWAVE_PID_FILE"
    fi

    # Kill any remaining beam processes for this project
    pkill -f "imaginative_restoration" 2>/dev/null || true

    echo -e "${GREEN}✅ Cleanup complete!${NC}"
}

# Function to check if a port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is free
    fi
}

# Function to wait for server to be ready
wait_for_server() {
    local url=$1
    local name=$2
    local max_attempts=30
    local attempt=1

    echo -n "Waiting for $name to be ready"
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f -u "$AUTH_USERNAME:$AUTH_PASSWORD" "$url" > /dev/null 2>&1; then
            echo -e " ${GREEN}✅${NC}"
            return 0
        fi
        echo -n "."
        sleep 1
        attempt=$((attempt + 1))
    done

    echo -e " ${RED}❌${NC}"
    echo -e "${RED}Failed to connect to $name after $max_attempts attempts${NC}"
    return 1
}

# Function to start mcp-proxy
start_mcp_proxy() {
    local endpoint=$1
    local name=$2
    local pid_file=$3

    if command -v mcp-proxy > /dev/null 2>&1; then
        echo "Starting mcp-proxy for $name..."
        mcp-proxy "$endpoint" > "/tmp/mcp_${name}.log" 2>&1 &
        echo $! > "$pid_file"
        echo -e "${GREEN}✅ mcp-proxy for $name started (PID: $!)${NC}"
        echo "   Log file: /tmp/mcp_${name}.log"
    else
        echo -e "${YELLOW}⚠️  mcp-proxy not found in PATH - skipping proxy for $name${NC}"
        echo "   Install with: cargo install mcp-proxy"
    fi
}

# Trap cleanup function on script exit
trap cleanup EXIT INT TERM

# Check if port is already in use
if check_port $PORT; then
    echo -e "${YELLOW}⚠️  Port $PORT is already in use${NC}"
    echo "Stopping existing processes..."
    cleanup
    sleep 2
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --help     Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  AUTH_USERNAME  Authentication username (default: admin)"
            echo "  AUTH_PASSWORD  Authentication password (default: password)"
            echo ""
            echo "MCP Endpoints:"
            echo "  Ash AI:    $ASH_AI_ENDPOINT"
            echo "  Tidewave:  $TIDEWAVE_ENDPOINT"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}Configuration:${NC}"
echo "  Host: $HOST"
echo "  Port: $PORT"
echo "  Auth: $AUTH_USERNAME:$AUTH_PASSWORD"
echo "  Ash AI MCP: $ASH_AI_ENDPOINT"
echo "  Tidewave MCP: $TIDEWAVE_ENDPOINT"
echo ""

# Start Phoenix server
echo -e "${YELLOW}🔥 Starting Phoenix server...${NC}"
export AUTH_USERNAME="$AUTH_USERNAME"
export AUTH_PASSWORD="$AUTH_PASSWORD"

mix phx.server &

PHOENIX_PID=$!
echo "$PHOENIX_PID" > "$PHOENIX_PID_FILE"
echo -e "${GREEN}✅ Phoenix server started (PID: $PHOENIX_PID)${NC}"

# Wait for Phoenix server to be ready
if ! wait_for_server "http://$HOST:$PORT" "Phoenix server"; then
    echo -e "${RED}❌ Phoenix server failed to start properly${NC}"
    exit 1
fi

# Start mcp-proxy instances
echo -e "\n${YELLOW}🔗 Starting mcp-proxy instances...${NC}"
start_mcp_proxy "$ASH_AI_ENDPOINT" "ash_ai" "$MCP_PROXY_ASH_PID_FILE"
start_mcp_proxy "$TIDEWAVE_ENDPOINT" "tidewave" "$MCP_PROXY_TIDEWAVE_PID_FILE"

# Show status and usage information
echo -e "\n${GREEN}🎉 Development environment is ready!${NC}"
echo "========================================"
echo ""
echo -e "${BLUE}Available MCP Servers:${NC}"
echo "  📊 Ash AI MCP:    $ASH_AI_ENDPOINT"
echo "  🌊 Tidewave MCP:  $TIDEWAVE_ENDPOINT"
echo ""

echo -e "${BLUE}MCP Proxy Commands:${NC}"
echo "  For Ash AI:    mcp-proxy $ASH_AI_ENDPOINT"
echo "  For Tidewave:  mcp-proxy $TIDEWAVE_ENDPOINT"
echo ""

echo -e "${BLUE}Next Steps:${NC}"
echo "1. Configure your MCP client (Zed, Claude Desktop, etc.)"
echo "2. Use the endpoints above with your MCP client"
echo "3. Test with: curl -H 'Accept: application/json' <endpoint>"
echo ""
echo -e "${BLUE}Available Tools (Ash AI):${NC}"
echo "  • read_sketches - Read sketch records"
echo "  • create_sketch - Create new sketch"
echo "  • crop_and_label_sketch - Process sketch cropping and labeling"
echo "  • process_sketch - Process sketch with AI"
echo "  • read_prompts - Read prompt templates"
echo "  • get_latest_prompt - Get the latest prompt template"
echo ""
echo -e "${BLUE}Log Files:${NC}"
echo "  Ash AI Proxy: /tmp/mcp_ash_ai.log"
echo "  Tidewave Proxy: /tmp/mcp_tidewave.log"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop all services and clean up${NC}"

# Keep the script running until interrupted
while true; do
    sleep 1

    # Check if Phoenix server is still running
    if ! kill -0 "$PHOENIX_PID" 2>/dev/null; then
        echo -e "\n${RED}❌ Phoenix server has stopped unexpectedly${NC}"
        exit 1
    fi
done
