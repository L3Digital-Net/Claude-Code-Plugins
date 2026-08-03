---
title: Plugin Development Guide
category: development
target_platform: linux
audience: ai_agent
keywords: [plugins, skills, agents, hooks, mcp, development]
---

# Plugin Development

## Overview

**Plugin Types:**

- Skills: Domain knowledge and workflows
- Agents: Specialized subprocesses with tool restrictions
- Hooks: Lifecycle event handlers
- MCP Servers: External tool integrations
- LSP Servers: Language protocol integrations

**Architecture Comparison:**

| Component  | Location    | Namespace         | Scope               |
| ---------- | ----------- | ----------------- | ------------------- |
| Standalone | `.claude/`  | Global `/command` | Project-only        |
| Plugin     | Plugin root | `/plugin:command` | Shareable/versioned |

## Quick Start

### Minimum Viable Plugin

```bash
mkdir -p my-plugin/.claude-plugin
cd my-plugin
```

**Optional `plugin.json`:**

```json
{ "name": "my-plugin", "version": "1.0.0", "description": "Plugin description" }
```

**Directory structure:**

```text
my-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── example/
│       └── SKILL.md
└── commands/
    └── hello.md
```

### Testing

```bash
claude --plugin-dir ./my-plugin

# In session:
/my-plugin:hello
/help  # List all commands
```

## Prerequisites

```bash
# Verify Claude Code installation
claude --version
```

## Plugin Manifest Schema

`plugin.json` is optional. Without it, Claude Code discovers components in their default plugin-root locations and derives the plugin name from the directory. When present, `name` is required.

**Common fields (`.claude-plugin/plugin.json`):**

```jsonc
{
	"name": "plugin-identifier", // lowercase-hyphenated
	"displayName": "Plugin Identifier",
	"version": "1.0.0",
	"description": "Brief description",
	"repository": "https://github.com/example/my-plugin",
	"license": "MIT",
	"keywords": ["example"],
	"defaultEnabled": true,
}
```

`author` and `homepage` are also supported metadata. Unknown top-level fields warn by default; `claude plugin validate --strict` makes them errors. See the [official manifest schema](https://code.claude.com/docs/en/plugins-reference#plugin-manifest-schema) for component-path fields. MCP and LSP can use plugin-root sidecars (`.mcp.json`, `.lsp.json`).

## Component Types

### Commands

**Location:** `commands/*.md` **Format:** Markdown files with optional YAML frontmatter **Invocation:** `/plugin-name:command-name`

```markdown
---
description: Command description
---

Command instructions using $ARGUMENTS placeholder for user input.
```

### Skills

**Location:** `skills/*/SKILL.md` **Format:** Folder per skill with SKILL.md file **Invocation:** Auto-invoked by AI based on context

```yaml
---
name: skill-name
description: When to use this skill
---
Skill implementation instructions.
```

See [skills.md](../skills.md) for complete reference.

### Agents

**Location:** `agents/*.md` **Purpose:** Specialized subprocesses with tool restrictions **Invocation:** Namespaced dispatch from a command or skill

See [sub-agents.md](../sub-agents.md) for complete reference.

### Hooks

**Location:** `hooks/hooks.json` **Purpose:** Lifecycle event handlers **Events:** SessionStart, SessionEnd, PreToolUse, PostToolUse, etc.

See [hooks.md](../hooks.md) for complete reference.

### MCP Servers

**Location:** Configured in `.mcp.json` at plugin root **Purpose:** External tool integrations via Model Context Protocol

See [mcp.md](../mcp.md) for complete reference.

### LSP Servers

**Location:** Configured in `.lsp.json` at plugin root **Purpose:** Language Server Protocol for code intelligence

```json
{
	"python": {
		"command": "pylsp",
		"args": [],
		"extensionToLanguage": { ".py": "python" }
	}
}
```

## Directory Structure

```text
plugin-name/
├── .claude-plugin/
│   └── plugin.json            # Optional metadata and configuration
├── commands/                  # Optional command skills
│   └── command-name.md
├── skills/                    # Optional AI skills
│   └── skill-folder/
│       └── SKILL.md
├── agents/                    # Optional custom agents
│   └── agent-name.md
├── hooks/                     # Optional hooks
│   └── hooks.json
├── .lsp.json                  # Optional LSP config
└── README.md                  # Documentation — use docs/templates/plugin-readme-template.md
```

**Important:** Only `plugin.json` goes inside `.claude-plugin/`. All other directories are at plugin root.

Every plugin `README.md` should follow `docs/templates/plugin-readme-template.md`. Required sections: Summary, Principles, Requirements, Installation, How It Works (Mermaid), Usage, Planned Features, Known Issues, Links. Delete optional sections (Features, Configuration, Design Decisions, etc.) that don't apply to the specific plugin.

## Development Workflow

### 1. Create Plugin

```bash
mkdir -p my-plugin/.claude-plugin
cat > my-plugin/.claude-plugin/plugin.json << 'EOF'
{
  "name": "my-plugin",
  "version": "0.1.0",
  "description": "Description"
}
EOF
```

### 2. Add Components

```bash
# Add a command
mkdir -p my-plugin/commands
cat > my-plugin/commands/hello.md << 'EOF'
---
description: Greet user
---
Greet the user named "$ARGUMENTS" warmly.
EOF

# Add a skill
mkdir -p my-plugin/skills/example
cat > my-plugin/skills/example/SKILL.md << 'EOF'
---
name: example
description: Example skill
---
Skill implementation.
EOF
```

### 3. Test Locally

```bash
claude --plugin-dir ./my-plugin
```

### 4. Update and Reload

```bash
# Make changes
# Activate source changes in the active session
/reload-plugins
```
