#!/bin/bash
# Kanata Auto-Start Setup Script

set -euo pipefail

echo "🔧 Setting up Kanata auto-start service..."
echo ""

# Ensure Karabiner virtual HID device daemon is running (required for kanata output)
echo "0. Setting up Karabiner virtual HID device daemon (prerequisite)..."
KARABINER_DAEMONS="/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Elements Privileged Daemons v2.app/Contents/MacOS/Karabiner-Elements Privileged Daemons v2"
if [ ! -f "$KARABINER_DAEMONS" ]; then
    echo "   ⚠️  Karabiner-Elements not found — install it first: brew install --cask karabiner-elements"
    echo "      Kanata requires Karabiner-DriverKit-VirtualHIDDevice for key output."
    exit 1
fi
if pgrep -x karabiner_grabber > /dev/null 2>&1; then
    echo "   ✓ Karabiner daemon already running"
else
    echo "   Starting Karabiner privileged daemons..."
    sudo "$KARABINER_DAEMONS"
    echo "   ✓ Karabiner daemon started"
fi
echo ""

# Stop any running kanata instances
echo "1. Stopping any running kanata instances..."
sudo pkill kanata 2>/dev/null || echo "   No running instances found"
echo ""

# Unload existing service if it exists
echo "2. Unloading existing service (if any)..."
sudo launchctl bootout system/xbxd.kanata 2>/dev/null || echo "   No existing service found"
echo ""

# Remove old symlink if it exists
echo "3. Cleaning up old symlinks..."
sudo rm -f /Library/LaunchDaemons/xbxd.kanata.plist
echo ""

# Create log directory
echo "4. Creating log directory..."
sudo mkdir -p /Library/Logs/Kanata
echo "   ✓ Created /Library/Logs/Kanata"
echo ""

# Create symlink
echo "5. Creating symlink to LaunchDaemons..."
sudo ln -sf "$HOME/.config/kanata/xbxd.kanata.plist" /Library/LaunchDaemons/xbxd.kanata.plist
echo "   ✓ Symlinked plist file"
echo ""

# Set proper ownership
echo "6. Setting proper ownership..."
sudo chown root:wheel /Library/LaunchDaemons/xbxd.kanata.plist
echo "   ✓ Ownership set to root:wheel"
echo ""

# Bootstrap the service (modern way)
echo "7. Loading service with launchctl bootstrap..."
sudo launchctl bootstrap system /Library/LaunchDaemons/xbxd.kanata.plist
echo "   ✓ Service loaded"
echo ""

# Enable the service
echo "8. Enabling service..."
sudo launchctl enable system/xbxd.kanata
echo "   ✓ Service enabled"
echo ""

# Start the service
echo "9. Starting service..."
sudo launchctl kickstart -k system/xbxd.kanata
echo "   ✓ Service started"
echo ""

# Verify it's running
echo "10. Verifying service status..."
if sudo launchctl list | grep -q xbxd.kanata; then
    echo "   ✓ Service is running!"
    echo ""
    sudo launchctl list | grep xbxd.kanata
else
    echo "   ⚠️  Service not found in list"
    echo "   Check logs: sudo tail -f /Library/Logs/Kanata/kanata.err.log"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Grant Input Monitoring permission in System Settings"
echo "      Settings > Privacy & Security > Input Monitoring"
echo "      Add: /opt/homebrew/bin/kanata"
echo ""
echo "   2. Test your homerow mods and function keys"
echo ""
echo "   3. Check logs if something doesn't work:"
echo "      sudo tail -f /Library/Logs/Kanata/kanata.err.log"
echo ""
