#!/bin/bash

# Script to safely install Bitwig Studio without filesystem package conflicts
# Works with both .deb and .rpm files
# Usage: sudo ./install-bitwig.sh [path-to-deb-or-rpm-file]

# Check if script is run with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "This script needs to be run with sudo privileges."
    echo "Usage: sudo $0 [path-to-deb-or-rpm-file]"
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required tools
required_tools=("rpm2cpio" "cpio")

# Check if input is a .deb file, then add alien to required tools
if [ $# -ge 1 ] && [[ "$1" == *.deb ]]; then
    required_tools+=("alien")
fi

for tool in "${required_tools[@]}"; do
    if ! command_exists "$tool"; then
        echo "$tool is required but not installed."
        read -p "Do you want to install $tool now? (y/n): " install_tool
        if [[ "$install_tool" == "y" || "$install_tool" == "Y" ]]; then
            if command_exists dnf; then
                dnf install -y "$tool"
            elif command_exists yum; then
                yum install -y "$tool"
            else
                echo "Error: Could not determine package manager to install $tool."
                echo "Please install $tool manually and try again."
                exit 1
            fi
        else
            echo "$tool is required. Exiting."
            exit 1
        fi
    fi
done

# Get the input file
if [ $# -ge 1 ]; then
    input_file="$1"
    if [ ! -f "$input_file" ]; then
        echo "Error: File '$input_file' not found."
        exit 1
    fi
else
    echo "Please provide the path to the Bitwig Studio .deb or .rpm file."
    echo "Usage: sudo $0 [path-to-deb-or-rpm-file]"
    exit 1
fi

# Get absolute path
input_file=$(readlink -f "$input_file")

# Convert .deb to .rpm if needed
if [[ "$input_file" == *.deb ]]; then
    echo "Converting .deb to .rpm for extraction purposes..."
    input_dir=$(dirname "$input_file")
    input_basename=$(basename "$input_file")
    
    # Change to the directory containing the .deb file
    pushd "$input_dir" > /dev/null
    
    # Convert the .deb to .rpm
    rpm_file=$(alien --to-rpm --scripts "$input_basename" | grep -o "[^ ]*\.rpm")
    
    if [ -z "$rpm_file" ] || [ ! -f "$rpm_file" ]; then
        echo "Error: Failed to convert .deb to .rpm."
        popd > /dev/null
        exit 1
    fi
    
    # Get the absolute path of the created RPM
    rpm_file="$input_dir/$rpm_file"
    
    popd > /dev/null
    
    echo "Successfully converted to: $rpm_file"
else
    rpm_file="$input_file"
fi

# Create a temporary directory
temp_dir=$(mktemp -d)
echo "Working in: $temp_dir"
cd "$temp_dir" || exit 1

# Extract the RPM
echo "Extracting package contents..."
mkdir -p extract
cd extract
rpm2cpio "$rpm_file" | cpio -idmv
cd ..

# Remove any existing Bitwig installation in /opt
if [ -d "/opt/bitwig-studio" ]; then
    echo "Removing existing Bitwig Studio installation from /opt..."
    rm -rf /opt/bitwig-studio
fi

# Create installation directory
echo "Creating installation directory..."
mkdir -p /opt/bitwig-studio

# Copy files from the package to /opt
echo "Installing Bitwig Studio to /opt..."
if [ -d "$temp_dir/extract/opt/bitwig-studio" ]; then
    cp -a "$temp_dir/extract/opt/bitwig-studio/"* /opt/bitwig-studio/
    echo "Copied Bitwig Studio files to /opt/bitwig-studio/"
else
    echo "Warning: Could not find Bitwig Studio files in the expected location."
    echo "Looking for alternative locations..."
    
    # Try to find the main Bitwig executable
    bitwig_dirs=$(find "$temp_dir/extract" -name "bitwig-studio" -type f -executable)
    if [ -n "$bitwig_dirs" ]; then
        for exec_file in $bitwig_dirs; do
            echo "Found Bitwig executable at: $exec_file"
            # Get the parent directory structure
            parent_dir=$(dirname "$exec_file")
            # Find the root directory (usually /opt/bitwig-studio or /usr/share/bitwig-studio)
            while [ "$(basename "$parent_dir")" != "bitwig-studio" ] && [ "$parent_dir" != "/" ]; do
                parent_dir=$(dirname "$parent_dir")
            done
            
            if [ -d "$parent_dir" ]; then
                echo "Copying from $parent_dir to /opt/bitwig-studio/"
                cp -a "$parent_dir/"* /opt/bitwig-studio/
                break
            fi
        done
    else
        echo "Error: Could not find Bitwig Studio executable."
        echo "Manual installation may be required."
        exit 1
    fi
fi

# Create symlink for the executable
echo "Creating symlink for Bitwig Studio executable..."
if [ -f "/opt/bitwig-studio/bitwig-studio" ]; then
    ln -sf /opt/bitwig-studio/bitwig-studio /usr/local/bin/bitwig-studio
    echo "Created symlink: /usr/local/bin/bitwig-studio -> /opt/bitwig-studio/bitwig-studio"
else
    # Try to find the executable
    bitwig_exec=$(find /opt/bitwig-studio -name "bitwig-studio" -type f -executable)
    if [ -n "$bitwig_exec" ]; then
        ln -sf "$bitwig_exec" /usr/local/bin/bitwig-studio
        echo "Created symlink: /usr/local/bin/bitwig-studio -> $bitwig_exec"
    else
        echo "Warning: Could not find Bitwig Studio executable to create symlink."
    fi
fi

# Copy desktop file and icons
echo "Installing desktop integration..."
if [ -d "$temp_dir/extract/usr/share/applications" ]; then
    mkdir -p /usr/local/share/applications
    cp -a "$temp_dir/extract/usr/share/applications/"* /usr/local/share/applications/
    
    # Fix paths in desktop files if needed
    for desktop_file in /usr/local/share/applications/*.desktop; do
        if [ -f "$desktop_file" ]; then
            # Update Exec path to use /usr/local/bin/bitwig-studio
            sed -i 's|Exec=.*bitwig-studio|Exec=/usr/local/bin/bitwig-studio|g' "$desktop_file"
            echo "Updated paths in $desktop_file"
        fi
    done
fi

if [ -d "$temp_dir/extract/usr/share/icons" ]; then
    mkdir -p /usr/local/share/icons
    cp -a "$temp_dir/extract/usr/share/icons/"* /usr/local/share/icons/
fi

if [ -d "$temp_dir/extract/usr/share/mime" ]; then
    mkdir -p /usr/local/share/mime
    cp -a "$temp_dir/extract/usr/share/mime/"* /usr/local/share/mime/
    
    # Update MIME database
    if command_exists update-mime-database; then
        update-mime-database /usr/local/share/mime
    fi
fi

if [ -d "$temp_dir/extract/usr/share/metainfo" ]; then
    mkdir -p /usr/local/share/metainfo
    cp -a "$temp_dir/extract/usr/share/metainfo/"* /usr/local/share/metainfo/
fi

# Update desktop database
if command_exists update-desktop-database; then
    update-desktop-database /usr/local/share/applications
fi

# Clean up
echo "Cleaning up temporary files..."
cd /
rm -rf "$temp_dir"

echo "======================================================"
echo "Bitwig Studio has been installed to /opt/bitwig-studio"
echo "Executable: /usr/local/bin/bitwig-studio"
echo ""
echo "This installation will NOT conflict with the filesystem package"
echo "because it uses /opt for the application and /usr/local for"
echo "integration files, which are standard locations for manually"
echo "installed software."
echo "======================================================"


# Ask if user wants to remove the original files
if [ "$original_input_file" != "$rpm_file" ]; then
    # We have both a .deb and a converted .rpm
    echo
    read -p "Do you want to remove the original .deb file ($original_input_file)? (y/n): " remove_deb
    if [[ "$remove_deb" == "y" || "$remove_deb" == "Y" ]]; then
        rm -f "$original_input_file"
        echo "Removed original .deb file: $original_input_file"
    fi
    
    read -p "Do you want to remove the converted .rpm file ($rpm_file)? (y/n): " remove_rpm
    if [[ "$remove_rpm" == "y" || "$remove_rpm" == "Y" ]]; then
        rm -f "$rpm_file"
        echo "Removed converted .rpm file: $rpm_file"
    fi
else
    # We only have an .rpm file
    echo
    read -p "Do you want to remove the original .rpm file ($rpm_file)? (y/n): " remove_rpm
    if [[ "$remove_rpm" == "y" || "$remove_rpm" == "Y" ]]; then
        rm -f "$rpm_file"
        echo "Removed original .rpm file: $rpm_file"
    fi
fi

echo
echo "Installation complete!"