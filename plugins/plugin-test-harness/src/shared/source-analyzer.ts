// src/shared/source-analyzer.ts
import fs from 'fs/promises';
import path from 'path';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import type { McpConfig } from '../plugin/types.js';

export interface ToolSchema {
  name: string;
  description?: string;
  inputSchema?: {
    type: string;
    properties?: Record<string, { type: string; description?: string; enum?: unknown[]; minItems?: number; items?: Record<string, unknown> }>;
    required?: string[];
  };
}

export async function readToolSchemasFromSource(pluginPath: string): Promise<ToolSchema[]> {
  // Read .pth-tools-cache.json if present (populated by Claude after tools/list)
  const cachePath = path.join(pluginPath, '.pth-tools-cache.json');
  let raw: string;
  try {
    raw = await fs.readFile(cachePath, 'utf-8');
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'ENOENT') return [];
    throw err;
  }
  return JSON.parse(raw) as ToolSchema[];
}

export async function writeToolSchemasCache(pluginPath: string, schemas: ToolSchema[]): Promise<void> {
  const cachePath = path.join(pluginPath, '.pth-tools-cache.json');
  await fs.writeFile(cachePath, JSON.stringify(schemas, null, 2), 'utf-8');
}

// Spawns the target MCP server, calls tools/list, and returns all tool schemas.
// The server process is started and stopped within this call — no persistent process.
// cwd is set to pluginPath so relative paths in args (e.g. "dist/server.js") resolve correctly.
export async function fetchToolSchemasFromMcpServer(
  mcpConfig: McpConfig,
  pluginPath: string
): Promise<ToolSchema[]> {
  const transport = new StdioClientTransport({
    command: mcpConfig.command,
    args: mcpConfig.args,
    env: { ...process.env, ...(mcpConfig.env ?? {}) } as Record<string, string>,
    cwd: pluginPath,
  });

  const client = new Client({ name: 'pth-discovery', version: '1.0.0' });

  try {
    await client.connect(transport);
    const { tools } = await client.listTools();
    return tools.map(t => ({
      name: t.name,
      description: t.description,
      inputSchema: t.inputSchema as ToolSchema['inputSchema'],
    }));
  } finally {
    await client.close();
  }
}
