#!/bin/bash

# Minetest/Luanti macOS Client Connection Script
# Edit the configuration section below with your server details

# === CONFIGURATION - EDIT THESE ===
SERVER_HOST="24.29.85.43"        # Your server's IP or hostname
SERVER_SSH_PORT="12069"          # SSH port (usually 22)
SERVER_USER="tdeshane"           # Your SSH username
LOCAL_PORT="30100"               # Local port for game connection
# ==================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Minetest/Luanti Tunnel Setup for macOS ===${NC}"
echo

# Check if frpc is installed
if ! command -v frpc &> /dev/null; then
    echo -e "${RED}Error: frpc not found${NC}"
    echo "Please install it with: brew install frpc"
    exit 1
fi

# Kill any existing connections
echo -e "${YELLOW}Cleaning up existing connections...${NC}"
pkill -f "ssh.*7000" 2>/dev/null
pkill frpc 2>/dev/null
sleep 1

# Create config directory if it doesn't exist
mkdir -p ~/minetest-tunnel

# Create FRP client configuration
echo -e "${YELLOW}Creating FRP configuration...${NC}"
cat > ~/minetest-tunnel/frpc.toml << EOF
serverAddr = "127.0.0.1"
serverPort = 7000

[[visitors]]
name = "minetest-udp-visitor"
type = "sudp"
serverName = "minetest-udp"
bindAddr = "127.0.0.1"
bindPort = ${LOCAL_PORT}
EOF

# Create SSH tunnel for FRP control
echo -e "${YELLOW}Creating SSH tunnel to ${SERVER_HOST}...${NC}"
ssh -f -N -L 7000:127.0.0.1:7000 ${SERVER_USER}@${SERVER_HOST} -p ${SERVER_SSH_PORT}

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create SSH tunnel. Check your SSH credentials.${NC}"
    exit 1
fi

echo -e "${GREEN}SSH tunnel established.${NC}"

# Start FRP client
echo -e "${YELLOW}Starting FRP client...${NC}"
frpc -c ~/minetest-tunnel/frpc.toml 2>&1 | tee ~/minetest-tunnel/frpc.log &
FRP_PID=$!

sleep 3

# Check if FRP is running and connected
if ps -p $FRP_PID > /dev/null; then
    if grep -q "sudp start to work" ~/minetest-tunnel/frpc.log 2>/dev/null; then
        echo
        echo -e "${GREEN}=== Connection Successful ===${NC}"
        echo -e "${CYAN}Connect your Minetest/Luanti client to:${NC}"
        echo -e "  Host: ${GREEN}127.0.0.1${NC}"
        echo -e "  Port: ${GREEN}${LOCAL_PORT}${NC}"
        echo
        echo -e "${YELLOW}Press Ctrl+C to disconnect${NC}"
        
        # Trap Ctrl+C to cleanup
        trap cleanup INT
        
        function cleanup() {
            echo
            echo -e "${YELLOW}Disconnecting...${NC}"
            kill $FRP_PID 2>/dev/null
            pkill -f "ssh.*7000" 2>/dev/null
            echo -e "${GREEN}Disconnected successfully${NC}"
            exit 0
        }
        
        # Keep script running
        wait $FRP_PID
    else
        echo -e "${RED}FRP client started but failed to establish visitor${NC}"
        echo "Check ~/minetest-tunnel/frpc.log for details"
        kill $FRP_PID 2>/dev/null
        pkill -f "ssh.*7000" 2>/dev/null
        exit 1
    fi
else
    echo -e "${RED}Failed to start FRP client${NC}"
    pkill -f "ssh.*7000" 2>/dev/null
    exit 1
fi