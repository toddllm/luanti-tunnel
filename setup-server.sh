#!/bin/bash

# Minetest/Luanti Server Setup Script for FRP Tunnel
# Run this on your Linux server

set -e

echo "=== Minetest/Luanti FRP Server Setup ==="
echo

# Configuration
FRP_VERSION="0.64.0"
FRP_DIR="/tmp/frp_${FRP_VERSION}_linux_amd64"
MINETEST_PORT="30000"
FRP_PORT="7000"

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo "Warning: Running as root. Consider using a regular user."
fi

# Download FRP if not exists
if [ ! -d "$FRP_DIR" ]; then
    echo "Downloading FRP v${FRP_VERSION}..."
    cd /tmp
    wget -q "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz"
    tar -xzf "frp_${FRP_VERSION}_linux_amd64.tar.gz"
    echo "FRP downloaded and extracted."
else
    echo "FRP already exists at $FRP_DIR"
fi

cd "$FRP_DIR"

# Kill any existing FRP processes
echo "Stopping any existing FRP processes..."
pkill frps 2>/dev/null || true
pkill frpc 2>/dev/null || true
sleep 1

# Create FRP server config
echo "Creating FRP server configuration..."
cat > frps.toml << EOF
bindPort = ${FRP_PORT}
EOF

# Create FRP client config (to expose Minetest)
echo "Creating FRP client configuration..."
cat > frpc_server.toml << EOF
serverAddr = "127.0.0.1"
serverPort = ${FRP_PORT}

[[proxies]]
name = "minetest-udp"
type = "sudp"
localIP = "127.0.0.1"
localPort = ${MINETEST_PORT}
EOF

# Check if Minetest is running
if netstat -uln | grep -q ":${MINETEST_PORT}"; then
    echo "✓ Minetest server detected on port ${MINETEST_PORT}"
else
    echo "⚠ Warning: No service detected on UDP port ${MINETEST_PORT}"
    echo "  Make sure Minetest server is running!"
fi

# Start FRP server
echo "Starting FRP server..."
nohup ./frps -c frps.toml > /tmp/frps.log 2>&1 &
FRP_SERVER_PID=$!
sleep 2

# Start FRP client
echo "Starting FRP client..."
nohup ./frpc -c frpc_server.toml > /tmp/frpc_server.log 2>&1 &
FRP_CLIENT_PID=$!
sleep 2

# Check if processes are running
if ps -p $FRP_SERVER_PID > /dev/null && ps -p $FRP_CLIENT_PID > /dev/null; then
    echo
    echo "=== Server Setup Complete ==="
    echo "FRP Server PID: $FRP_SERVER_PID"
    echo "FRP Client PID: $FRP_CLIENT_PID"
    echo
    echo "Tunnel is ready for client connections on port ${FRP_PORT}"
    echo
    echo "To stop the tunnel:"
    echo "  kill $FRP_SERVER_PID $FRP_CLIENT_PID"
    echo
    echo "To check logs:"
    echo "  tail -f /tmp/frps.log"
    echo "  tail -f /tmp/frpc_server.log"
else
    echo "Error: Failed to start FRP services"
    echo "Check logs at /tmp/frps.log and /tmp/frpc_server.log"
    exit 1
fi