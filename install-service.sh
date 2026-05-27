#!/bin/bash
# install-service.sh
# One-click installer for the XDC CGNAT Peer Monitor systemd service
# Run this script with: sudo ./install-service.sh

set -e  # Exit on any error

echo "🚀 Installing XDC CGNAT Peer Monitor as a systemd service..."

# Check if running as root (or with sudo)
if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run with sudo."
  echo "   Please run: sudo ./install-service.sh"
  exit 1
fi

# Get the current user who owns the scripts (not root)
CURRENT_USER="${SUDO_USER:-$USER}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="/etc/systemd/system/xdc-cgnat-monitor.service"

echo "📁 Working directory : $SCRIPT_DIR"
echo "👤 Running as user    : $CURRENT_USER"
echo "📄 Service file will be: $SERVICE_FILE"

# Stop and disable old service if it exists
if systemctl list-unit-files | grep -q xdc-cgnat-monitor.service; then
  echo "🔄 Old service found. Stopping and disabling..."
  systemctl stop xdc-cgnat-monitor.service 2>/dev/null || true
  systemctl disable xdc-cgnat-monitor.service 2>/dev/null || true
fi

# Create the systemd service file
echo "📝 Creating systemd service file..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=XDC CGNAT Peer Monitor
After=network.target docker.service

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/xdc-behind-cgnat.sh
Restart=always
RestartSec=10
StandardOutput=append:$HOME/xdc-cgnat-monitor.log
StandardError=append:$HOME/xdc-cgnat-monitor.log

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable/start the service
echo "🔄 Reloading systemd daemon..."
systemctl daemon-reload

echo "✅ Enabling service..."
systemctl enable xdc-cgnat-monitor.service

echo "🚀 Starting service..."
systemctl start xdc-cgnat-monitor.service

echo ""
echo "🎉 Installation complete!"
echo ""
echo "Service status:"
systemctl status xdc-cgnat-monitor.service --no-pager -l
echo ""
echo "Useful commands:"
echo "   sudo systemctl status xdc-cgnat-monitor.service"
echo "   sudo systemctl restart xdc-cgnat-monitor.service"
echo "   sudo systemctl stop xdc-cgnat-monitor.service"
echo ""
echo "✅ Your XDC CGNAT Peer Monitor will now start automatically on boot!"

exit 0
