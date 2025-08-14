#!/bin/bash
# Claude Agent Telemetry - Comprehensive Health Check

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Claude Agent Telemetry - Health Check${NC}"
echo "====================================="

# Check Loki service
echo -n "Loki Service: "
if curl -s -f "http://localhost:3100/ready" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Healthy${NC}"
    LOKI_STATUS="healthy"
else
    echo -e "${RED}❌ Not responding${NC}"
    LOKI_STATUS="unhealthy"
fi

# Check Grafana service  
echo -n "Grafana Service: "
if curl -s -f "http://localhost:3000/api/health" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Healthy${NC}"
    GRAFANA_STATUS="healthy"
else
    echo -e "${RED}❌ Not responding${NC}"
    GRAFANA_STATUS="unhealthy"
fi

# Check Python dependencies
echo -n "Python Dependencies: "
if python3 -c "import pandas, numpy, sklearn, joblib, requests" 2>/dev/null; then
    echo -e "${GREEN}✅ Available${NC}"
    PYTHON_STATUS="available"
else
    echo -e "${RED}❌ Missing${NC}"
    PYTHON_STATUS="missing"
fi

# Check system dependencies
echo -n "System Dependencies: "
missing_deps=()
for cmd in curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_deps+=("$cmd")
    fi
done

if [ ${#missing_deps[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ Available${NC}"
    SYSTEM_STATUS="available"
else
    echo -e "${RED}❌ Missing: ${missing_deps[*]}${NC}"
    SYSTEM_STATUS="missing"
fi

# Check data directories
echo -n "Data Directories: "
required_dirs=(
    "$PROJECT_DIR/data/loki"
    "$PROJECT_DIR/data/logs"
    "$PROJECT_DIR/data/grafana"
    "$PROJECT_DIR/logs"
)

missing_dirs=()
for dir in "${required_dirs[@]}"; do
    if [ ! -d "$dir" ]; then
        missing_dirs+=("$dir")
    fi
done

if [ ${#missing_dirs[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ Present${NC}"
    DIRS_STATUS="present"
else
    echo -e "${RED}❌ Missing: ${#missing_dirs[@]} directories${NC}"
    DIRS_STATUS="missing"
fi

# Check telemetry data
echo -n "Telemetry Data: "
if [ -f "$PROJECT_DIR/data/logs/claude-telemetry.jsonl" ]; then
    entry_count=$(wc -l < "$PROJECT_DIR/data/logs/claude-telemetry.jsonl" 2>/dev/null || echo "0")
    echo -e "${GREEN}✅ $entry_count entries${NC}"
else
    echo -e "${YELLOW}⚠ No data yet${NC}"
fi

# Check configuration files
echo -n "Configuration: "
config_files=(
    "$PROJECT_DIR/config/loki/loki.yaml"
    "$PROJECT_DIR/config/grafana/grafana.ini"
    "$PROJECT_DIR/config/claude/settings.json"
)

missing_configs=()
for file in "${config_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_configs+=("$(basename "$file")")
    fi
done

if [ ${#missing_configs[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ Complete${NC}"
    CONFIG_STATUS="complete"
else
    echo -e "${RED}❌ Missing: ${missing_configs[*]}${NC}"
    CONFIG_STATUS="missing"
fi

# Overall health assessment
echo ""
echo "Overall Health Assessment:"
echo "========================="

if [[ "$LOKI_STATUS" == "healthy" && "$GRAFANA_STATUS" == "healthy" && "$PYTHON_STATUS" == "available" && "$SYSTEM_STATUS" == "available" ]]; then
    echo -e "${GREEN}🎉 System is fully operational!${NC}"
    echo ""
    echo "You can:"
    echo "• View dashboards at http://localhost:3000"
    echo "• Query Loki at http://localhost:3100"
    echo "• Connect projects with 'npm run connect'"
    exit 0
elif [[ "$LOKI_STATUS" == "unhealthy" || "$GRAFANA_STATUS" == "unhealthy" ]]; then
    echo -e "${YELLOW}⚠ Services need attention${NC}"
    echo ""
    echo "Try:"
    echo "• npm start    - Start services"
    echo "• npm restart  - Restart services"
    exit 1
else
    echo -e "${RED}❌ System requires setup${NC}"
    echo ""
    echo "Run: npm run setup"
    exit 2
fi