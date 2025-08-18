#!/bin/bash
# Claude Agent Telemetry - One-Command Setup
# Automated installation and configuration

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_MIN_VERSION="3.8"
REQUIRED_COMMANDS=("curl" "jq")

# Logging functions
log_header() {
    echo -e "\n${BOLD}${BLUE}=== $1 ===${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}▶${NC} $1"
}

# Progress tracking
TOTAL_STEPS=10
CURRENT_STEP=0

show_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "${BOLD}[${CURRENT_STEP}/${TOTAL_STEPS}]${NC} $1"
}

# System detection
detect_system() {
    log_header "System Detection"
    
    OS_TYPE=$(uname -s)
    ARCH=$(uname -m)
    
    log_info "Operating System: $OS_TYPE"
    log_info "Architecture: $ARCH"
    
    case "$OS_TYPE" in
        Linux*)
            OS_TYPE="linux"
            ;;
        Darwin*)
            OS_TYPE="darwin"
            ;;
        *)
            log_error "Unsupported operating system: $OS_TYPE"
            log_info "Supported systems: Linux, macOS"
            exit 1
            ;;
    esac
    
    case "$ARCH" in
        x86_64|amd64)
            ARCH="x64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        *)
            log_warning "Architecture $ARCH may not be fully supported"
            ARCH="x64"  # Default fallback
            ;;
    esac
    
    log_success "System detected: $OS_TYPE-$ARCH"
}

# Check system dependencies
check_system_dependencies() {
    show_progress "Checking system dependencies"
    
    local missing_deps=()
    
    # Check required commands
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    # Check Python
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_VERSION=$(python3 -c "import sys; print('.'.join(map(str, sys.version_info[:2])))")
        log_info "Python version: $PYTHON_VERSION"
        
        # Version comparison (basic)
        if python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
            log_success "Python version is compatible"
        else
            log_error "Python 3.8+ required, found $PYTHON_VERSION"
            exit 1
        fi
    else
        missing_deps+=("python3")
    fi
    
    # Report missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        log_info "Please install the missing dependencies:"
        
        case "$OS_TYPE" in
            linux)
                log_info "Ubuntu/Debian: sudo apt update && sudo apt install ${missing_deps[*]}"
                log_info "CentOS/RHEL: sudo yum install ${missing_deps[*]}"
                log_info "Arch: sudo pacman -S ${missing_deps[*]}"
                ;;
            darwin)
                log_info "macOS: brew install ${missing_deps[*]}"
                ;;
        esac
        
        exit 1
    fi
    
    log_success "All system dependencies are available"
}

# Setup Python virtual environment
setup_python_environment() {
    show_progress "Setting up Python environment"
    
    local venv_dir="$PROJECT_DIR/venv"
    
    if [ -d "$venv_dir" ]; then
        log_info "Virtual environment already exists"
    else
        log_step "Creating Python virtual environment"
        python3 -m venv "$venv_dir"
        log_success "Virtual environment created"
    fi
    
    # Activate virtual environment
    source "$venv_dir/bin/activate"
    
    # Upgrade pip
    log_step "Upgrading pip"
    python -m pip install --upgrade pip >/dev/null 2>&1
    
    # Install Python dependencies
    log_step "Installing Python dependencies"
    if [ -f "$PROJECT_DIR/requirements.txt" ]; then
        python -m pip install -r "$PROJECT_DIR/requirements.txt" >/dev/null 2>&1
        log_success "Python dependencies installed"
    else
        log_warning "requirements.txt not found, skipping Python dependencies"
    fi
}

# Validate binaries
validate_binaries() {
    show_progress "Validating included binaries"
    
    local loki_bin="$PROJECT_DIR/bin/loki"
    local grafana_bin="$PROJECT_DIR/bin/grafana"
    
    # Check Loki
    if [ -x "$loki_bin" ]; then
        if "$loki_bin" --version >/dev/null 2>&1; then
            local loki_version=$("$loki_bin" --version 2>&1 | head -1)
            log_success "Loki binary valid: $loki_version"
        else
            log_warning "Loki binary may not be compatible with this system"
        fi
    else
        log_error "Loki binary not found or not executable: $loki_bin"
        exit 1
    fi
    
    # Check Grafana
    if [ -x "$grafana_bin" ]; then
        log_success "Grafana binary found and executable"
    else
        log_error "Grafana binary not found or not executable: $grafana_bin"
        exit 1
    fi
}

