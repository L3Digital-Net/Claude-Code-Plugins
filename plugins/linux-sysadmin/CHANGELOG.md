# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.1.0] - 2026-03-01

### Added

- Plugin scaffold with discovery skill and `/sysadmin` guided workflow command
- `linux-overview` discovery skill: categorized index of all services, tools, and filesystems
- `/sysadmin` command: interactive system architecture interview with stack recommendations
- Design document and implementation plan for ~75 service/tool/filesystem skills

### Removed

- Replaced `linux-sysadmin-mcp` (TypeScript MCP server with 18 tools) with pure-markdown skills approach
