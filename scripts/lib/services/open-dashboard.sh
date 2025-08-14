#!/bin/bash
# Open Grafana dashboard in the default browser

echo "🌐 Opening Grafana dashboard..."

# Check if Grafana is running
if ! curl -s -f "http://localhost:3000/api/health" >/dev/null 2>&1; then
    echo "❌ Grafana is not running"
    echo "💡 Start it with: npm start"
    exit 1
fi

# Try different browser opening commands based on OS
if command -v open >/dev/null 2>&1; then
    # macOS
    open "http://localhost:3000"
elif command -v xdg-open >/dev/null 2>&1; then
    # Linux with desktop environment
    xdg-open "http://localhost:3000"
elif command -v sensible-browser >/dev/null 2>&1; then
    # Debian/Ubuntu alternative
    sensible-browser "http://localhost:3000"
elif command -v firefox >/dev/null 2>&1; then
    # Try Firefox directly
    firefox "http://localhost:3000" &
elif command -v google-chrome >/dev/null 2>&1; then
    # Try Chrome directly
    google-chrome "http://localhost:3000" &
elif command -v chromium >/dev/null 2>&1; then
    # Try Chromium directly
    chromium "http://localhost:3000" &
else
    # Fallback - show manual instructions
    echo "🖥️ Please open the following URL in your browser:"
    echo ""
    echo "   🔗 http://localhost:3000"
    echo ""
    echo "📋 Login credentials:"
    echo "   Username: admin"
    echo "   Password: admin"
    exit 0
fi

echo "✅ Dashboard opened in your default browser"
echo ""
echo "📋 Login credentials:"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "🔍 If the browser didn't open, visit: http://localhost:3000"