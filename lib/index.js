/**
 * Main entry point for Claude Agent Telemetry npm package
 * Provides programmatic API and CLI routing
 */

const path = require('path');
const BinaryManager = require('./binary-manager');

class ClaudeTelemetry {
  constructor() {
    this.binaryManager = new BinaryManager();
  }

  // Setup binaries (equivalent to npm run setup)
  async setup(options = {}) {
    try {
      return await this.binaryManager.downloadAllBinaries(options);
    } catch (error) {
      throw new Error(`Setup failed: ${error.message}`);
    }
  }

  // Check if system is ready
  async isReady() {
    try {
      const health = await this.binaryManager.checkBinariesHealth();
      return Object.values(health).every(h => h.status === 'healthy');
    } catch {
      return false;
    }
  }

  // Get binary paths
  async getBinaryPaths() {
    const paths = {};
    for (const binary of ['loki', 'grafana']) {
      paths[binary] = await this.binaryManager.getBinaryPath(binary);
    }
    return paths;
  }

  // Get health status
  async getHealth() {
    return await this.binaryManager.checkBinariesHealth();
  }
}

// CLI routing function
function routeCLI() {
  const args = process.argv.slice(2);
  const command = args[0];
  
  // Route to existing claude-telemetry script
  const scriptPath = path.join(__dirname, '..', 'scripts', 'claude-telemetry');
  const { spawn } = require('child_process');
  
  const child = spawn(scriptPath, args, {
    stdio: 'inherit',
    env: { 
      ...process.env,
      CLAUDE_TELEMETRY_NPM_MODE: 'true' // Flag to indicate npm installation
    }
  });
  
  child.on('close', (code) => {
    process.exit(code);
  });
  
  child.on('error', (error) => {
    console.error(`Failed to execute claude-telemetry: ${error.message}`);
    process.exit(1);
  });
}

// Export API for programmatic use
module.exports = ClaudeTelemetry;

// CLI entry point when called directly
if (require.main === module) {
  routeCLI();
}