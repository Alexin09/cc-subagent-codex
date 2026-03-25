#!/usr/bin/env node
// cc-subagent-codex CLI
// npx cc-subagent-codex        → runs install.sh
// npx cc-subagent-codex install → same

const { execSync, spawnSync } = require('child_process')
const path = require('path')
const fs = require('fs')
const os = require('os')

const REPO = 'https://github.com/Alexin09/cc-subagent-codex.git'
const INSTALL_DIR = path.join(os.homedir(), '.cc-subagent-codex')

const cmd = process.argv[2] || 'install'

if (cmd === 'install') {
  console.log('cc-subagent-codex installer\n')

  // 1. Clone or update repo
  if (fs.existsSync(INSTALL_DIR)) {
    console.log('Updating existing installation...')
    spawnSync('git', ['pull'], { cwd: INSTALL_DIR, stdio: 'inherit' })
  } else {
    console.log(`Cloning to ${INSTALL_DIR}...`)
    spawnSync('git', ['clone', REPO, INSTALL_DIR], { stdio: 'inherit' })
  }

  // 2. Run install.sh
  const installScript = path.join(INSTALL_DIR, 'install.sh')
  console.log('\nRunning install.sh...\n')
  const result = spawnSync('bash', [installScript], { stdio: 'inherit' })

  if (result.status !== 0) {
    console.error('Installation failed.')
    process.exit(1)
  }
} else {
  console.error(`Unknown command: ${cmd}`)
  console.error('Usage: npx cc-subagent-codex [install]')
  process.exit(1)
}
