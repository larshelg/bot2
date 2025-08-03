#!/bin/bash

# Complete Documentation System Setup Script
# Run this script in an empty directory to create the entire system

set -e

echo "🚀 Setting up Documentation System..."
echo "====================================="

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p docs/source/shared
mkdir -p docs/source/gitbook/assets
mkdir -p docs/source/mcp
mkdir -p docs/build/gitbook
mkdir -p docs/build/mcp
mkdir -p config
mkdir -p scripts

# Create package.json
echo "📦 Creating package.json..."
cat > package.json << 'EOF'
{
  "name": "docs-system",
  "version": "1.0.0",
  "description": "Dual-purpose documentation system for GitBook and MCP",
  "scripts": {
    "build": "./scripts/build-docs.sh",
    "build:gitbook": "node scripts/build-gitbook.js",
    "build:mcp": "node scripts/build-mcp.js",
    "clean": "rm -rf docs/build/*",
    "watch": "nodemon --watch docs/source --exec 'npm run build'"
  },
  "dependencies": {
    "gray-matter": "^4.0.3",
    "fs-extra": "^11.1.1",
    "path": "^0.12.7"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  },
  "keywords": ["documentation", "gitbook", "mcp", "markdown"],
  "author": "Your Name",
  "license": "MIT"
}
EOF

# Create GitBook config
echo "📚 Creating GitBook configuration..."
cat > config/gitbook-config.json << 'EOF'
{
  "title": "Project Documentation",
  "description": "Complete documentation for our project",
  "structure": [
    {
      "title": "Getting Started",
      "file": "getting-started.md",
      "source": "gitbook"
    },
    {
      "title": "Company Information", 
      "file": "company-info.md",
      "source": "gitbook"
    },
    {
      "title": "Architecture",
      "file": "architecture.md", 
      "source": "shared"
    },
    {
      "title": "API Guidelines",
      "file": "api-guidelines.md",
      "source": "shared"
    },
    {
      "title": "Deployment Guide",
      "file": "deployment.md",
      "source": "shared"
    },
    {
      "title": "Tutorials",
      "file": "tutorials.md",
      "source": "gitbook"
    }
  ],
  "readme": {
    "title": "Welcome to Our Documentation",
    "content": "This documentation covers everything you need to know about our project."
  }
}
EOF

# Create MCP config
echo "🤖 Creating MCP configuration..."
cat > config/mcp-config.json << 'EOF'
{
  "frontmatterTemplates": {
    "shared/api-guidelines.md": {
      "description": "API development guidelines and standards",
      "alwaysApply": true,
      "globs": ["**/*.ts", "**/*.js", "**/api/**"]
    },
    "shared/deployment.md": {
      "description": "Deployment procedures and configurations",
      "globs": ["**/deploy/**", "**/*.yml", "**/*.yaml"]
    },
    "shared/architecture.md": {
      "description": "System architecture and design decisions",
      "alwaysApply": true
    },
    "mcp/code-review.md": {
      "description": "Code review checklist and standards",
      "globs": ["**/*.ts", "**/*.js", "**/*.tsx", "**/*.jsx"]
    },
    "mcp/debug-checklist.md": {
      "description": "Debugging procedures and troubleshooting steps"
    },
    "mcp/llm-instructions.md": {
      "description": "Instructions for LLM behavior and responses",
      "alwaysApply": true
    }
  },
  "defaultFrontmatter": {
    "description": "General project documentation"
  }
}
EOF

# Create GitBook builder script
echo "📄 Creating GitBook builder..."
cat > scripts/build-gitbook.js << 'EOF'
#!/usr/bin/env node

const fs = require('fs-extra');
const path = require('path');

const CONFIG_PATH = path.join(__dirname, '../config/gitbook-config.json');
const SOURCE_DIR = path.join(__dirname, '../docs/source');
const BUILD_DIR = path.join(__dirname, '../docs/build/gitbook');

async function buildGitBook() {
  try {
    console.log('🚀 Building GitBook documentation...');

    // Load configuration
    const config = await fs.readJson(CONFIG_PATH);
    
    // Ensure build directory exists
    await fs.ensureDir(BUILD_DIR);
    
    // Clear previous build
    await fs.emptyDir(BUILD_DIR);
    
    // Generate README.md
    await generateReadme(config);
    
    // Generate SUMMARY.md (table of contents)
    await generateSummary(config);
    
    // Copy files based on configuration
    await copySourceFiles(config);
    
    // Copy assets if they exist
    await copyAssets();
    
    console.log('✅ GitBook documentation built successfully!');
    console.log(`📁 Output directory: ${BUILD_DIR}`);
    
  } catch (error) {
    console.error('❌ Error building GitBook:', error.message);
    process.exit(1);
  }
}

