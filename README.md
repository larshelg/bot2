# Documentation System

A dual-purpose documentation system that generates both human-readable GitBook documentation and LLM-optimized MCP (Model Context Protocol) documentation from a single source.

## Quick Start

```bash
# Install dependencies
npm install

# Build documentation
npm run build

# Or build individually
npm run build:gitbook  # For GitBook
npm run build:mcp      # For MCP
```

## Structure

- `docs/source/shared/` - Content for both GitBook and MCP
- `docs/source/gitbook/` - Human-friendly content only  
- `docs/source/mcp/` - LLM-specific content only
- `docs/build/gitbook/` - Generated GitBook files
- `docs/build/mcp/` - Generated MCP files with frontmatter

## Usage

1. Add your documentation to `docs/source/`
2. Update configs in `config/` if needed
3. Run `npm run build`
4. Use outputs:
   - GitBook: Upload `docs/build/gitbook/` to GitBook
   - MCP: Point MCP server to `docs/build/mcp/`

See the individual artifact files for detailed implementation.
