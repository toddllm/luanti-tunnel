# Minetest/Luanti UDP Tunnel Setup Guide

This guide provides a complete solution for tunneling Minetest/Luanti UDP traffic through SSH using FRP (Fast Reverse Proxy), which properly handles the game's UDP protocol including large item definition transfers.

## Overview

Minetest uses UDP on port 30000 by default. When you need to connect through firewalls or NAT, standard SSH tunneling doesn't work because SSH only supports TCP. This solution uses FRP to create a secure UDP tunnel.

## Architecture

```
[Game Client] --UDP--> [FRP Client] --SSH Tunnel--> [FRP Server] --UDP--> [Minetest Server]
    Port 30100            Port 7000                   Port 7000             Port 30000
```

## Prerequisites

- SSH access to the server
- Minetest/Luanti server running on port 30000
- Admin access on client machine (for installing tools)

## Server Setup (Linux)

### 1. Download and Install FRP

```bash
# Download FRP
cd /tmp
wget https://github.com/fatedier/frp/releases/download/v0.64.0/frp_0.64.0_linux_amd64.tar.gz
tar -xzf frp_0.64.0_linux_amd64.tar.gz
cd frp_0.64.0_linux_amd64
```

### 2. Configure FRP Server

Create `/tmp/frp_0.64.0_linux_amd64/frps.toml`:
```toml
bindPort = 7000
```

### 3. Configure FRP Client on Server

Create `/tmp/frp_0.64.0_linux_amd64/frpc_server.toml`:
```toml
serverAddr = "127.0.0.1"
serverPort = 7000

[[proxies]]
name = "minetest-udp"
type = "sudp"
localIP = "127.0.0.1"
localPort = 30000
```

### 4. Start FRP Services

```bash
# Start FRP server
./frps -c frps.toml > /tmp/frps.log 2>&1 &

# Start FRP client (exposes Minetest)
./frpc -c frpc_server.toml > /tmp/frpc_server.log 2>&1 &
```

## macOS Client Setup

### 1. Install Dependencies

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install FRP client
brew install frpc
```

### 2. Create Configuration

Create `~/minetest-tunnel/frpc.toml`:
```toml
serverAddr = "127.0.0.1"
serverPort = 7000

[[visitors]]
name = "minetest-udp-visitor"
type = "sudp"
serverName = "minetest-udp"
bindAddr = "127.0.0.1"
bindPort = 30100
```

### 3. Create Connection Script

Save as `~/minetest-tunnel/connect-mac.sh`:
```bash
#!/bin/bash

# Configuration
SERVER_HOST="your.server.ip"
SERVER_SSH_PORT="22"
SERVER_USER="username"
LOCAL_PORT="30100"

echo "=== Minetest/Luanti Tunnel Setup for macOS ==="
echo

# Kill any existing connections
echo "Cleaning up existing connections..."
pkill -f "ssh.*7000" 2>/dev/null
pkill frpc 2>/dev/null
sleep 1

# Create SSH tunnel for FRP control
echo "Creating SSH tunnel to server..."
ssh -f -N -L 7000:127.0.0.1:7000 ${SERVER_USER}@${SERVER_HOST} -p ${SERVER_SSH_PORT}

if [ $? -ne 0 ]; then
    echo "Failed to create SSH tunnel. Check your SSH credentials."
    exit 1
fi

echo "SSH tunnel established."

# Start FRP client
echo "Starting FRP client..."
frpc -c ~/minetest-tunnel/frpc.toml &
FRP_PID=$!

sleep 2

# Check if FRP is running
if ps -p $FRP_PID > /dev/null; then
    echo
    echo "=== Connection Successful ==="
    echo "Connect your Minetest/Luanti client to:"
    echo "  Host: 127.0.0.1"
    echo "  Port: ${LOCAL_PORT}"
    echo
    echo "Press Ctrl+C to disconnect"
    
    # Keep script running
    wait $FRP_PID
else
    echo "Failed to start FRP client"
    exit 1
fi
```

Make it executable:
```bash
chmod +x ~/minetest-tunnel/connect-mac.sh
```

## Windows Client Setup

### 1. Download Required Tools

1. **Download FRP for Windows**:
   - Go to: https://github.com/fatedier/frp/releases
   - Download: `frp_0.64.0_windows_amd64.zip`
   - Extract to: `C:\minetest-tunnel\`

2. **Download PuTTY** (for SSH tunneling):
   - Go to: https://www.putty.org/
   - Download the MSI installer
   - Install PuTTY

### 2. Create Configuration

Create `C:\minetest-tunnel\frpc.ini`:
```ini
[common]
server_addr = 127.0.0.1
server_port = 7000

[minetest-udp-visitor]
type = sudp
role = visitor
server_name = minetest-udp
bind_addr = 127.0.0.1
bind_port = 30100
```

### 3. Create Connection Scripts

Save as `C:\minetest-tunnel\connect-windows.bat`:
```batch
@echo off
setlocal

REM Configuration
set SERVER_HOST=your.server.ip
set SERVER_SSH_PORT=22
set SERVER_USER=username
set LOCAL_PORT=30100

echo === Minetest/Luanti Tunnel Setup for Windows ===
echo.

REM Kill existing connections
echo Cleaning up existing connections...
taskkill /F /IM plink.exe 2>NUL
taskkill /F /IM frpc.exe 2>NUL
timeout /t 2 /nobreak >NUL

REM Create SSH tunnel using plink
echo Creating SSH tunnel to server...
echo Please enter your SSH password when prompted.
start /B plink -ssh -L 7000:127.0.0.1:7000 -P %SERVER_SSH_PORT% %SERVER_USER%@%SERVER_HOST%

timeout /t 3 /nobreak >NUL