async function generateReadme(config) {
  const readmeContent = `# ${config.title}

${config.readme.content}

## Table of Contents

${config.structure.map(item => `- [${item.title}](${item.file})`).join('\n')}

---

*Last updated: ${new Date().toISOString().split('T')[0]}*
`;

  await fs.writeFile(path.join(BUILD_DIR, 'README.md'), readmeContent);
  console.log('📝 Generated README.md');
}

async function generateSummary(config) {
  const summaryContent = `# Table of contents

* [Introduction](README.md)

${config.structure.map(item => `* [${item.title}](${item.file})`).join('\n')}
`;

  await fs.writeFile(path.join(BUILD_DIR, 'SUMMARY.md'), summaryContent);
  console.log('📑 Generated SUMMARY.md');
}

async function copySourceFiles(config) {
  for (const item of config.structure) {
    const sourceDir = item.source === 'shared' ? 'shared' : 'gitbook';
    const sourcePath = path.join(SOURCE_DIR, sourceDir, item.file);
    const destPath = path.join(BUILD_DIR, item.file);
    
    if (await fs.pathExists(sourcePath)) {
      await fs.copy(sourcePath, destPath);
      console.log(`📄 Copied ${item.file} from ${sourceDir}/`);
    } else {
      console.warn(`⚠️  Warning: ${sourcePath} not found`);
    }
  }
}

async function copyAssets() {
  const assetsSource = path.join(SOURCE_DIR, 'gitbook/assets');
  const assetsDest = path.join(BUILD_DIR, 'assets');
  
  if (await fs.pathExists(assetsSource)) {
    await fs.copy(assetsSource, assetsDest);
    console.log('🖼️  Copied assets');
  }
  
  // Copy any images from shared directory
  const sharedAssetsSource = path.join(SOURCE_DIR, 'shared/images');
  const sharedAssetsDest = path.join(BUILD_DIR, 'images');
  
  if (await fs.pathExists(sharedAssetsSource)) {
    await fs.copy(sharedAssetsSource, sharedAssetsDest);
    console.log('🖼️  Copied shared images');
  }
}

// Run if called directly
if (require.main === module) {
  buildGitBook();
}

module.exports = { buildGitBook };
EOF

# Create MCP builder script
echo "🔧 Creating MCP builder..."
cat > scripts/build-mcp.js << 'EOF'
#!/usr/bin/env node

const fs = require('fs-extra');
const path = require('path');
const matter = require('gray-matter');

const CONFIG_PATH = path.join(__dirname, '../config/mcp-config.json');
const SOURCE_DIR = path.join(__dirname, '../docs/source');
const BUILD_DIR = path.join(__dirname, '../docs/build/mcp');

async function buildMCP() {
  try {
    console.log('🚀 Building MCP documentation...');

    // Load configuration
    const config = await fs.readJson(CONFIG_PATH);
    
    // Ensure build directory exists
    await fs.ensureDir(BUILD_DIR);
    
    // Clear previous build
    await fs.emptyDir(BUILD_DIR);
    
    // Process shared files
    await processSharedFiles(config);
    
    // Process MCP-only files
    await processMCPOnlyFiles(config);
    
    // Generate usage instructions
    await generateUsageInstructions();
    
    console.log('✅ MCP documentation built successfully!');
    console.log(`📁 Output directory: ${BUILD_DIR}`);
    
  } catch (error) {
    console.error('❌ Error building MCP:', error.message);
    process.exit(1);
  }
}

async function processSharedFiles(config) {
  const sharedDir = path.join(SOURCE_DIR, 'shared');
  
  if (!(await fs.pathExists(sharedDir))) {
    console.warn('⚠️  Shared directory not found');
    return;
  }
  
  const files = await fs.readdir(sharedDir);
  
  for (const file of files) {
    if (!file.endsWith('.md')) continue;
    
    const sourcePath = path.join(sharedDir, file);
    const destPath = path.join(BUILD_DIR, file);
    const configKey = `shared/${file}`;
    
    // Read the original file
    const content = await fs.readFile(sourcePath, 'utf8');
    
    // Get frontmatter for this file or use default
    const frontmatter = config.frontmatterTemplates[configKey] || config.defaultFrontmatter;
    
    // Add frontmatter to content
    const fileWithFrontmatter = matter.stringify(content, frontmatter);
    
    await fs.writeFile(destPath, fileWithFrontmatter);
    console.log(`📄 Processed shared/${file} with frontmatter`);
  }
}

