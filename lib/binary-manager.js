/**
 * Binary Manager for Claude Agent Telemetry
 * Handles downloading, extracting, and managing Loki/Grafana binaries
 */

const fs = require('fs').promises;
const fsSync = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');
const yauzl = require('yauzl');
const { 
  getPlatform, 
  getCacheDir, 
  getBinDir, 
  getDownloadUrl, 
  getBinaryPath, 
  isPlatformSupported,
  VERSIONS
} = require('./download-config');

class BinaryManager {
  constructor() {
    this.platform = getPlatform();
    this.cacheDir = getCacheDir();
    this.binDir = getBinDir();
  }

  // Ensure cache directories exist
  async ensureCacheDir() {
    try {
      await fs.mkdir(this.cacheDir, { recursive: true });
      await fs.mkdir(this.binDir, { recursive: true });
      
      // Create version tracking file if it doesn't exist
      const versionFile = path.join(this.cacheDir, 'versions.json');
      try {
        await fs.access(versionFile);
      } catch {
        await fs.writeFile(versionFile, JSON.stringify({}), 'utf8');
      }
    } catch (error) {
      throw new Error(`Failed to create cache directory: ${error.message}`);
    }
  }

  // Check if binary is already installed and up to date
  async isBinaryInstalled(binaryName) {
    try {
      const binaryPath = getBinaryPath(binaryName, this.platform);
      const versionFile = path.join(this.cacheDir, 'versions.json');
      
      // Check if binary file exists
      await fs.access(binaryPath, fsSync.constants.X_OK);
      
      // Check version
      const versions = JSON.parse(await fs.readFile(versionFile, 'utf8'));
      const installedVersion = versions[binaryName];
      const expectedVersion = VERSIONS[binaryName];
      
      return installedVersion === expectedVersion;
    } catch {
      return false;
    }
  }

  // Download a file with progress
  async downloadFile(url, filePath, onProgress = null) {
    return new Promise((resolve, reject) => {
      const file = fsSync.createWriteStream(filePath);
      
      https.get(url, (response) => {
        // Handle redirects
        if (response.statusCode === 301 || response.statusCode === 302) {
          file.close();
          fsSync.unlinkSync(filePath);
          return this.downloadFile(response.headers.location, filePath, onProgress)
            .then(resolve)
            .catch(reject);
        }
        
        if (response.statusCode !== 200) {
          file.close();
          fsSync.unlinkSync(filePath);
          return reject(new Error(`HTTP ${response.statusCode}: ${response.statusMessage}`));
        }
        
        const totalSize = parseInt(response.headers['content-length'], 10);
        let downloadedSize = 0;
        
        response.on('data', (chunk) => {
          downloadedSize += chunk.length;
          if (onProgress && totalSize) {
            const percent = Math.round((downloadedSize / totalSize) * 100);
            onProgress(downloadedSize, totalSize, percent);
          }
        });
        
        response.pipe(file);
        
        file.on('finish', () => {
          file.close();
          resolve(filePath);
        });
        
        file.on('error', (error) => {
          file.close();
          fsSync.unlinkSync(filePath);
          reject(error);
        });
      }).on('error', (error) => {
        if (fsSync.existsSync(filePath)) {
          fsSync.unlinkSync(filePath);
        }
        reject(error);
      });
    });
  }

  // Extract downloaded archive using Node.js
  async extractArchive(archivePath, extractDir) {
    await fs.mkdir(extractDir, { recursive: true });
    
    const ext = path.extname(archivePath).toLowerCase();
    
    try {
      if (ext === '.zip') {
        await this.extractZip(archivePath, extractDir);
      } else if (ext === '.gz' && archivePath.includes('.tar.gz')) {
        // Use system tar command
        execSync(`tar -xzf "${archivePath}" -C "${extractDir}"`, { stdio: 'pipe' });
      } else {
        throw new Error(`Unsupported archive format: ${ext}`);
      }
    } catch (error) {
      throw new Error(`Failed to extract ${archivePath}: ${error.message}`);
    }
  }

  // Extract ZIP file using Node.js yauzl library
  async extractZip(zipPath, extractDir) {
    return new Promise((resolve, reject) => {
      yauzl.open(zipPath, { lazyEntries: true }, (err, zipfile) => {
        if (err) return reject(err);
        
        zipfile.readEntry();
        zipfile.on('entry', (entry) => {
          if (/\/$/.test(entry.fileName)) {
            // Directory entry
            zipfile.readEntry();
          } else {
            // File entry
            const filePath = path.join(extractDir, entry.fileName);
            const fileDir = path.dirname(filePath);
            
            // Ensure directory exists
            fsSync.mkdirSync(fileDir, { recursive: true });
            
            zipfile.openReadStream(entry, (err, readStream) => {
              if (err) return reject(err);
              
              const writeStream = fsSync.createWriteStream(filePath);
              readStream.pipe(writeStream);
              
              writeStream.on('close', () => {
                // Set executable permission for binary files
                if (entry.fileName.includes('loki') || entry.fileName.includes('grafana')) {
                  try {
                    fsSync.chmodSync(filePath, 0o755);
                  } catch (chmodErr) {
                    // Ignore chmod errors on Windows
                  }
                }
                zipfile.readEntry();
              });
              
              writeStream.on('error', reject);
            });
          }
        });
        
        zipfile.on('end', resolve);
        zipfile.on('error', reject);
      });
    });
  }

