#!/bin/bash
# Validate Claude Agent Telemetry setup before first use

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}Claude Agent Telemetry - Setup Validation${NC}"
echo "========================================="

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Testing $test_name: "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        return 1
    fi
}

# Test system dependencies
echo -e "\n${BOLD}System Dependencies:${NC}"
run_test "curl command" "command -v curl"
run_test "jq command" "command -v jq"
run_test "python3 command" "command -v python3"
run_test "python3 version" "python3 -c 'import sys; exit(0 if sys.version_info >= (3, 8) else 1)'"

# Test Python dependencies
echo -e "\n${BOLD}Python Dependencies:${NC}"
run_test "pandas library" "python3 -c 'import pandas'"
run_test "numpy library" "python3 -c 'import numpy'"
run_test "scikit-learn library" "python3 -c 'import sklearn'"
run_test "joblib library" "python3 -c 'import joblib'"
run_test "requests library" "python3 -c 'import requests'"

# Test binary executables
echo -e "\n${BOLD}Binary Executables:${NC}"
run_test "loki binary" "[ -x '$PROJECT_DIR/bin/loki' ]"
run_test "grafana binary" "[ -x '$PROJECT_DIR/bin/grafana' ]"
run_test "loki version check" "'$PROJECT_DIR/bin/loki' --version"

# Test directory structure
echo -e "\n${BOLD}Directory Structure:${NC}"
run_test "data/loki directory" "[ -d '$PROJECT_DIR/data/loki' ]"
run_test "data/logs directory" "[ -d '$PROJECT_DIR/data/logs' ]"
run_test "logs directory" "[ -d '$PROJECT_DIR/logs' ]"
run_test "config directory" "[ -d '$PROJECT_DIR/config' ]"

# Test configuration files
echo -e "\n${BOLD}Configuration Files:${NC}"
run_test "loki config" "[ -f '$PROJECT_DIR/config/loki/loki.yaml' ]"
run_test "grafana config" "[ -f '$PROJECT_DIR/config/grafana/grafana.ini' ]"
run_test "claude config" "[ -f '$PROJECT_DIR/config/claude/settings.json' ]"
run_test "telemetry hook" "[ -x '$PROJECT_DIR/config/claude/hooks/telemetry-hook.sh' ]"

# Test script permissions
echo -e "\n${BOLD}Script Permissions:${NC}"
run_test "start-loki.sh" "[ -x '$PROJECT_DIR/scripts/start-loki.sh' ]"
run_test "start-grafana.sh" "[ -x '$PROJECT_DIR/scripts/start-grafana.sh' ]"
run_test "status.sh" "[ -x '$PROJECT_DIR/scripts/status.sh' ]"
run_test "connect-project.sh" "[ -x '$PROJECT_DIR/scripts/connect-project.sh' ]"

# Test Loki startup (if not already running)
echo -e "\n${BOLD}Service Startup Test:${NC}"
if ! curl -s "http://localhost:3100/ready" >/dev/null 2>&1; then
    run_test "loki startup" "'$PROJECT_DIR/scripts/start-loki.sh' && sleep 3 && curl -s 'http://localhost:3100/ready' >/dev/null"
    # Clean up - stop loki after test
    "$PROJECT_DIR/scripts/stop-loki.sh" >/dev/null 2>&1
else
    echo "Loki service: ${GREEN}✅ Already running${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
fi

# Summary
echo ""
echo "========================================"
echo -e "${BOLD}Validation Summary:${NC}"
echo "Passed: $PASSED_TESTS / $TOTAL_TESTS tests"

if [ "$PASSED_TESTS" -eq "$TOTAL_TESTS" ]; then
    echo -e "${GREEN}🎉 All tests passed! System is ready to use.${NC}"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "1. npm start           - Start monitoring services"
    echo "2. npm run connect     - Connect a project"
    echo "3. npm run dashboard   - Open Grafana dashboard"
    exit 0
else
    failed_tests=$((TOTAL_TESTS - PASSED_TESTS))
    echo -e "${RED}❌ $failed_tests test(s) failed. Please check the output above.${NC}"
    echo ""
    echo -e "${BOLD}Troubleshooting:${NC}"
    echo "• Run 'npm run setup' to fix common issues"
    echo "• Check system dependencies installation"
    echo "• Verify Python virtual environment setup"
    exit 1
fi