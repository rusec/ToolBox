#!/bin/bash

# Directory to move the binaries to
DEST_DIR="/tmp/safe"

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# List of GTFOBins (Note: This is a partial list for demonstration; the full list should be checked on the GTFOBins website)
GTFOBINS=(
    "dd"
    "rm"
    "ash"
    "busybox"
    "csh"
    "dash"
    "ed"
    "env"
    "expect"
    "find"
    "ftp"
    "gdb"
    "ld.so"
    "lua"
    "mail"
    "perl"
    "rlwrap"
    "rpm"
    "rsync"
    "ruby"
    "scp"
    "sh"
    "ssh"
    "tclsh"
    "telnet"
    "vim"
    "socket"
    "view"
    "rview"
    "rvim"
    "perl"
    "julia"
    "jrunscript"
    "jjs"
    "gimp"
    "easy_install"
    "nc"
    "cpan"
)

# Function to move a GTFOBin to the destination directory and make it non-executable
move_bin() {
    bin=$1
    if command_exists "$bin"; then
        mv "$(command -v "$bin")" "$DEST_DIR"
        chmod -x "$DEST_DIR/$bin"
        echo "Moved $bin to $DEST_DIR and made it non-executable"
    else
        echo "$bin not found on this system."
    fi
}

# Function to restore a GTFOBin to its original location and make it executable
restore_bin() {
    bin=$1
    if [ -f "$DEST_DIR/$bin" ]; then
        mv "$DEST_DIR/$bin" "/usr/bin/$bin"
        chmod +x "/usr/bin/$bin"
        echo "Moved $bin back to /usr/bin and restored executable permissions"
    else
        echo "$bin not found in $DEST_DIR"
    fi
}
# Create the destination directory if it does not exist
if [ ! -d "$DEST_DIR" ]; then
    mkdir -p "$DEST_DIR"
fi


# Prompt the user for action
echo "Choose an action:"
echo "1. Move GTFOBins to a different location and make them non-executable"
echo "2. Restore GTFOBins to their original locations and make them executable"
read -p -r "Enter your choice (1 or 2): " choice

if [[ $choice -eq 1 ]]; then
    echo "Enter the name of the binary to move (or 'all' to move all GTFOBins):"
    read -p -r "Binary name: " bin_name
    if [[ $bin_name == "all" ]]; then
        for bin in "${GTFOBINS[@]}"; do
            move_bin "$bin"
        done
    else
        move_bin "$bin_name"
    fi
fi

if [[ $choice -eq 2 ]]; then
    echo "Enter the name of the binary to restore (or 'all' to restore all GTFOBins):"
    read -p -r "Binary name: " bin_name
    if [[ $bin_name == "all" ]]; then
        for bin in "${GTFOBINS[@]}"; do
            restore_bin "$bin"
        done
    else
        restore_bin "$bin_name"
    fi
else
    echo "Invalid choice. Please run the script again and choose 1 or 2."
fi