  // Download and install a binary
  async downloadBinary(binaryName, options = {}) {
    const { onProgress = null, force = false } = options;
    
    console.log(`📦 Installing ${binaryName}...`);
    
    // Check platform support
    if (!isPlatformSupported(binaryName, this.platform)) {
      throw new Error(`${binaryName} is not supported on ${this.platform.os}-${this.platform.arch}`);
    }
    
    // Check if already installed (unless forced)
    if (!force && await this.isBinaryInstalled(binaryName)) {
      console.log(`✅ ${binaryName} is already installed and up to date`);
      return getBinaryPath(binaryName, this.platform);
    }
    
    await this.ensureCacheDir();
    
    // Setup paths
    const downloadUrl = getDownloadUrl(binaryName, this.platform);
    const filename = path.basename(downloadUrl);
    const downloadPath = path.join(this.cacheDir, 'downloads', filename);
    const extractDir = path.join(this.binDir, binaryName, VERSIONS[binaryName]);
    
    try {
      // Create downloads directory
      await fs.mkdir(path.dirname(downloadPath), { recursive: true });
      
      // Download
      console.log(`📥 Downloading ${binaryName} from ${downloadUrl}`);
      await this.downloadFile(downloadUrl, downloadPath, onProgress);
      
      // Extract
      console.log(`📂 Extracting ${binaryName}...`);
      await this.extractArchive(downloadPath, extractDir);
      
      // Verify binary exists and make executable
      const binaryPath = getBinaryPath(binaryName, this.platform);
      await fs.access(binaryPath);
      await fs.chmod(binaryPath, 0o755);
      
      // Update version tracking
      const versionFile = path.join(this.cacheDir, 'versions.json');
      const versions = JSON.parse(await fs.readFile(versionFile, 'utf8'));
      versions[binaryName] = VERSIONS[binaryName];
      await fs.writeFile(versionFile, JSON.stringify(versions, null, 2));
      
      // Cleanup download
      await fs.unlink(downloadPath);
      
      console.log(`✅ ${binaryName} installed successfully`);
      return binaryPath;
      
    } catch (error) {
      // Cleanup on failure
      try {
        if (fsSync.existsSync(downloadPath)) {
          await fs.unlink(downloadPath);
        }
        if (fsSync.existsSync(extractDir)) {
          await fs.rmdir(extractDir, { recursive: true });
        }
      } catch (cleanupError) {
        console.warn(`Warning: Failed to cleanup after error: ${cleanupError.message}`);
      }
      
      throw new Error(`Failed to install ${binaryName}: ${error.message}`);
    }
  }

  // Download all required binaries
  async downloadAllBinaries(options = {}) {
    console.log('🚀 Setting up Claude Agent Telemetry binaries...');
    
    const binaries = ['loki', 'grafana'];
    const results = {};
    
    for (const binary of binaries) {
      try {
        results[binary] = await this.downloadBinary(binary, options);
      } catch (error) {
        console.error(`❌ Failed to install ${binary}: ${error.message}`);
        throw error;
      }
    }
    
    console.log('✅ All binaries installed successfully!');
    return results;
  }

  // Get path to installed binary
  async getBinaryPath(binaryName) {
    if (await this.isBinaryInstalled(binaryName)) {
      return getBinaryPath(binaryName, this.platform);
    }
    return null;
  }

  // Check health of all binaries
  async checkBinariesHealth() {
    const health = {};
    
    for (const binaryName of ['loki', 'grafana']) {
      try {
        const binaryPath = await this.getBinaryPath(binaryName);
        if (binaryPath) {
          // Test binary execution
          if (binaryName === 'loki') {
            execSync(`"${binaryPath}" --version`, { stdio: 'pipe', timeout: 5000 });
          } else if (binaryName === 'grafana') {
            execSync(`"${binaryPath}" --version`, { stdio: 'pipe', timeout: 5000 });
          }
          health[binaryName] = { status: 'healthy', path: binaryPath };
        } else {
          health[binaryName] = { status: 'missing', path: null };
        }
      } catch (error) {
        health[binaryName] = { 
          status: 'error', 
          path: await this.getBinaryPath(binaryName),
          error: error.message 
        };
      }
    }
    
    return health;
  }
}

module.exports = BinaryManager;