async function processMCPOnlyFiles(config) {
  const mcpDir = path.join(SOURCE_DIR, 'mcp');
  
  if (!(await fs.pathExists(mcpDir))) {
    console.warn('⚠️  MCP directory not found');
    return;
  }
  
  const files = await fs.readdir(mcpDir);
  
  for (const file of files) {
    if (!file.endsWith('.md')) continue;
    
    const sourcePath = path.join(mcpDir, file);
    const destPath = path.join(BUILD_DIR, file);
    const configKey = `mcp/${file}`;
    
    // Read the original file
    const content = await fs.readFile(sourcePath, 'utf8');
    
    // Get frontmatter for this file or use default
    const frontmatter = config.frontmatterTemplates[configKey] || config.defaultFrontmatter;
    
    // Add frontmatter to content
    const fileWithFrontmatter = matter.stringify(content, frontmatter);
    
    await fs.writeFile(destPath, fileWithFrontmatter);
    console.log(`📄 Processed mcp/${file} with frontmatter`);
  }
}

async function generateUsageInstructions() {
  const usageContent = `---
description: "Usage instructions for the get_relevant_docs MCP tool"
alwaysApply: true
---

# Usage Instructions

* You **must** call the \`get_relevant_docs\` MCP tool before providing your first response in any new chat session.
* After the initial call in a chat, you should **only** call \`get_relevant_docs\` again if one of these specific situations occurs:
  * The user explicitly requests it.
  * The user attaches new files.
  * The user's query introduces a completely new topic unrelated to the previous discussion.

## Available Documentation

This project includes the following types of documentation:

- **Architecture**: System design and technical decisions
- **API Guidelines**: Development standards and best practices
- **Code Review**: Quality assurance checklists
- **Deployment**: Production deployment procedures
- **Debug Procedures**: Troubleshooting and debugging steps

## Context Usage

The documentation is automatically filtered based on:
- File types being worked on
- Project areas being discussed
- Specific topics mentioned in queries

Always consult the most relevant documentation before providing advice or making suggestions.
`;

  await fs.writeFile(path.join(BUILD_DIR, 'markdown-rules.md'), usageContent);
  console.log('📋 Generated markdown-rules.md');
}

// Run if called directly
if (require.main === module) {
  buildMCP();
}

module.exports = { buildMCP };
EOF

# Create main build script
echo "🏗️  Creating main build script..."
cat > scripts/build-docs.sh << 'EOF'
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
EOF

# Make scripts executable
chmod +x scripts/build-docs.sh

# Create example source files
echo "📝 Creating example documentation files..."

# Shared API Guidelines
cat > docs/source/shared/api-guidelines.md << 'EOF'
# API Guidelines

## Overview

This document outlines the core API development standards that all team members must follow.

## Authentication

All APIs must implement JWT-based authentication with the following requirements:

- Token expiry: 1 hour for access tokens
- Refresh token expiry: 7 days
- Include proper CORS headers
- Rate limiting: 1000 requests per hour per user

```typescript
interface AuthConfig {
  accessTokenExpiry: string;
  refreshTokenExpiry: string;
  corsOrigins: string[];
  rateLimit: {
    requests: number;
    windowMs: number;
  };
}
```

## Error Handling

### Standard Error Format

