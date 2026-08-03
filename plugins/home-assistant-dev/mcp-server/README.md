# Home Assistant Development MCP Server

An MCP (Model Context Protocol) server that connects Claude to Home Assistant instances for enhanced integration development.

## Features

### 🏠 Home Assistant Tools

| Tool              | Description                          |
| ----------------- | ------------------------------------ |
| `ha_connect`      | Connect to a Home Assistant instance |
| `ha_get_states`   | Query entity states with filtering   |
| `ha_get_services` | List available services              |
| `ha_call_service` | Call services (with safety controls) |
| `ha_get_devices`  | Query device registry                |
| `ha_get_logs`     | Fetch and analyze logs               |

### 📚 Documentation Tools

| Tool            | Description                           |
| --------------- | ------------------------------------- |
| `docs_search`   | Full-text search HA developer docs    |
| `docs_fetch`    | Fetch specific documentation pages    |
| `docs_examples` | Get code examples for common patterns |

### ✅ Validation Tools

| Tool                | Description                               |
| ------------------- | ----------------------------------------- |
| `validate_manifest` | Validate manifest.json for Core/HACS      |
| `validate_strings`  | Sync strings.json with config_flow.py     |
| `check_patterns`    | Detect 20+ anti-patterns and deprecations |

## Installation

This server ships pre-built with the `home-assistant-dev` Claude Code plugin and is registered automatically via the plugin's `.mcp.json` (`node dist/server.bundle.cjs`) — no separate install is required.

For standalone development, build and run it from this directory:

```bash
npm install
npm run build
node dist/server.bundle.cjs
```

## Configuration

### Claude Desktop

Add to your Claude Desktop configuration:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json` **Windows**: `%APPDATA%\Claude\claude_desktop_config.json` **Linux**: `~/.config/claude/claude_desktop_config.json`

```json
{
	"mcpServers": {
		"ha-dev": {
			"command": "node",
			"args": ["/absolute/path/to/mcp-server/dist/server.bundle.cjs"],
			"env": {
				"HA_DEV_MCP_URL": "http://192.168.1.100:8123",
				"HA_DEV_MCP_TOKEN": "your-long-lived-access-token"
			}
		}
	}
}
```

### Getting a Home Assistant Token

1. Go to your Home Assistant instance
2. Click your profile (bottom left)
3. Scroll to "Long-Lived Access Tokens"
4. Click "Create Token"
5. Give it a name (e.g., "Claude MCP")
6. Copy the token (it won't be shown again)

### Configuration File (Optional)

For more control, create `~/.config/ha-dev-mcp/config.json`. Configuration layers in this order: built-in defaults, this file, then environment variables. `HA_DEV_MCP_URL` and `HA_DEV_MCP_TOKEN` take precedence over the compatibility names `HA_URL` and `HA_TOKEN`.

```json
{
	"homeAssistant": {
		"url": "http://192.168.1.100:8123",
		"token": "your-token-here",
		"verifySsl": true
	},
	"safety": {
		"allowServiceCalls": false,
		"blockedServices": [
			"homeassistant.restart",
			"homeassistant.stop",
			"homeassistant.reload_all",
			"homeassistant.reload_core_config",
			"persistent_notification.dismiss_all",
			"system_log.clear",
			"recorder.purge"
		],
		"requireDryRun": true
	},
	"cache": { "statesTtlSeconds": 30 },
	"features": {
		"enableDocsTools": true,
		"enableHaTools": true,
		"enableValidationTools": true
	}
}
```

`blockedServices` is an array replacement, not an additive override. If you set it, include every service you want blocked. The three always-blocked services remain blocked regardless of this setting.

Environment settings also support `HA_DEV_MCP_VERIFY_SSL=false`, `HA_DEV_MCP_ALLOW_SERVICE_CALLS=true`, and feature opt-outs: `HA_DEV_MCP_DISABLE_HA_TOOLS=true`, `HA_DEV_MCP_DISABLE_DOCS_TOOLS=true`, and `HA_DEV_MCP_DISABLE_VALIDATION_TOOLS=true`.

## Usage Examples

### Connect and Query States

```text
Connect to my Home Assistant at http://192.168.1.100:8123
```

```text
Show me all sensor entities
```

```text
What's the state of light.living_room?
```

### Query Devices and Services

```text
List all devices from the hue integration
```

```text
What services are available for the light domain?
```

### Validate Integration Code

```text
Validate the manifest.json in /path/to/my_integration
```

```text
Check /path/to/my_integration for anti-patterns
```

### Search Documentation

```text
Search the HA docs for DataUpdateCoordinator
```

```text
Show me a full example of a config flow
```

## Safety Features

### Service Call Protection

The server includes multiple layers of protection for service calls:

1. **Disabled by Default**: `allowServiceCalls: false`
2. **Dry-Run Mode**: Validates without executing (default)
3. **Blocklist**: Always-blocked services and your configured `blockedServices` are refused. Other services can execute only after service calls are enabled and any dry-run requirement is satisfied; specifically dangerous services return a warning.
4. **Safe Domains**: The listed helper domains (`input_boolean`, `input_number`, `input_select`, `input_text`, `input_datetime`, `input_button`, `counter`, `timer`, and `persistent_notification`) bypass the dry-run requirement. They can execute with `dry_run: false` even when `requireDryRun` is enabled; always-blocked and configured services are still refused.

#### Always Blocked Services

- `homeassistant.stop`
- `hassio.host_shutdown`
- `hassio.host_reboot`

#### Blocked by Default

- `homeassistant.restart`
- `homeassistant.reload_all`
- `recorder.purge`

### To Enable Service Calls

Set in config file:

```json
{ "safety": { "allowServiceCalls": true, "requireDryRun": false } }
```

Or via environment:

```bash
HA_DEV_MCP_ALLOW_SERVICE_CALLS=true
```

### Token Security

- The server reads tokens from the tool call, environment, or optional config file; it does not create its own token store
- Tokens are not deliberately logged, and service-call previews redact sensitive data fields
- Config file should have restricted permissions: `chmod 600 config.json`

## Development

```bash
# From the plugin checkout
cd plugins/home-assistant-dev/mcp-server
npm install

# Build
npm run build

# Run locally
npm run dev

# Run tests
npm test

# Lint
npm run lint
```

## Architecture

```text
src/
├── index.ts          # MCP server entry point
├── config.ts         # Configuration loading
├── ha-client.ts      # Home Assistant WebSocket client
├── safety.ts         # Service call safety checker
├── docs-index.ts     # Documentation search index
├── types.ts          # TypeScript interfaces
└── tools/
    ├── ha-connect.ts
    ├── ha-states.ts
    ├── ha-services.ts
    ├── ha-call-service.ts
    ├── ha-devices.ts
    ├── ha-logs.ts
    ├── docs-search.ts
    ├── docs-fetch.ts
    ├── docs-examples.ts
    ├── validate-manifest.ts
    ├── validate-strings.ts
    └── check-patterns.ts
```

## Requirements

- Node.js 20 or later
- Home Assistant 2024.1.0 or later (for full compatibility)

## Troubleshooting

### Connection Failed

1. Check the URL is correct (include port 8123)
2. Verify the token is valid and not expired
3. Ensure Home Assistant is accessible from your machine
4. Check if SSL verification is causing issues (`verifySsl: false`)

### Service Call Blocked

1. Check if service calls are enabled in config
2. Verify the service isn't in the blocklist
3. Try with `dry_run: true` first to validate

### Tool Not Available

1. Check if the feature is enabled in config
2. For HA tools, ensure you're connected first

## License

MIT
