#!/bin/bash

# Main build script for documentation system
# Builds both GitBook and MCP documentation

set -e  # Exit on any error

echo "🏗️  Building Documentation System"
echo "=================================="

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Change to project directory
cd "$PROJECT_DIR"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Create necessary directories
echo "📁 Creating build directories..."
mkdir -p docs/build/gitbook
mkdir -p docs/build/mcp

# Build GitBook documentation
echo ""
echo "📚 Building GitBook documentation..."
node scripts/build-gitbook.js

# Build MCP documentation  
echo ""
echo "🤖 Building MCP documentation..."
node scripts/build-mcp.js

echo ""
echo "✅ Documentation build complete!"
echo ""
echo "📊 Build Summary:"
echo "=================="

# Count files in each build directory
GITBOOK_FILES=$(find docs/build/gitbook -name "*.md" | wc -l)
MCP_FILES=$(find docs/build/mcp -name "*.md" | wc -l)

echo "GitBook files: $GITBOOK_FILES"
echo "MCP files: $MCP_FILES"

echo ""
echo "📁 Output locations:"
echo "GitBook: docs/build/gitbook/"
echo "MCP: docs/build/mcp/"
