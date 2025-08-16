# Minetest/Luanti Windows PowerShell Connection Script
# Edit the configuration section below with your server details

# === CONFIGURATION - EDIT THESE ===
$SERVER_HOST = "24.29.85.43"
$SERVER_SSH_PORT = "12069"
$SERVER_USER = "tdeshane"
$LOCAL_PORT = "30100"
$FRP_PATH = "C:\minetest-tunnel"
# ==================================

# Set console colors
$Host.UI.RawUI.WindowTitle = "Minetest/Luanti Tunnel"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Minetest/Luanti Tunnel Setup for Windows" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator (not required but good to know)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isAdmin) {
    Write-Host "Running with Administrator privileges" -ForegroundColor Green
}

# Check if FRP exists
if (-not (Test-Path "$FRP_PATH\frpc.exe")) {
    Write-Host "ERROR: frpc.exe not found at $FRP_PATH" -ForegroundColor Red
    Write-Host "Please download FRP from: https://github.com/fatedier/frp/releases" -ForegroundColor Yellow
    Write-Host "Extract to: $FRP_PATH" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if plink exists
$plinkPath = Get-Command plink -ErrorAction SilentlyContinue
if (-not $plinkPath) {
    Write-Host "ERROR: plink.exe not found" -ForegroundColor Red
    Write-Host "Please install PuTTY from: https://www.putty.org/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Kill existing connections
Write-Host "Cleaning up existing connections..." -ForegroundColor Yellow
Get-Process plink -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process frpc -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Create FRP configuration
Write-Host "Creating FRP configuration..." -ForegroundColor Yellow
if (-not (Test-Path $FRP_PATH)) {
    New-Item -ItemType Directory -Path $FRP_PATH -Force | Out-Null
}

$frpConfig = @"
[common]
server_addr = 127.0.0.1
server_port = 7000

[minetest-udp-visitor]
type = sudp
role = visitor
server_name = minetest-udp
bind_addr = 127.0.0.1
bind_port = $LOCAL_PORT
"@

Set-Content -Path "$FRP_PATH\frpc.ini" -Value $frpConfig

# Create SSH tunnel
Write-Host ""
Write-Host "Creating SSH tunnel to ${SERVER_HOST}..." -ForegroundColor Yellow
Write-Host ""
Write-Host "IMPORTANT: Enter your SSH password in the new window" -ForegroundColor Cyan
Write-Host ""

$sshArgs = "-ssh -L 7000:127.0.0.1:7000 -P $SERVER_SSH_PORT $SERVER_USER@$SERVER_HOST"
$sshProcess = Start-Process plink -ArgumentList $sshArgs -PassThru

Write-Host "Waiting for SSH connection..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Check if SSH tunnel is established
$tcpConnection = Get-NetTCPConnection -LocalPort 7000 -State Listen -ErrorAction SilentlyContinue
if (-not $tcpConnection) {
    Write-Host ""
    Write-Host "ERROR: SSH tunnel failed to establish" -ForegroundColor Red
    Write-Host "Please check your credentials and try again" -ForegroundColor Yellow
    Stop-Process -Id $sshProcess.Id -Force -ErrorAction SilentlyContinue
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "SSH tunnel established successfully" -ForegroundColor Green

# Start FRP client
Write-Host "Starting FRP client..." -ForegroundColor Yellow
Set-Location $FRP_PATH
$frpProcess = Start-Process ".\frpc.exe" -ArgumentList "-c frpc.ini" -PassThru -WindowStyle Hidden

Start-Sleep -Seconds 3

# Check if FRP is running
if ($frpProcess.HasExited -eq $false) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "       CONNECTION ESTABLISHED!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Connect your Minetest/Luanti client to:" -ForegroundColor Cyan
    Write-Host "  Server Address: " -NoNewline -ForegroundColor White
    Write-Host "127.0.0.1" -ForegroundColor Green
    Write-Host "  Port: " -NoNewline -ForegroundColor White
    Write-Host "$LOCAL_PORT" -ForegroundColor Green
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Press any key to disconnect..." -ForegroundColor Yellow
    
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} else {
    Write-Host ""
    Write-Host "ERROR: Failed to start FRP client" -ForegroundColor Red
    Write-Host "Check the log file at: $FRP_PATH\frpc.log" -ForegroundColor Yellow
}

# Cleanup
Write-Host ""
Write-Host "Disconnecting..." -ForegroundColor Yellow
Stop-Process -Id $sshProcess.Id -Force -ErrorAction SilentlyContinue
Stop-Process -Id $frpProcess.Id -Force -ErrorAction SilentlyContinue
Get-Process plink -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process frpc -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Host "Disconnected successfully" -ForegroundColor Green
Start-Sleep -Seconds 2