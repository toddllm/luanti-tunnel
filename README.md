# Minetest/Luanti UDP Tunnel Solution

This repository contains a complete solution for tunneling Minetest/Luanti UDP traffic through SSH using FRP (Fast Reverse Proxy).

## Quick Start

### Server Setup (One-time)
```bash
# Copy setup-server.sh to your server and run:
./setup-server.sh
```

### macOS Client
```bash
# Edit connect-mac.sh with your server details
./connect-mac.sh
# Connect game to 127.0.0.1:30100
```

### Windows Client
1. Download FRP: https://github.com/fatedier/frp/releases
2. Extract to `C:\minetest-tunnel\`
3. Install PuTTY: https://www.putty.org/
4. Edit and run `connect-windows.bat` or `connect-windows.ps1`
5. Connect game to 127.0.0.1:30100

## Files

- `minetest-tunnel-setup.md` - Complete documentation
- `setup-server.sh` - Server setup script (Linux)
- `connect-mac.sh` - macOS client connection script
- `connect-windows.bat` - Windows batch script
- `connect-windows.ps1` - Windows PowerShell script

## Why This Solution?

- **Works with UDP**: Minetest uses UDP which SSH doesn't natively support
- **Handles large transfers**: Successfully handles item definition transfers
- **Secure**: All traffic encrypted through SSH tunnel
- **Cross-platform**: Works on macOS, Windows, and Linux
- **No port forwarding**: No need to expose game ports to internet

## Architecture

```
[Game] <--UDP--> [FRP Client] <--SSH--> [FRP Server] <--UDP--> [Minetest]
Port 30100        Port 7000              Port 7000             Port 30000
```

## Troubleshooting

1. **Connection timeout**: Check server setup completed successfully
2. **Port in use**: Change LOCAL_PORT in scripts
3. **SSH fails**: Verify credentials and port number
4. **FRP fails**: Check both frps and frpc are running on server

## Support

For detailed documentation, see `minetest-tunnel-setup.md`