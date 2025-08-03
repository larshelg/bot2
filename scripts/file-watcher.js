#!/usr/bin/env node

// File Watcher Service for Documentation System
// Automatically rebuilds MCP docs when source files change

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

const WATCH_DIR = path.join(__dirname, '../docs/source');
const BUILD_SCRIPT = path.join(__dirname, 'build-mcp.js');

let buildTimeout;
let isBuilding = false;

function triggerBuild() {
  if (isBuilding) {
    console.log('⏳ Build already in progress, skipping...');
    return;
  }

  // Debounce builds (wait 2 seconds after last change)
  clearTimeout(buildTimeout);
  buildTimeout = setTimeout(() => {
    console.log('🔄 Source files changed, rebuilding MCP documentation...');
    isBuilding = true;

    const buildProcess = spawn('node', [BUILD_SCRIPT], {
      stdio: 'inherit',
      cwd: path.dirname(__dirname)
    });

    buildProcess.on('close', (code) => {
      isBuilding = false;
      if (code === 0) {
        console.log('✅ MCP documentation rebuilt successfully');
        
        // Optionally trigger MCP reindex here
        // This would require calling the MCP server's reindex endpoint
        console.log('💡 Run "reindex_docs" in your AI chat to update context');
      } else {
        console.error('❌ Build failed with code:', code);
      }
    });

    buildProcess.on('error', (error) => {
      isBuilding = false;
      console.error('❌ Build error:', error.message);
    });
  }, 2000);
}

function startWatching() {
  if (!fs.existsSync(WATCH_DIR)) {
    console.error(`❌ Watch directory not found: ${WATCH_DIR}`);
    process.exit(1);
  }

  console.log(`👀 Watching for changes in: ${WATCH_DIR}`);
  console.log('🔄 File changes will trigger MCP documentation rebuild');

  fs.watch(WATCH_DIR, { recursive: true }, (eventType, filename) => {
    if (filename && filename.endsWith('.md')) {
      console.log(`📝 Detected change: ${filename}`);
      triggerBuild();
    }
  });

  // Also watch config files
  const configDir = path.join(__dirname, '../config');
  if (fs.existsSync(configDir)) {
    fs.watch(configDir, (eventType, filename) => {
      if (filename && filename.endsWith('.json')) {
        console.log(`⚙️  Config change detected: ${filename}`);
        triggerBuild();
      }
    });
  }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n👋 Stopping file watcher...');
  process.exit(0);
});

// Start watching
startWatching();

// Keep the process alive
setInterval(() => {
  // Heartbeat every 30 seconds
}, 30000);