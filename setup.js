#!/usr/bin/env node
/**
 * Node.js Setup Script for Claude Agent Telemetry
 * Replaces setup.sh with cross-platform Node.js implementation
 */

const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const BinaryManager = require('./lib/binary-manager');
const { getPlatform } = require('./lib/download-config');

// Colors for output
const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
  bold: '\x1b[1m',
  reset: '\x1b[0m'
};

function log(level, message) {
  const timestamp = new Date().toISOString();
  const colorMap = {
    info: colors.blue,
    success: colors.green,
    warning: colors.yellow,
    error: colors.red,
    step: colors.cyan
  };
  
  const color = colorMap[level] || '';
  console.log(`${color}[${level.toUpperCase()}]${colors.reset} ${message}`);
}

function logHeader(title) {
  console.log(`\n${colors.bold}${colors.blue}=== ${title} ===${colors.reset}`);
}

function showProgress(current, total, description) {
  const percent = Math.round((current / total) * 100);
  const bar = '█'.repeat(Math.floor(percent / 5)) + '░'.repeat(20 - Math.floor(percent / 5));
  process.stdout.write(`\r${colors.cyan}▶${colors.reset} ${description} [${bar}] ${percent}%`);
  if (current === total) {
    console.log(); // New line when complete
  }
}

class Setup {
  constructor() {
    this.projectDir = __dirname;
    this.platform = getPlatform();
    this.binaryManager = new BinaryManager();
    this.totalSteps = 8;
    this.currentStep = 0;
  }

  nextStep(description) {
    this.currentStep++;
    console.log(`${colors.bold}[${this.currentStep}/${this.totalSteps}]${colors.reset} ${description}`);
  }

  // Check system dependencies
  async checkSystemDependencies() {
    this.nextStep('Checking system dependencies');
    
    const requiredCommands = ['curl'];
    const missingDeps = [];
    
    // Check required commands
    for (const cmd of requiredCommands) {
      try {
        execSync(`command -v ${cmd}`, { stdio: 'pipe' });
        log('info', `✓ ${cmd} found`);
      } catch {
        missingDeps.push(cmd);
      }
    }
    
    // Check Node.js version
    const nodeVersion = process.version;
    const majorVersion = parseInt(nodeVersion.split('.')[0].substring(1));
    
    if (majorVersion >= 14) {
      log('info', `✓ Node.js ${nodeVersion} (compatible)`);
    } else {
      throw new Error(`Node.js 14+ required, found ${nodeVersion}`);
    }
    
    // Check platform support
    log('info', `Platform: ${this.platform.platform}-${this.platform.raw_arch}`);
    
    if (missingDeps.length > 0) {
      log('error', `Missing dependencies: ${missingDeps.join(', ')}`);
      
      if (this.platform.platform === 'linux') {
        log('info', 'Install with: sudo apt update && sudo apt install curl');
      } else if (this.platform.platform === 'darwin') {
        log('info', 'Install with: brew install curl');
      }
      
      throw new Error('Missing required dependencies');
    }
    
    log('success', 'All system dependencies available');
  }

  // Setup directories and permissions
  async setupDirectories() {
    this.nextStep('Setting up directories and permissions');
    
    const dirs = [
      path.join(this.projectDir, 'data', 'loki', 'chunks'),
      path.join(this.projectDir, 'data', 'loki', 'rules'),
      path.join(this.projectDir, 'data', 'logs'),
      path.join(this.projectDir, 'data', 'grafana'),
      path.join(this.projectDir, 'logs')
    ];
    
    for (const dir of dirs) {
      await fs.mkdir(dir, { recursive: true });
    }
    
    // Fix script permissions
    const scriptsDir = path.join(this.projectDir, 'scripts');
    try {
      const files = await fs.readdir(scriptsDir, { recursive: true });
      for (const file of files) {
        const filePath = path.join(scriptsDir, file);
        const stat = await fs.stat(filePath);
        if (stat.isFile() && (file.endsWith('.sh') || file === 'claude-telemetry')) {
          await fs.chmod(filePath, 0o755);
        }
      }
    } catch (error) {
      log('warning', `Could not fix script permissions: ${error.message}`);
    }
    
    // Fix hook permissions
    const hookPath = path.join(this.projectDir, 'config', 'claude', 'hooks', 'telemetry-hook.sh');
    try {
      await fs.chmod(hookPath, 0o755);
    } catch (error) {
      log('warning', `Could not fix hook permissions: ${error.message}`);
    }
    
    log('success', 'Directories and permissions configured');
  }

  // Download and install binaries
  async installBinaries() {
    this.nextStep('Installing Loki and Grafana binaries');
    
    const progressCallback = (downloaded, total, percent) => {
      const downloadedMB = (downloaded / 1024 / 1024).toFixed(1);
      const totalMB = (total / 1024 / 1024).toFixed(1);
      showProgress(downloaded, total, `Downloading (${downloadedMB}/${totalMB} MB)`);
    };
    
    try {
      await this.binaryManager.downloadAllBinaries({ 
        onProgress: progressCallback 
      });
      log('success', 'Binaries installed successfully');
    } catch (error) {
      throw new Error(`Binary installation failed: ${error.message}`);
    }
  }

