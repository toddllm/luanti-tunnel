@echo off
setlocal enabledelayedexpansion

REM Minetest/Luanti Windows Client Connection Script
REM Edit the configuration section below with your server details

REM === CONFIGURATION - EDIT THESE ===
set SERVER_HOST=24.29.85.43
set SERVER_SSH_PORT=12069
set SERVER_USER=tdeshane
set LOCAL_PORT=30100
set FRP_PATH=C:\minetest-tunnel
REM ==================================

echo ========================================
echo   Minetest/Luanti Tunnel Setup for Windows
echo ========================================
echo.

REM Check if FRP exists
if not exist "%FRP_PATH%\frpc.exe" (
    echo ERROR: frpc.exe not found at %FRP_PATH%
    echo Please download FRP from: https://github.com/fatedier/frp/releases
    echo Extract to: %FRP_PATH%
    pause
    exit /b 1
)

REM Check if plink exists
where plink >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: plink.exe not found
    echo Please install PuTTY from: https://www.putty.org/
    pause
    exit /b 1
)

REM Kill existing connections
echo Cleaning up existing connections...
taskkill /F /IM plink.exe >nul 2>&1
taskkill /F /IM frpc.exe >nul 2>&1
timeout /t 2 /nobreak >nul

REM Create FRP configuration
echo Creating FRP configuration...
if not exist "%FRP_PATH%" mkdir "%FRP_PATH%"

(
echo [common]
echo server_addr = 127.0.0.1
echo server_port = 7000
echo.
echo [minetest-udp-visitor]
echo type = sudp
echo role = visitor
echo server_name = minetest-udp
echo bind_addr = 127.0.0.1
echo bind_port = %LOCAL_PORT%
) > "%FRP_PATH%\frpc.ini"

REM Create SSH tunnel using plink
echo.
echo Creating SSH tunnel to %SERVER_HOST%...
echo.
echo IMPORTANT: Enter your SSH password when prompted
echo.
start "SSH Tunnel" /MIN cmd /c "plink -ssh -L 7000:127.0.0.1:7000 -P %SERVER_SSH_PORT% %SERVER_USER%@%SERVER_HOST%"

echo Waiting for SSH connection...
timeout /t 5 /nobreak >nul

REM Check if port 7000 is listening
netstat -an | find "7000" | find "LISTENING" >nul
if %errorlevel% neq 0 (
    echo.
    echo ERROR: SSH tunnel failed to establish
    echo Please check your credentials and try again
    taskkill /F /IM plink.exe >nul 2>&1
    pause
    exit /b 1
)

REM Start FRP client
echo Starting FRP client...
cd /d "%FRP_PATH%"
start "FRP Client" /MIN frpc.exe -c frpc.ini

timeout /t 3 /nobreak >nul

REM Check if FRP is running
tasklist | find "frpc.exe" >nul
if %errorlevel% equ 0 (
    cls
    echo ========================================
    echo        CONNECTION ESTABLISHED!
    echo ========================================
    echo.
    echo Connect your Minetest/Luanti client to:
    echo   Server Address: 127.0.0.1
    echo   Port: %LOCAL_PORT%
    echo.
    echo ========================================
    echo.
    echo Press any key to disconnect and exit...
    pause >nul
) else (
    echo.
    echo ERROR: Failed to start FRP client
    pause
)

REM Cleanup
echo.
echo Disconnecting...
taskkill /F /IM plink.exe >nul 2>&1
taskkill /F /IM frpc.exe >nul 2>&1
echo Disconnected successfully
timeout /t 2 /nobreak >nul