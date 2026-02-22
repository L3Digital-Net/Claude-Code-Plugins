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
  // ${CLAUDE_PLUGIN_ROOT} is substituted by Claude Code at load time, but spawn() does not
  // invoke a shell, so template syntax passes through literally and causes ENOENT on the child.
  // Substitute here with pluginPath — the same value Claude Code would use.
  const expandVar = (s: string): string => s.replace(/\$\{CLAUDE_PLUGIN_ROOT\}/g, pluginPath);

  // stderr: 'pipe' prevents the child from inheriting the parent's stderr fd.
  // When PTH runs as a Claude Code MCP server, fd 2 is a live Unix socket to Claude Code.
  // Inheriting that socket in the child can cause the child to stall or crash
  // (e.g. if the socket buffer fills, blocking the child's stderr writes).
  // 'pipe' gives the child an isolated stderr pipe; we drain it to prevent backpressure.
  const transport = new StdioClientTransport({
    command: expandVar(mcpConfig.command),
    args: mcpConfig.args.map(expandVar),
    env: { ...process.env, ...(mcpConfig.env ?? {}) } as Record<string, string>,
    cwd: pluginPath,
    stderr: 'pipe',
  });
  // Drain child stderr — nobody reads it here, but an unread pipe can stall the child.
  if (transport.stderr) (transport.stderr as unknown as NodeJS.ReadableStream).resume();

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