# Setup directories and permissions
setup_directories() {
    show_progress "Setting up directories and permissions"
    
    # Create necessary directories
    local dirs=(
        "$PROJECT_DIR/data/loki/chunks"
        "$PROJECT_DIR/data/loki/rules"
        "$PROJECT_DIR/data/logs"
        "$PROJECT_DIR/data/grafana"
        "$PROJECT_DIR/logs"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    
    # Fix script permissions
    find "$PROJECT_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
    chmod +x "$PROJECT_DIR/config/claude/hooks/telemetry-hook.sh" 2>/dev/null || true
    
    log_success "Directories and permissions configured"
}

# Test Loki startup
test_loki() {
    show_progress "Testing Loki service"
    
    log_step "Starting Loki for validation"
    
    # Start Loki temporarily
    "$PROJECT_DIR/scripts/start-loki.sh" >/dev/null 2>&1
    
    # Wait for startup
    sleep 5
    
    # Test HTTP endpoint
    if curl -s "http://localhost:3100/ready" >/dev/null 2>&1; then
        log_success "Loki service test passed"
    else
        log_error "Loki service test failed"
        exit 1
    fi
    
    # Stop Loki
    "$PROJECT_DIR/scripts/stop-loki.sh" >/dev/null 2>&1
}

# Setup Claude Code integration
setup_claude_integration() {
    show_progress "Setting up Claude Code integration"
    
    if [ -f "$PROJECT_DIR/scripts/lib/maintenance/install-claude-commands.sh" ]; then
        log_step "Installing Claude Code commands"
        "$PROJECT_DIR/scripts/lib/maintenance/install-claude-commands.sh"
        log_success "Claude Code integration configured"
    else
        log_warning "Claude Code integration script not found"
    fi
}

# Generate startup scripts
create_convenience_scripts() {
    show_progress "Creating convenience scripts"
    
    # Create start-all script if it doesn't exist
    if [ ! -f "$PROJECT_DIR/scripts/start-all.sh" ]; then
        cat > "$PROJECT_DIR/scripts/start-all.sh" << 'EOF'
#!/bin/bash
# Start all telemetry services
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Starting Claude Agent Telemetry services..."
"$PROJECT_DIR/scripts/start-loki.sh"
sleep 2
"$PROJECT_DIR/scripts/start-grafana.sh"
echo "Services started. Dashboard: http://localhost:3000 (admin/admin)"
EOF
        chmod +x "$PROJECT_DIR/scripts/start-all.sh"
    fi
    
    # Create health check script
    if [ ! -f "$PROJECT_DIR/scripts/health-check.sh" ]; then
        cat > "$PROJECT_DIR/scripts/health-check.sh" << 'EOF'
#!/bin/bash
# Health check for telemetry system
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Claude Agent Telemetry - Health Check"
echo "====================================="

# Check Loki
if curl -s "http://localhost:3100/ready" >/dev/null 2>&1; then
    echo "✅ Loki: Healthy"
else
    echo "❌ Loki: Not responding"
fi

# Check Grafana
if curl -s "http://localhost:3000/api/health" >/dev/null 2>&1; then
    echo "✅ Grafana: Healthy"
else
    echo "❌ Grafana: Not responding"
fi

# Check Python dependencies
if python3 -c "import pandas, numpy, sklearn, joblib, requests" 2>/dev/null; then
    echo "✅ Python dependencies: Available"
else
    echo "❌ Python dependencies: Missing"
fi
EOF
        chmod +x "$PROJECT_DIR/scripts/health-check.sh"
    fi
    
    # Create dashboard opener
    if [ ! -f "$PROJECT_DIR/scripts/open-dashboard.sh" ]; then
        cat > "$PROJECT_DIR/scripts/open-dashboard.sh" << 'EOF'
#!/bin/bash
# Open Grafana dashboard
echo "Opening Grafana dashboard..."
if command -v open >/dev/null 2>&1; then
    open "http://localhost:3000"
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "http://localhost:3000"
elif command -v sensible-browser >/dev/null 2>&1; then
    sensible-browser "http://localhost:3000"
else
    echo "Please open http://localhost:3000 in your browser"
    echo "Login: admin/admin"
fi
EOF
        chmod +x "$PROJECT_DIR/scripts/open-dashboard.sh"
    fi
    
    log_success "Convenience scripts created"
}

# Run health check
run_health_check() {
    show_progress "Running final health check"
    
    if [ -f "$PROJECT_DIR/scripts/health-check.sh" ]; then
        "$PROJECT_DIR/scripts/health-check.sh"
    fi
}

# Main setup flow
main() {
    clear
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                     Claude Agent Telemetry Setup                            ║"
    echo "║                         One-Command Installation                             ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    detect_system
    check_system_dependencies
    setup_python_environment
    validate_binaries
    setup_directories
    test_loki
    setup_claude_integration
    create_convenience_scripts
    run_health_check
    
    echo ""
    log_header "Setup Complete!"
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                              🎉 SUCCESS! 🎉                                 ║"
    echo "║               Claude Agent Telemetry is ready to use!                       ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Detect installation method and show appropriate commands
    if [[ "${CLAUDE_TELEMETRY_NPM_MODE:-}" == "true" ]] || [[ "$PROJECT_DIR" == *"node_modules"* ]] || [[ "$PROJECT_DIR" == *".npm"* ]]; then
        # NPM package installation - use claude-telemetry commands
        echo -e "${BOLD}Quick Start:${NC}"
        echo -e "  ${CYAN}claude-telemetry start${NC}     - Start monitoring services"
        echo -e "  ${CYAN}claude-telemetry dashboard${NC} - Open Grafana dashboard"
        echo -e "  ${CYAN}claude-telemetry connect${NC}   - Connect a project to telemetry"
        echo -e "  ${CYAN}claude-telemetry logs${NC}      - View live telemetry stream"
        echo ""
        echo -e "${BOLD}Next Steps:${NC}"
        echo -e "1. Run ${CYAN}claude-telemetry start${NC} to begin monitoring"
    else
        # Repository installation - use npm commands
        echo -e "${BOLD}Quick Start:${NC}"
        echo -e "  ${CYAN}npm start${NC}        - Start monitoring services"
        echo -e "  ${CYAN}npm run dashboard${NC} - Open Grafana dashboard"
        echo -e "  ${CYAN}npm run connect${NC}   - Connect a project to telemetry"
        echo -e "  ${CYAN}npm run logs${NC}      - View live telemetry stream"
        echo ""
        echo -e "${BOLD}Next Steps:${NC}"
        echo -e "1. Run ${CYAN}npm start${NC} to begin monitoring"
    fi
    echo -e "2. Navigate to any project and use Claude Code normally"
    echo -e "3. View telemetry at ${CYAN}http://localhost:3000${NC} (admin/admin)"
    echo ""
    echo -e "${YELLOW}Note:${NC} Your Claude Code activity will be automatically monitored!"
}

# Handle errors gracefully
trap 'log_error "Setup failed. Check the output above for details."' ERR

# Run main setup
main "$@"