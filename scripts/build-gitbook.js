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
