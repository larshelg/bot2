#!/bin/bash

# MCP Build Hook Script
# This script is triggered by the MCP server when reindexing is needed
# It rebuilds the documentation and then allows the MCP server to reindex

set -e

echo "🔄 MCP reindex triggered - rebuilding documentation..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Change to project directory
cd "$PROJECT_DIR"

# Check if this is a docs project
if [ ! -f "scripts/build-docs.sh" ]; then
    echo "❌ Not a documentation project - skipping build"
    exit 0
fi

# Check if source files are newer than build files
SOURCE_NEWER=false

# Check if any source files are newer than the newest build file
if [ -d "docs/source" ] && [ -d "docs/build/mcp" ]; then
    # Find newest source file
    NEWEST_SOURCE=$(find docs/source -name "*.md" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    
    # Find newest build file
    NEWEST_BUILD=$(find docs/build/mcp -name "*.md" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
    
    if [ -n "$NEWEST_SOURCE" ] && [ -n "$NEWEST_BUILD" ]; then
        if [ "$NEWEST_SOURCE" -nt "$NEWEST_BUILD" ]; then
            SOURCE_NEWER=true
        fi
    elif [ -n "$NEWEST_SOURCE" ] && [ -z "$NEWEST_BUILD" ]; then
        SOURCE_NEWER=true
    fi
fi

# Force rebuild if source is newer or if explicitly requested
if [ "$SOURCE_NEWER" = true ] || [ "$1" = "--force" ]; then
    echo "📝 Source files newer than build - rebuilding MCP documentation..."
    
    # Only rebuild MCP (faster than full build)
    if [ -f "scripts/build-mcp.js" ]; then
        node scripts/build-mcp.js
        echo "✅ MCP documentation rebuilt successfully"
    else
        echo "⚠️  MCP build script not found - running full build"
        npm run build
    fi
else
    echo "✅ Build files are up to date - no rebuild needed"
fi

echo "🔄 Ready for MCP reindexing..."