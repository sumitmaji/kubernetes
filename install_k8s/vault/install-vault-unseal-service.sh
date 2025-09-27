#!/bin/bash
# Installation script for Vault Unseal Systemd Service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_FILE="$SCRIPT_DIR/vault-unseal.service"
STARTUP_SCRIPT="$SCRIPT_DIR/vault-unseal-startup.sh"

echo "Installing Vault Unseal Systemd Service..."

# Make the startup script executable
chmod +x "$STARTUP_SCRIPT"
echo "Made startup script executable: $STARTUP_SCRIPT"

# Copy service file to systemd directory
cp "$SERVICE_FILE" /etc/systemd/system/
echo "Copied service file to /etc/systemd/system/vault-unseal.service"

# Reload systemd daemon
systemctl daemon-reload
echo "Reloaded systemd daemon"

# Enable the service
systemctl enable vault-unseal.service
echo "Enabled vault-unseal.service"

# Show service status
systemctl status vault-unseal.service --no-pager
echo ""
echo "Installation completed!"
echo ""
echo "To manually start the service: systemctl start vault-unseal.service"
echo "To check logs: journalctl -u vault-unseal.service -f"
echo "To check script logs: tail -f /var/log/vault-unseal.log"