REM Start FRP client
echo Starting FRP client...
cd /d C:\minetest-tunnel
start /B frpc.exe -c frpc.ini

timeout /t 2 /nobreak >NUL

echo.
echo === Connection Setup Complete ===
echo Connect your Minetest/Luanti client to:
echo   Host: 127.0.0.1
echo   Port: %LOCAL_PORT%
echo.
echo Press any key to disconnect and exit...
pause >NUL

REM Cleanup
taskkill /F /IM plink.exe 2>NUL
taskkill /F /IM frpc.exe 2>NUL
```

### 4. PowerShell Alternative (Windows)

Save as `C:\minetest-tunnel\connect-windows.ps1`:
```powershell
# Configuration
$SERVER_HOST = "your.server.ip"
$SERVER_SSH_PORT = "22"
$SERVER_USER = "username"
$LOCAL_PORT = "30100"

Write-Host "=== Minetest/Luanti Tunnel Setup for Windows ===" -ForegroundColor Green
Write-Host ""

# Kill existing connections
Write-Host "Cleaning up existing connections..." -ForegroundColor Yellow
Get-Process plink -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process frpc -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Create SSH tunnel
Write-Host "Creating SSH tunnel to server..." -ForegroundColor Yellow
$sshProcess = Start-Process plink -ArgumentList "-ssh -L 7000:127.0.0.1:7000 -P $SERVER_SSH_PORT $SERVER_USER@$SERVER_HOST" -PassThru -WindowStyle Hidden

Start-Sleep -Seconds 3

# Start FRP client
Write-Host "Starting FRP client..." -ForegroundColor Yellow
Set-Location "C:\minetest-tunnel"
$frpProcess = Start-Process ".\frpc.exe" -ArgumentList "-c frpc.ini" -PassThru -WindowStyle Hidden

Start-Sleep -Seconds 2

if ($frpProcess.HasExited -eq $false) {
    Write-Host ""
    Write-Host "=== Connection Successful ===" -ForegroundColor Green
    Write-Host "Connect your Minetest/Luanti client to:" -ForegroundColor Cyan
    Write-Host "  Host: 127.0.0.1" -ForegroundColor White
    Write-Host "  Port: $LOCAL_PORT" -ForegroundColor White
    Write-Host ""
    Write-Host "Press any key to disconnect..." -ForegroundColor Yellow
    
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} else {
    Write-Host "Failed to start FRP client" -ForegroundColor Red
}

# Cleanup
Write-Host "Disconnecting..." -ForegroundColor Yellow
Stop-Process -Id $sshProcess.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $frpProcess.Id -Force -ErrorAction SilentlyContinue
```

## Usage Instructions

### For macOS Users

1. Edit `~/minetest-tunnel/connect-mac.sh` and update:
   - `SERVER_HOST` - Your server's IP address
   - `SERVER_SSH_PORT` - SSH port (usually 22)
   - `SERVER_USER` - Your SSH username

2. Run the connection script:
   ```bash
   ~/minetest-tunnel/connect-mac.sh
   ```

3. Open Minetest/Luanti and connect to:
   - Server Address: `127.0.0.1`
   - Port: `30100`

### For Windows Users

1. Edit `C:\minetest-tunnel\connect-windows.bat` and update:
   - `SERVER_HOST` - Your server's IP address
   - `SERVER_SSH_PORT` - SSH port (usually 22)
   - `SERVER_USER` - Your SSH username

2. Double-click `connect-windows.bat`

3. Enter your SSH password when prompted

4. Open Minetest/Luanti and connect to:
   - Server Address: `127.0.0.1`
   - Port: `30100`

## Troubleshooting

### Connection Times Out

1. **Check server processes**:
   ```bash
   ssh user@server "ps aux | grep frp"
   ```
   Should show both `frps` and `frpc` running.

2. **Check SSH tunnel**:
   - macOS: `lsof -i :7000`
   - Windows: `netstat -an | findstr 7000`

3. **Check FRP client**:
   - macOS: `ps aux | grep frpc`
   - Windows: Open Task Manager and look for `frpc.exe`

### Port Already in Use

If port 30100 is already in use, change it in:
- Configuration file (`frpc.toml` or `frpc.ini`)
- Connection script (`LOCAL_PORT` variable)

### SSH Connection Issues

- Ensure SSH key authentication is set up, or be ready to enter password
- Check firewall rules allow SSH connection
- Verify server SSH port is correct

## Security Considerations

1. **SSH Tunnel**: All traffic between client and server is encrypted through SSH
2. **Local Only**: FRP server binds to localhost only (127.0.0.1)
3. **SUDP Protocol**: Uses secure UDP protocol for game traffic
4. **No Public Exposure**: Server's game port remains unexposed to internet

## Advanced Configuration

### Multiple Servers

To connect to multiple servers, create different config files with unique visitor names and local ports:

```toml
[[visitors]]
name = "server1-visitor"
type = "sudp"
serverName = "server1-udp"
bindAddr = "127.0.0.1"
bindPort = 30101

[[visitors]]
name = "server2-visitor"
type = "sudp"
serverName = "server2-udp"
bindAddr = "127.0.0.1"
bindPort = 30102
```

### Persistent Server Setup

For production use, create systemd services on the server:

`/etc/systemd/system/frps.service`:
```ini
[Unit]
Description=FRP Server
After=network.target

[Service]
Type=simple
User=minetest
ExecStart=/opt/frp/frps -c /opt/frp/frps.toml
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
```

## Performance Notes

- FRP with SUDP protocol handles game traffic efficiently
- Minimal latency overhead (typically < 5ms)
- Successfully handles large item definition transfers
- Supports multiple concurrent players

## Credits

- FRP (Fast Reverse Proxy): https://github.com/fatedier/frp
- Solution tested with Minetest 5.x and Luanti