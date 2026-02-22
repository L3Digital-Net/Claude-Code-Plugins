// test/unit/shared/source-analyzer.test.ts
// Verifies that PTH can autonomously spawn an MCP server and fetch all tool schemas.
// Uses the sample-mcp-plugin fixture (pre-built, 4 tools).
import path from 'path';
import { fileURLToPath } from 'url';
import { readMcpConfig } from '../../../src/plugin/detector.js';
import { fetchToolSchemasFromMcpServer } from '../../../src/shared/source-analyzer.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURE_MCP = path.join(__dirname, '../../fixtures/sample-mcp-plugin');

describe('fetchToolSchemasFromMcpServer', () => {
  it('discovers all tools by spawning the target MCP server', async () => {
    const mcpConfig = await readMcpConfig(FIXTURE_MCP);
    expect(mcpConfig).not.toBeNull();

    const schemas = await fetchToolSchemasFromMcpServer(mcpConfig!, FIXTURE_MCP);

    expect(schemas).toHaveLength(4);
    expect(schemas.map(s => s.name)).toEqual(
      expect.arrayContaining(['echo', 'reverse_string', 'divide', 'get_status'])
    );
  }, 15_000);

  it('preserves inputSchema details including required fields', async () => {
    const mcpConfig = await readMcpConfig(FIXTURE_MCP);
    const schemas = await fetchToolSchemasFromMcpServer(mcpConfig!, FIXTURE_MCP);

    const echo = schemas.find(s => s.name === 'echo');
    expect(echo).toBeDefined();
    expect(echo!.inputSchema?.required).toContain('message');
    expect(echo!.inputSchema?.properties?.['message']).toMatchObject({ type: 'string' });
  }, 15_000);
});
