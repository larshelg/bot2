---
description: "Usage instructions for the get_relevant_docs MCP tool with build integration"
alwaysApply: true
---

# Usage Instructions

## Document Access

* You **must** call the `get_relevant_docs` MCP tool before providing your first response in any new chat session.
* After the initial call in a chat, you should **only** call `get_relevant_docs` again if one of these specific situations occurs:
  * The user explicitly requests it.
  * The user attaches new files.
  * The user's query introduces a completely new topic unrelated to the previous discussion.

## Editing Documentation

When asked to modify documentation:

### General Rules
1. **Always edit source files** in `docs/source/` directories
2. **Never edit build files** in `docs/build/` (they get overwritten)
3. **After editing**, call `reindex_docs` to update the MCP context

### File Locations by Purpose

**Shared Documentation** (appears in both GitBook and MCP):
- Location: `docs/source/shared/`
- Files: `api-guidelines.md`, `architecture.md`, `deployment.md`
- Use for: Core technical docs, API specs, system design

**GitBook-Only Documentation** (human-readable content only):
- Location: `docs/source/gitbook/`
- Files: `getting-started.md`, `tutorials.md`, `company-info.md`
- Use for: Tutorials, walkthroughs, company info, screenshots, marketing content

**MCP-Only Documentation** (LLM context only):
- Location: `docs/source/mcp/` 
- Files: `code-review.md`, `debug-checklist.md`, `llm-instructions.md`
- Use for: Code review checklists, debugging procedures, LLM behavior rules

### When Asked About GitBook Updates

**When asked to update GitBook content, only use these files:**
- `docs/source/gitbook/*.md` - For GitBook-specific content
- `docs/source/shared/*.md` - For content that should appear in both systems

**Do NOT edit** `docs/source/mcp/*.md` files when updating GitBook content.

### When Asked About MCP/LLM Context Updates

**When asked to update MCP/LLM context, use these files:**
- `docs/source/mcp/*.md` - For LLM-specific instructions and checklists
- `docs/source/shared/*.md` - For core documentation that LLMs should know

### After Any Documentation Edit

Always suggest calling `reindex_docs` to update the MCP context with the latest changes.

## Smart Linking Features

When creating documentation, use these special link formats to enhance MCP context:

### Link Entire Files (?md-link=true)
To include the full contents of referenced files in the MCP context:
```markdown
See [Database Schema](./database-schema.md?md-link=true) for complete details.
See [Utility Functions](../src/utils.ts?md-link=true) for helper code.
```

### Embed Specific Lines (?md-embed=START-END)
To include only specific lines from files:
```markdown
Configuration example: [API Config](./config.json?md-embed=1-10)
Error handling pattern: [Utils](../src/utils.ts?md-embed=45-65)
```

### When to Use Smart Links

**Use ?md-link=true when:**
- Referencing complete documentation files
- Linking to source code that should be fully included
- Cross-referencing between documentation sections

**Use ?md-embed=START-END when:**
- Showing specific code examples
- Including relevant configuration snippets
- Highlighting particular functions or sections

**Use regular links when:**
- Creating GitBook navigation (smart links don't work in GitBook)
- Linking to external resources
- Simple cross-references that don't need full content inclusion

### Smart Link Examples

```markdown
<!-- Good: Include full utility file in MCP context -->
For helper functions, see [Utils](../src/utils.ts?md-link=true).

<!-- Good: Include specific config section -->
Database settings: [Config](./config.json?md-embed=15-25)

<!-- Good: Regular link for GitBook navigation -->
Continue to [Next Chapter](./chapter-2.md)
```

## Rebuilding Documentation

When documentation source files change:

1. **Automatic Rebuild**: If file watcher is running (`npm run watch:mcp`), MCP docs rebuild automatically
2. **Manual Rebuild**: Run `reindex_docs` tool to trigger a rebuild and reindex
3. **Force Rebuild**: Use `npm run mcp:force-rebuild` in the project directory

## Available Documentation

This project includes the following types of documentation:

- **Architecture**: System design and technical decisions (always included)
- **API Guidelines**: Development standards and best practices (always included)
- **Code Review**: Quality assurance checklists (included for code files)
- **Deployment**: Production deployment procedures (included for deploy files)
- **Debug Procedures**: Troubleshooting and debugging steps

## Context Usage

The documentation is automatically filtered based on:
- File types being worked on (via `globs` in frontmatter)
- Project areas being discussed
- Specific topics mentioned in queries
- Always-apply rules for critical documentation

## Reindexing Process

When you call `reindex_docs`:
1. System checks if source documentation has changed
2. If changes detected, rebuilds MCP documentation from source
3. Reindexes the updated files
4. You'll get fresh context from the latest documentation

Always consult the most relevant documentation before providing advice or making suggestions.
