# MCP (Model Context Protocol) Server Setup

This document explains how to set up and use the MCP servers for both `ash_ai`
and `tidewave` in your Imaginative Restoration application.

## Prerequisites

- Ensure you have `mcp-proxy` installed and available in your `$PATH`
- Your Phoenix application should be running on `http://localhost:4000`

## What's Been Configured

### 1. Ash AI MCP Server

The Ash AI MCP server exposes your Ash domain actions as tools that can be used
by AI assistants:

**Available Tools:**

- `read_sketches` - Read sketch records
- `create_sketch` - Create new sketches
- `crop_and_label_sketch` - Process sketch cropping and labeling
- `process_sketch` - Process sketches through AI pipeline
- `read_prompts` - Read prompt records
- `get_latest_prompt` - Get the latest prompt

**Endpoints:**

- Development: `http://localhost:4000/ash_ai/mcp` (via dev plug)
- Production: `http://localhost:4000/ash_ai/mcp` (via router)

### 2. Tidewave MCP Server

The Tidewave MCP server provides database and application introspection tools.

**Endpoint:**

- `http://localhost:4000/tidewave/mcp`

## Setting Up MCP Clients

### For Zed Editor

1. Open Zed and go to the Assistant tab
2. Click the `⋯` icon at the top right
3. Select "Add Custom Server"
4. Configure each server:

**Ash AI Server:**

```
Name: Imaginative Restoration AI
Command: mcp-proxy http://localhost:4000/ash_ai/mcp
```

**Tidewave Server:**

```
Name: Imaginative Restoration DB
Command: mcp-proxy http://localhost:4000/tidewave/mcp
```

### For Claude Desktop

Add to your Claude Desktop configuration file:

**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "imaginative-restoration-ai": {
      "command": "mcp-proxy",
      "args": ["http://localhost:4000/ash_ai/mcp"]
    },
    "imaginative-restoration-db": {
      "command": "mcp-proxy",
      "args": ["http://localhost:4000/tidewave/mcp"]
    }
  }
}
```

### For Other MCP-Compatible Tools

Use the following endpoints with `mcp-proxy`:

- Ash AI: `mcp-proxy http://localhost:4000/ash_ai/mcp`
- Tidewave: `mcp-proxy http://localhost:4000/tidewave/mcp`

## Quick Start with Dev Script

The easiest way to get started is using the provided development script:

```bash
# Start Phoenix server with both MCP servers
./dev.sh

# Start with mcp-proxy instances (optional)
./dev.sh --proxy

# Show verbose output
./dev.sh --verbose

# Get help
./dev.sh --help
```

The dev script will:

- Start Phoenix server with proper environment variables
- Test both MCP endpoints
- Optionally start mcp-proxy instances
- Handle cleanup when you stop it (Ctrl+C)
- Show helpful usage information

## Manual Testing

If you prefer to test manually:

1. Start your Phoenix application:

   ```bash
   AUTH_USERNAME=admin AUTH_PASSWORD=password mix phx.server
   ```

2. Test the endpoints directly:

   ```bash
   # Test Ash AI MCP
   curl -u admin:password http://localhost:4000/ash_ai/mcp

   # Test Tidewave MCP
   curl -u admin:password http://localhost:4000/tidewave/mcp
   ```

3. Test with mcp-proxy:

   ```bash
   # Test Ash AI via proxy
   mcp-proxy http://localhost:4000/ash_ai/mcp

   # Test Tidewave via proxy
   mcp-proxy http://localhost:4000/tidewave/mcp
   ```

4. Or use the simple test script:

   ```bash
   ./test_mcp_simple.sh
   ```

## Environment Variables

Make sure you have the required authentication environment variables set:

- `AUTH_USERNAME` - Basic auth username
- `AUTH_PASSWORD` - Basic auth password

Note: The MCP endpoints bypass the web authentication but use the same
application context.

## Troubleshooting

### MCP Server Not Responding

- Ensure your Phoenix app is running on port 4000
- Check that `mcp-proxy` is installed and in your PATH
- Verify the endpoints return JSON responses

### Authentication Issues

- MCP endpoints are configured to bypass web authentication
- If you need authenticated MCP access, you can modify the `:mcp` pipeline in
  the router

### Tool Not Available

- Check that your Ash domain is properly configured with the `AshAi` extension
- Verify tools are listed in the router configuration
- Ensure your resources and actions are properly defined

### Protocol Version Issues

- The configuration uses protocol version "2024-11-05" for compatibility
- Some newer MCP clients may require protocol version "2025-03-26"
- Update the `protocol_version_statement` in both the endpoint and router if
  needed

## Advanced Configuration

### Adding More Tools

To expose additional Ash actions as MCP tools:

1. Add them to your domain's `tools` block:

   ```elixir
   tools do
     tool(:my_new_tool, MyResource, :my_action)
   end
   ```

2. Add the tool name to the router configuration:
   ```elixir
   tools: [
     # existing tools...
     :my_new_tool
   ]
   ```

### Custom Authentication

To add authentication to MCP endpoints, modify the `:mcp` pipeline:

```elixir
pipeline :mcp do
  plug :accepts, ["json"]
  plug :custom_mcp_auth  # Add your auth plug here
end
```

### Production Deployment

For production deployments:

- Update the URLs to use your production domain
- Consider adding rate limiting to MCP endpoints
- Set up proper monitoring and logging
- Review security implications of exposed tools

## Development Scripts

This project includes several helper scripts:

### `./dev.sh` - Main Development Script

Start the complete MCP development environment:

```bash
# Basic start
./dev.sh

# With mcp-proxy instances
./dev.sh --proxy

# With verbose output
./dev.sh --verbose
```

### `./test_mcp_simple.sh` - Quick Test

Test that both MCP servers are working:

```bash
./test_mcp_simple.sh
```

### `./scripts/test_mcp.sh` - Comprehensive Test

Full test suite including mcp-proxy integration:

```bash
./scripts/test_mcp.sh
```

## Useful Commands

```bash
# Install dependencies
mix deps.get

# Start development server manually
AUTH_USERNAME=admin AUTH_PASSWORD=password mix phx.server

# Test MCP endpoints
curl -u admin:password -H "Accept: application/json" http://localhost:4000/ash_ai/mcp
curl -u admin:password -H "Accept: application/json" http://localhost:4000/tidewave/mcp

# Check available tools (requires running server)
mcp-proxy http://localhost:4000/ash_ai/mcp --list-tools
```