All API errors must follow this structure:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": {
      "field": "email",
      "reason": "Invalid email format"
    },
    "timestamp": "2025-01-15T10:30:00Z"
  }
}
```

### HTTP Status Codes

- `200` - Success
- `201` - Created
- `400` - Bad Request (validation errors)
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `429` - Too Many Requests
- `500` - Internal Server Error

## API Versioning

Use header-based versioning:

```
API-Version: v1
```

## Documentation

All endpoints must be documented using OpenAPI 3.0 specification.

## Testing

Each API endpoint requires:
- Unit tests for business logic
- Integration tests for database interactions
- End-to-end tests for critical user journeys
EOF

# Shared Architecture
cat > docs/source/shared/architecture.md << 'EOF'
# System Architecture

## Overview

Our system follows a microservices architecture with clear separation of concerns.

## Core Components

### API Gateway
- Route requests to appropriate services
- Handle authentication and authorization
- Rate limiting and request throttling

### User Service
- User management and authentication
- Profile data and preferences
- OAuth integration

### Data Service
- Database operations
- Data validation and transformation
- Caching layer

## Technology Stack

- **Backend**: Node.js with TypeScript
- **Database**: PostgreSQL with Redis cache
- **API**: RESTful APIs with GraphQL for complex queries
- **Authentication**: JWT with refresh tokens
- **Deployment**: Docker containers on Kubernetes

## Data Flow

1. Client sends request to API Gateway
2. Gateway validates authentication
3. Request routed to appropriate microservice
4. Service processes request and returns response
5. Gateway returns response to client
EOF

# Shared Deployment
cat > docs/source/shared/deployment.md << 'EOF'
# Deployment Guide

## Environments

### Development
- Local development environment
- Hot reloading enabled
- Debug logging active

### Staging
- Production-like environment for testing
- Integration with external services
- Performance monitoring

### Production
- Live user environment
- High availability setup
- Comprehensive monitoring and alerting

## Deployment Process

### Prerequisites
- Docker installed
- Kubernetes cluster access
- Environment variables configured

### Steps

1. **Build**: Create Docker images
2. **Test**: Run automated test suite
3. **Deploy**: Apply Kubernetes manifests
4. **Verify**: Health checks and smoke tests

## Configuration

All configuration is managed through environment variables:

```bash
DATABASE_URL=postgresql://...
JWT_SECRET=...
REDIS_URL=redis://...
API_PORT=3000
```

## Monitoring

- Health check endpoints at `/health`
- Metrics collection with Prometheus
- Log aggregation with ELK stack
- Alerting via PagerDuty
EOF

# GitBook Getting Started
cat > docs/source/gitbook/getting-started.md << 'EOF'
# Getting Started Tutorial

Welcome to our project! This tutorial will guide you through setting up your development environment and creating your first API endpoint.

## Prerequisites

Before you begin, make sure you have:

{% hint style="info" %}
**System Requirements**
- Node.js 18 or higher
- PostgreSQL 14+
- Git
- A code editor (we recommend VS Code)
{% endhint %}

## Step 1: Clone the Repository

```bash
git clone https://github.com/your-org/your-project.git
cd your-project
```

## Step 2: Install Dependencies

```bash
npm install
```

This will install all the necessary packages and dependencies.

## Step 3: Environment Setup

Create a `.env` file in the root directory:

```env
DATABASE_URL=postgresql://username:password@localhost:5432/your_db
JWT_SECRET=your-super-secret-key
API_PORT=3000
```

{% hint style="warning" %}
**Security Note**
Never commit your `.env` file to version control. Make sure it's listed in your `.gitignore` file.
{% endhint %}

## Next Steps

- Read our [API Guidelines](api-guidelines.md)
- Check out the [Architecture Guide](architecture.md) 
- Explore the [Deployment Guide](deployment.md)
EOF

# GitBook Company Info
cat > docs/source/gitbook/company-info.md << 'EOF'
# Company Information

## About Us

We are a technology company focused on building innovative solutions that make developers' lives easier.

## Our Mission

To create tools and platforms that enable developers to build better software faster.

## Our Values

- **Innovation**: We constantly push the boundaries of what's possible
- **Quality**: We believe in building software that works reliably
- **Collaboration**: We work together to achieve common goals
- **Transparency**: We communicate openly and honestly

## Team

Our team consists of experienced engineers, designers, and product managers who are passionate about technology and solving real-world problems.

## Contact

- **Email**: hello@company.com
- **Slack**: #general
- **GitHub**: github.com/company
EOF

# GitBook Tutorials
cat > docs/source/gitbook/tutorials.md << 'EOF'
# Tutorials

## Quick Start Tutorials

### Building Your First API

This tutorial walks you through creating a simple REST API endpoint.

1. Create a new route file
2. Define your endpoint logic
3. Add input validation
4. Test your endpoint

### Database Integration

Learn how to connect your API to a PostgreSQL database.

1. Set up database connection
2. Create database models
3. Implement CRUD operations
4. Handle database errors

### Authentication Setup

Implement JWT-based authentication in your application.

1. Install authentication middleware
2. Create login/logout endpoints
3. Protect routes with authentication
4. Handle token refresh

## Advanced Tutorials

### Microservices Architecture

Break down a monolithic application into microservices.

### Performance Optimization

Optimize your application for better performance.

### Deployment Strategies

Learn different deployment strategies and best practices.
EOF

# MCP Code Review
cat > docs/source/mcp/code-review.md << 'EOF'
# Code Review Checklist

## Pre-Review Requirements

Before reviewing any code, ensure:

- [ ] All tests pass in CI/CD pipeline
- [ ] Code follows our style guide and linting rules
- [ ] PR description clearly explains changes and reasoning
- [ ] Branch is up to date with main/master

## Code Quality Checks

### TypeScript/JavaScript

- [ ] **Type Safety**: All variables and functions have proper type annotations
- [ ] **Error Handling**: Proper try-catch blocks and error propagation
- [ ] **Async/Await**: Consistent use of async/await over promises
- [ ] **Null Checks**: Proper handling of null/undefined values
- [ ] **Performance**: No unnecessary re-renders or inefficient loops

### API Endpoints

- [ ] **Authentication**: Proper JWT validation and user authorization
- [ ] **Input Validation**: All inputs validated using Joi/Zod schemas
- [ ] **Rate Limiting**: Applied to public endpoints
- [ ] **Error Responses**: Follow standard error format
- [ ] **Logging**: Appropriate logging for debugging and monitoring

### Security

- [ ] **Sensitive Data**: No secrets in code (use environment variables)
- [ ] **CORS**: Proper CORS configuration
- [ ] **Headers**: Security headers (HSTS, CSP, etc.)
- [ ] **Dependencies**: No vulnerable dependencies (check npm audit)

## Red Flags (Immediate Rejection)

- ❌ **Hardcoded Secrets**: API keys, passwords, or tokens in code
- ❌ **SQL Injection**: Raw SQL queries with string concatenation
- ❌ **No Error Handling**: Functions that can fail without error handling
- ❌ **Breaking Changes**: API changes without proper versioning
EOF

# MCP Debug Checklist
cat > docs/source/mcp/debug-checklist.md << 'EOF'
# Debug Checklist

## Initial Assessment

- [ ] **Reproduce the Issue**: Can you consistently reproduce the problem?
- [ ] **Error Messages**: Collect all error messages and stack traces
- [ ] **Environment**: Which environment is affected (dev/staging/prod)?
- [ ] **Timing**: When did the issue first appear?

## Common Issues

### API Errors

1. **500 Internal Server Error**
   - Check server logs for detailed error messages
   - Verify database connections
   - Check for unhandled exceptions

2. **401 Unauthorized**
   - Verify JWT token is present and valid
   - Check token expiry
   - Confirm user permissions

3. **404 Not Found**
   - Verify URL path is correct
   - Check if route is properly registered
   - Confirm API version in headers

### Database Issues

1. **Connection Timeout**
   - Check database server status
   - Verify connection string
   - Check connection pool settings

2. **Query Performance**
   - Use EXPLAIN to analyze query execution
   - Check for missing indexes
   - Monitor connection pool usage

### Performance Issues

1. **Slow Response Times**
   - Check database query performance
   - Monitor CPU and memory usage
   - Review caching strategy

2. **Memory Leaks**
   - Monitor memory usage over time
   - Check for unclosed connections
   - Review event listener cleanup

## Debugging Tools

- **Logs**: Always check application and system logs first
- **APM**: Use Application Performance Monitoring tools
- **Database**: Monitor database performance metrics
- **Network**: Check network connectivity and latency
EOF

# MCP LLM Instructions
cat > docs/source/mcp/llm-instructions.md << 'EOF'
# LLM Instructions

## Code Generation Guidelines

When generating code for this project:

1. **Follow TypeScript Standards**
   - Use strict typing
   - Include proper interfaces
   - Handle null/undefined cases

2. **Error Handling**
   - Always include try-catch blocks for async operations
   - Use proper error types and messages
   - Log errors appropriately

3. **Security Practices**
   - Never hardcode secrets or API keys
   - Validate all user inputs
   - Use parameterized queries for database operations

## Code Review Process

When reviewing code:

1. Check the code review checklist
2. Focus on security vulnerabilities
3. Ensure proper error handling
4. Verify test coverage

## API Development

When creating or modifying APIs:

1. Follow RESTful conventions
2. Include proper authentication
3. Implement rate limiting
4. Document with OpenAPI specs

## Debugging Assistance

When helping with debugging:

1. Start with the debug checklist
2. Ask for relevant error messages and logs
3. Suggest systematic troubleshooting steps
4. Recommend appropriate tools
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
# Documentation System .gitignore

# Build outputs (generated files)
docs/build/

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Editor files
.vscode/
.idea/
*.swp
*.swo
*~

# Temporary files
*.tmp
*.temp

# Logs
logs/
*.log
EOF

# Create README
cat > README.md << 'EOF'
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
EOF

# Final messages
echo ""
echo "✅ Documentation system setup complete!"
echo ""
echo "📁 Directory structure created"
echo "📦 Package.json with dependencies"
echo "🔧 Build scripts ready"
echo "📝 Example documentation files"
echo "⚙️  Configuration files"
echo ""
echo "Next steps:"
echo "1. Run: npm install"
echo "2. Run: npm run build"
echo "3. Check the outputs in docs/build/"
echo ""
echo "🚀 Your documentation system is ready to use!"