  // Test services
  async testServices() {
    this.nextStep('Testing service functionality');
    
    const health = await this.binaryManager.checkBinariesHealth();
    
    for (const [service, status] of Object.entries(health)) {
      if (status.status === 'healthy') {
        log('success', `✓ ${service} is functional`);
      } else {
        log('error', `✗ ${service} failed: ${status.error || status.status}`);
        throw new Error(`Service test failed for ${service}`);
      }
    }
    
    log('success', 'All services are functional');
  }

  // Setup Claude Code integration
  async setupClaudeIntegration() {
    this.nextStep('Setting up Claude Code integration');
    
    const integrationScript = path.join(this.projectDir, 'scripts', 'lib', 'maintenance', 'install-claude-commands.sh');
    
    if (fsSync.existsSync(integrationScript)) {
      try {
        execSync(`"${integrationScript}"`, { stdio: 'pipe' });
        log('success', 'Claude Code integration configured');
      } catch (error) {
        log('warning', `Claude Code integration setup failed: ${error.message}`);
      }
    } else {
      log('warning', 'Claude Code integration script not found');
    }
  }

  // Create convenience scripts
  async createScripts() {
    this.nextStep('Creating convenience scripts');
    
    // All scripts already exist in the repository
    // Just verify they're executable
    const scriptPaths = [
      path.join(this.projectDir, 'scripts', 'claude-telemetry'),
      path.join(this.projectDir, 'scripts', 'lib', 'services', 'start-all.sh'),
      path.join(this.projectDir, 'scripts', 'lib', 'maintenance', 'health-check.sh')
    ];
    
    for (const scriptPath of scriptPaths) {
      if (fsSync.existsSync(scriptPath)) {
        await fs.chmod(scriptPath, 0o755);
      }
    }
    
    log('success', 'Convenience scripts ready');
  }

  // Run health check
  async runHealthCheck() {
    this.nextStep('Running final health check');
    
    const healthScript = path.join(this.projectDir, 'scripts', 'lib', 'maintenance', 'health-check.sh');
    
    if (fsSync.existsSync(healthScript)) {
      try {
        const output = execSync(`"${healthScript}"`, { encoding: 'utf8' });
        console.log(output);
      } catch (error) {
        log('warning', `Health check script failed: ${error.message}`);
      }
    }
    
    // Also run our own health check
    const health = await this.binaryManager.checkBinariesHealth();
    const allHealthy = Object.values(health).every(h => h.status === 'healthy');
    
    if (allHealthy) {
      log('success', 'System health check passed');
    } else {
      log('warning', 'Some components may need attention');
    }
  }

  // Main setup flow
  async run() {
    try {
      console.clear();
      console.log(`${colors.bold}${colors.cyan}╔══════════════════════════════════════════════════════════════════════════════╗`);
      console.log(`║                     Claude Agent Telemetry Setup                            ║`);
      console.log(`║                      Node.js Installation System                            ║`);
      console.log(`╚══════════════════════════════════════════════════════════════════════════════╝${colors.reset}`);
      console.log();
      
      await this.checkSystemDependencies();
      await this.setupDirectories();
      await this.installBinaries();
      await this.testServices();
      await this.setupClaudeIntegration();
      await this.createScripts();
      await this.runHealthCheck();
      
      console.log();
      logHeader('Setup Complete!');
      console.log(`${colors.green}╔══════════════════════════════════════════════════════════════════════════════╗`);
      console.log(`║                              🎉 SUCCESS! 🎉                                 ║`);
      console.log(`║               Claude Agent Telemetry is ready to use!                       ║`);
      console.log(`╚══════════════════════════════════════════════════════════════════════════════╝${colors.reset}`);
      
      console.log(`\n${colors.bold}Quick Start:${colors.reset}`);
      console.log(`  ${colors.cyan}npm start${colors.reset}        - Start monitoring services`);
      console.log(`  ${colors.cyan}npm run dashboard${colors.reset} - Open Grafana dashboard`);
      console.log(`  ${colors.cyan}npm run connect${colors.reset}   - Connect a project to telemetry`);
      console.log(`  ${colors.cyan}npm run logs${colors.reset}      - View live telemetry stream`);
      
      console.log(`\n${colors.bold}Next Steps:${colors.reset}`);
      console.log(`1. Run ${colors.cyan}npm start${colors.reset} to begin monitoring`);
      console.log(`2. Navigate to any project and use Claude Code normally`);
      console.log(`3. View telemetry at ${colors.cyan}http://localhost:3000${colors.reset} (admin/admin)`);
      console.log(`\n${colors.yellow}Note:${colors.reset} Your Claude Code activity will be automatically monitored!`);
      
    } catch (error) {
      console.log();
      log('error', `Setup failed: ${error.message}`);
      console.log(`\n${colors.bold}Troubleshooting:${colors.reset}`);
      console.log(`• Check system requirements: Node.js 14+, curl`);
      console.log(`• Verify internet connection for downloads`);
      console.log(`• Run with --verbose for detailed output`);
      console.log(`• Report issues: https://github.com/D9kej5892KfW/Calcutta-packaged/issues`);
      process.exit(1);
    }
  }
}

// Run setup if called directly
if (require.main === module) {
  const setup = new Setup();
  setup.run().catch(error => {
    console.error(`Setup failed: ${error.message}`);
    process.exit(1);
  });
}

module.exports = Setup;