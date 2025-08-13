#!/usr/bin/env python3
"""
Simple local telemetry dashboard API
Serves data directly from JSON log file - bypasses Loki complexity
"""

import json
import os
from datetime import datetime, timedelta
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse
import sys

class TelemetryHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/telemetry':
            self.serve_telemetry()
        elif self.path == '/':
            self.serve_dashboard()
        else:
            self.send_error(404)

    def serve_telemetry(self):
        """Serve telemetry data as JSON API"""
        try:
            log_file = '/home/jeff/claude-code/agent-telemetry/data/logs/claude-telemetry.jsonl'
            data = []
            
            if os.path.exists(log_file):
                with open(log_file, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if line:
                            try:
                                entry = json.loads(line)
                                data.append(entry)
                            except json.JSONDecodeError:
                                continue
            
            # Get latest 100 entries
            recent_data = data[-100:] if len(data) > 100 else data
            
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            response = {
                'status': 'success',
                'total_entries': len(data),
                'returned_entries': len(recent_data),
                'data': recent_data
            }
            
            self.wfile.write(json.dumps(response, indent=2).encode())
            
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode())

    def serve_dashboard(self):
        """Serve simple HTML dashboard"""
        html = '''<!DOCTYPE html>
<html>
<head>
    <title>Claude Agent Telemetry - Local Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2196F3; color: white; padding: 20px; border-radius: 5px; }
        .stats { display: flex; gap: 20px; margin: 20px 0; }
        .stat-card { background: #f5f5f5; padding: 15px; border-radius: 5px; }
        .entries { max-height: 600px; overflow-y: auto; border: 1px solid #ddd; }
        .entry { border-bottom: 1px solid #eee; padding: 10px; font-size: 12px; }
        .entry:nth-child(even) { background: #f9f9f9; }
        .tool { font-weight: bold; color: #2196F3; }
        .timestamp { color: #666; font-size: 10px; }
        .error { color: red; background: #ffe6e6; padding: 10px; border-radius: 5px; }
        .success { color: green; background: #e6ffe6; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔍 Claude Agent Telemetry Dashboard</h1>
        <p>Local JSON-based monitoring (bypasses Loki)</p>
    </div>
    
    <div id="status">Loading...</div>
    
    <div class="stats">
        <div class="stat-card">
            <h3>Total Entries</h3>
            <div id="total">-</div>
        </div>
        <div class="stat-card">
            <h3>Recent Entries</h3>
            <div id="recent">-</div>
        </div>
        <div class="stat-card">
            <h3>Last Update</h3>
            <div id="lastUpdate">-</div>
        </div>
    </div>
    
    <h2>Recent Activity (Last 100 entries)</h2>
    <div id="entries" class="entries"></div>
    
    <script>
    function loadTelemetry() {
        fetch('/api/telemetry')
            .then(response => response.json())
            .then(data => {
                if (data.error) {
                    document.getElementById('status').innerHTML = '<div class="error">Error: ' + data.error + '</div>';
                    return;
                }
                
                document.getElementById('status').innerHTML = '<div class="success">✅ Connected - Dashboard working without JSON parsing errors!</div>';
                document.getElementById('total').textContent = data.total_entries;
                document.getElementById('recent').textContent = data.returned_entries;
                document.getElementById('lastUpdate').textContent = new Date().toLocaleTimeString();
                
                const entriesDiv = document.getElementById('entries');
                entriesDiv.innerHTML = '';
                
                data.data.reverse().forEach(entry => {
                    const div = document.createElement('div');
                    div.className = 'entry';
                    div.innerHTML = `
                        <div class="timestamp">${entry.timestamp}</div>
                        <span class="tool">${entry.tool_name}</span> - ${entry.event_type} - ${entry.hook_event}
                        ${entry.action_details.command ? '<br>Command: ' + entry.action_details.command : ''}
                        ${entry.action_details.file_path ? '<br>File: ' + entry.action_details.file_path : ''}
                    `;
                    entriesDiv.appendChild(div);
                });
            })
            .catch(error => {
                document.getElementById('status').innerHTML = '<div class="error">Connection Error: ' + error + '</div>';
            });
    }
    
    loadTelemetry();
    setInterval(loadTelemetry, 5000); // Refresh every 5 seconds
    </script>
</body>
</html>'''
        
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())

if __name__ == '__main__':
    port = 8080
    server = HTTPServer(('localhost', port), TelemetryHandler)
    print(f"🚀 Local Telemetry Dashboard running at http://localhost:{port}")
    print("📊 This bypasses Loki and reads JSON directly - no parsing errors!")
    print("🔄 Auto-refreshes every 5 seconds")
    print("Press Ctrl+C to stop")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 Dashboard stopped")
        server.shutdown()