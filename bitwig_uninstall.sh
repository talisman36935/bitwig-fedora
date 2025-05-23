#!/bin/bash

# Script to uninstall manually installed Bitwig Studio
# Usage: sudo ./uninstall-bitwig.sh

# Check if script is run with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "This script needs to be run with sudo privileges."
    echo "Usage: sudo $0"
    exit 1
fi

echo "Bitwig Studio Manual Uninstaller"
echo "================================"
echo "This script will remove Bitwig Studio that was installed manually to /opt/bitwig-studio."
echo "It will NOT remove your personal settings or projects in your home directory."
echo

# Ask for confirmation
read -p "Are you sure you want to uninstall Bitwig Studio? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Bitwig is installed in /opt
if [ ! -d "/opt/bitwig-studio" ]; then
    echo "Warning: Bitwig Studio installation not found in /opt/bitwig-studio."
    read -p "Do you want to continue anyway? (y/n): " continue_anyway
    if [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi
fi

# Remove the main application directory
echo "Removing Bitwig Studio application files..."
rm -rf /opt/bitwig-studio
echo "✓ Removed /opt/bitwig-studio"

# Remove the executable symlink
if [ -L "/usr/local/bin/bitwig-studio" ]; then
    rm /usr/local/bin/bitwig-studio
    echo "✓ Removed /usr/local/bin/bitwig-studio symlink"
else
    echo "Note: No symlink found at /usr/local/bin/bitwig-studio"
fi

# Remove desktop files
echo "Removing desktop integration files..."
if [ -f "/usr/local/share/applications/com.bitwig.BitwigStudio.desktop" ]; then
    rm /usr/local/share/applications/com.bitwig.BitwigStudio.desktop
    echo "✓ Removed desktop file"
else
    # Try to find any Bitwig desktop files
    bitwig_desktop_files=$(find /usr/local/share/applications -name "*bitwig*.desktop" 2>/dev/null)
    if [ -n "$bitwig_desktop_files" ]; then
        rm $bitwig_desktop_files
        echo "✓ Removed desktop files: $bitwig_desktop_files"
    else
        echo "Note: No Bitwig desktop files found in /usr/local/share/applications"
    fi
fi

# Remove icons
echo "Removing icon files..."
bitwig_icons=$(find /usr/local/share/icons -name "*com.bitwig.BitwigStudio*" 2>/dev/null)
if [ -n "$bitwig_icons" ]; then
    rm -f $bitwig_icons
    echo "✓ Removed icon files"
else
    echo "Note: No Bitwig icon files found in /usr/local/share/icons"
fi

# Remove MIME type information
echo "Removing MIME type information..."
if [ -f "/usr/local/share/mime/packages/com.bitwig.BitwigStudio.xml" ]; then
    rm /usr/local/share/mime/packages/com.bitwig.BitwigStudio.xml
    echo "✓ Removed MIME type file"
else
    echo "Note: No Bitwig MIME type file found"
fi

# Remove metainfo
echo "Removing application metadata..."
if [ -f "/usr/local/share/metainfo/com.bitwig.BitwigStudio.appdata.xml" ]; then
    rm /usr/local/share/metainfo/com.bitwig.BitwigStudio.appdata.xml
    echo "✓ Removed application metadata file"
else
    echo "Note: No Bitwig metadata file found"
fi

# Update MIME and desktop databases
echo "Updating system databases..."
if command_exists update-mime-database; then
    update-mime-database /usr/local/share/mime
    echo "✓ Updated MIME database"
else
    echo "Note: update-mime-database command not found, skipping MIME database update"
fi

if command_exists update-desktop-database; then
    update-desktop-database /usr/local/share/applications
    echo "✓ Updated desktop database"
else
    echo "Note: update-desktop-database command not found, skipping desktop database update"
fi

echo
echo "Bitwig Studio has been uninstalled from your system."
echo
echo "Note: Your personal settings and projects in ~/.BitwigStudio and ~/Documents/Bitwig Studio"
echo "have NOT been removed. If you want to remove these as well, you can do so manually with:"
echo
echo "  rm -rf ~/.BitwigStudio"
echo "  rm -rf ~/Documents/Bitwig\ Studio"
echo
echo "Uninstallation complete!"