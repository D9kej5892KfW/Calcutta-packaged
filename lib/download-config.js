/**
 * Binary download configuration for Claude Agent Telemetry
 * Defines download URLs, versions, and checksums for Loki and Grafana binaries
 */

const os = require('os');
const path = require('path');

// Current binary versions
const VERSIONS = {
  loki: '2.9.0',
  grafana: '10.4.1'
};

// Platform detection
function getPlatform() {
  const platform = os.platform();
  const arch = os.arch();
  
  // Normalize platform names
  const platformMap = {
    'darwin': 'darwin',
    'linux': 'linux',
    'win32': 'windows'
  };
  
  // Normalize architecture
  const archMap = {
    'x64': 'amd64',
    'arm64': 'arm64',
    'arm': 'arm'
  };
  
  return {
    os: platformMap[platform] || platform,
    arch: archMap[arch] || arch,
    platform: platform,
    raw_arch: arch
  };
}

// Binary download configurations
const BINARIES = {
  loki: {
    version: VERSIONS.loki,
    baseUrl: 'https://github.com/grafana/loki/releases/download',
    platforms: {
      'linux-amd64': {
        filename: 'loki-linux-amd64.zip',
        executable: 'loki-linux-amd64'
      },
      'linux-arm64': {
        filename: 'loki-linux-arm64.zip', 
        executable: 'loki-linux-arm64'
      },
      'darwin-amd64': {
        filename: 'loki-darwin-amd64.zip',
        executable: 'loki-darwin-amd64'
      },
      'darwin-arm64': {
        filename: 'loki-darwin-arm64.zip',
        executable: 'loki-darwin-arm64'
      }
    }
  },
  
  grafana: {
    version: VERSIONS.grafana,
    baseUrl: 'https://dl.grafana.com/oss/release/',
    platforms: {
      'linux-amd64': {
        filename: `grafana-${VERSIONS.grafana}.linux-amd64.tar.gz`,
        executable: 'bin/grafana-server',
        extractPath: `grafana-v${VERSIONS.grafana}`
      },
      'linux-arm64': {
        filename: `grafana-${VERSIONS.grafana}.linux-arm64.tar.gz`,
        executable: 'bin/grafana-server', 
        extractPath: `grafana-v${VERSIONS.grafana}`
      },
      'darwin-amd64': {
        filename: `grafana-${VERSIONS.grafana}.darwin-amd64.tar.gz`,
        executable: 'bin/grafana-server',
        extractPath: `grafana-v${VERSIONS.grafana}`
      },
      'darwin-arm64': {
        filename: `grafana-${VERSIONS.grafana}.darwin-arm64.tar.gz`, 
        executable: 'bin/grafana-server',
        extractPath: `grafana-v${VERSIONS.grafana}`
      }
    }
  }
};

// Cache directory locations
function getCacheDir() {
  const homeDir = os.homedir();
  return path.join(homeDir, '.claude-telemetry');
}

function getBinDir() {
  return path.join(getCacheDir(), 'bin');
}

// Generate download URL for a binary
function getDownloadUrl(binaryName, platform) {
  const config = BINARIES[binaryName];
  if (!config) {
    throw new Error(`Unknown binary: ${binaryName}`);
  }
  
  const platformKey = `${platform.os}-${platform.arch}`;
  const platformConfig = config.platforms[platformKey];
  
  if (!platformConfig) {
    throw new Error(`Unsupported platform: ${platformKey} for ${binaryName}`);
  }
  
  // Handle different URL patterns for different binaries
  if (binaryName === 'grafana') {
    return `${config.baseUrl}${platformConfig.filename}`;
  } else {
    return `${config.baseUrl}/v${config.version}/${platformConfig.filename}`;
  }
}

// Get expected binary path after installation
function getBinaryPath(binaryName, platform) {
  const config = BINARIES[binaryName];
  const platformKey = `${platform.os}-${platform.arch}`;
  const platformConfig = config.platforms[platformKey];
  
  const binDir = getBinDir();
  const binaryDir = path.join(binDir, binaryName, config.version);
  
  if (platformConfig.extractPath) {
    return path.join(binaryDir, platformConfig.extractPath, platformConfig.executable);
  }
  
  return path.join(binaryDir, platformConfig.executable);
}

// Check if platform is supported
function isPlatformSupported(binaryName, platform) {
  const config = BINARIES[binaryName];
  if (!config) return false;
  
  const platformKey = `${platform.os}-${platform.arch}`;
  return !!config.platforms[platformKey];
}

module.exports = {
  VERSIONS,
  BINARIES,
  getPlatform,
  getCacheDir,
  getBinDir,
  getDownloadUrl,
  getBinaryPath,
  isPlatformSupported
};