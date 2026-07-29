#!/usr/bin/env node

import fs from 'fs';
import path from 'path';

function parseArgs(argv) {
  const args = {
    mode: 'dry-run',
    repoRoot: '',
    sourceRoot: '',
    mappingFile: '',
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    switch (arg) {
      case '--mode':
        args.mode = argv[++i];
        break;
      case '--repo-root':
        args.repoRoot = argv[++i];
        break;
      case '--source-root':
        args.sourceRoot = argv[++i];
        break;
      case '--mapping-file':
        args.mappingFile = argv[++i];
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!args.repoRoot || !args.sourceRoot || !args.mappingFile) {
    throw new Error('Missing required arguments.');
  }

  if (!['dry-run', 'apply'].includes(args.mode)) {
    throw new Error(`Unsupported mode: ${args.mode}`);
  }

  return args;
}

function listFiles(rootDir) {
  const files = [];

  function walk(currentDir) {
    if (!fs.existsSync(currentDir)) {
      return;
    }
    const entries = fs.readdirSync(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const nextPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        walk(nextPath);
      } else if (entry.isFile()) {
        files.push(path.relative(rootDir, nextPath));
      }
    }
  }

  walk(rootDir);
  return files.sort();
}

function sameContent(leftPath, rightPath) {
  if (!fs.existsSync(leftPath) || !fs.existsSync(rightPath)) {
    return false;
  }
  const left = fs.readFileSync(leftPath);
  const right = fs.readFileSync(rightPath);
  return left.equals(right);
}

function copyFile(sourcePath, targetPath, mode) {
  if (mode === 'apply') {
    fs.mkdirSync(path.dirname(targetPath), { recursive: true });
    fs.copyFileSync(sourcePath, targetPath);
  }
}

function deleteFile(targetPath, mode) {
  if (mode === 'apply' && fs.existsSync(targetPath)) {
    fs.rmSync(targetPath, { force: true });
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const mappings = JSON.parse(fs.readFileSync(args.mappingFile, 'utf8'));
  const mappedSources = new Set(Object.keys(mappings));
  const upstreamFiles = listFiles(args.sourceRoot);

  const summary = {
    created: [],
    updated: [],
    deleted: [],
    unchanged: [],
    missingSources: [],
    unmappedUpstream: [],
  };

  for (const [sourceRel, targetRel] of Object.entries(mappings)) {
    const sourcePath = path.join(args.sourceRoot, sourceRel);
    const targetPath = path.join(args.repoRoot, targetRel);

    if (!fs.existsSync(sourcePath)) {
      if (fs.existsSync(targetPath)) {
        summary.deleted.push(targetRel);
        deleteFile(targetPath, args.mode);
      } else {
        summary.missingSources.push(sourceRel);
      }
      continue;
    }

    if (!fs.existsSync(targetPath)) {
      summary.created.push(targetRel);
      copyFile(sourcePath, targetPath, args.mode);
      continue;
    }

    if (!sameContent(sourcePath, targetPath)) {
      summary.updated.push(targetRel);
      copyFile(sourcePath, targetPath, args.mode);
      continue;
    }

    summary.unchanged.push(targetRel);
  }

  for (const upstreamFile of upstreamFiles) {
    if (!mappedSources.has(upstreamFile)) {
      summary.unmappedUpstream.push(upstreamFile);
    }
  }

  const modePrefix = args.mode === 'apply' ? 'apply' : 'dry-run';
  console.log(`[${modePrefix}] vulcan-book mapped file summary`);
  console.log(`  created: ${summary.created.length}`);
  console.log(`  updated: ${summary.updated.length}`);
  console.log(`  deleted: ${summary.deleted.length}`);
  console.log(`  unchanged: ${summary.unchanged.length}`);
  console.log(`  unmapped upstream: ${summary.unmappedUpstream.length}`);

  const detailGroups = [
    ['created', summary.created],
    ['updated', summary.updated],
    ['deleted', summary.deleted],
    ['missing source entries', summary.missingSources],
    ['unmapped upstream', summary.unmappedUpstream],
  ];

  for (const [label, items] of detailGroups) {
    if (items.length === 0) {
      continue;
    }
    console.log(`\n${label}:`);
    for (const item of items) {
      console.log(`  - ${item}`);
    }
  }
}

main();
