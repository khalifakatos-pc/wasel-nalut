# Wasel Nalut Admin MCP Server

Official Model Context Protocol (MCP) Server for the **Wasel Nalut Platform (واصل نالوت)**.
Empowers **Hermes Agent** and MCP-compatible AI agents to manage stores, menus, drivers, settlements, and live analytics for the delivery network of Nalut, Libya.

## Quick Start

```bash
cd c:\Users\kalifa\Desktop\wasel-app\wasel-admin-mcp
npm start
```

## Documentation

Full Arabic step-by-step instructions and Hermes prompt examples are available in [HERMES_INSTRUCTIONS.md](./HERMES_INSTRUCTIONS.md).

## Configuration

Add to your MCP Client configuration (`mcp_config.json`):

```json
{
  "mcpServers": {
    "wasel-admin-mcp": {
      "command": "node",
      "args": [
        "c:\\Users\\kalifa\\Desktop\\wasel-app\\wasel-admin-mcp\\index.js"
      ]
    }
  }
}
```

## Features
- **14 Built-in MCP Tools** for complete CRUD operations on Stores, Products, and Captains.
- **Smart Presets**: Auto-generates starter menus (Pizza, Grocery, Pharmacy, Restaurant) on store creation.
- **Dual-Cloud Sync**: Simultaneously writes to Render Node.js backend and Supabase Cloud.
- **Direct Integration**: Seamless real-time coordination with all 4 Wasel Flutter Apps.
