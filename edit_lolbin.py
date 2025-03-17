#!/usr/bin/env python3
import os
import subprocess
import shutil
import stat

# Directory to move the binaries to
DEST_DIR = "/tmp/safe"

# Function to check if a command exists
def command_exists(cmd):
    return shutil.which(cmd) is not None

# List of GTFOBins (Note: This is a partial list for demonstration)
GTFOBINS = [
    "dd", "rm", "ash", "busybox", "csh", "dash", "ed", "env", "expect", "find",
    "ftp", "gdb", "ld.so", "lua", "mail", "perl", "rlwrap", "rpm", "rsync",
    "ruby", "scp", "sh", "ssh", "tclsh", "telnet", "vim", "socket", "view",
    "rview", "rvim", "perl", "julia", "jrunscript", "jjs", "gimp",
    "easy_install", "nc", "cpan"
]

# Function to locate a binary in the PATH
def locate_bins(binary):
    paths = []
    for path_dir in os.environ["PATH"].split(os.pathsep):
        for root, _, files in os.walk(path_dir):
            if binary in files:
                bin_path = os.path.join(root, binary)
                if os.access(bin_path, os.X_OK):  # Check if executable
                    paths.append(bin_path)
    return paths

# Function to move a GTFOBin to the destination directory and make it non-executable
def move_bin(binary):
    if command_exists(binary):
        for bin_path in locate_bins(binary):
            try:
                shutil.move(bin_path, DEST_DIR)
                dest_path = os.path.join(DEST_DIR, os.path.basename(bin_path))
                # Remove executable permission
                os.chmod(dest_path, os.stat(dest_path).st_mode & ~stat.S_IEXEC)
                print(f"Moved {binary} to {DEST_DIR} and made it non-executable")
            except Exception as e:
                print(f"Error moving {binary}: {e}")
    else:
        print(f"{binary} not found on this system.")

# Function to restore a GTFOBin to its original location and make it executable
def restore_bin(binary):
    bin_path = os.path.join(DEST_DIR, binary)
    if os.path.isfile(bin_path):
        try:
            dest_path = os.path.join("/usr/bin", binary)
            shutil.move(bin_path, dest_path)
            # Add executable permission
            os.chmod(dest_path, os.stat(dest_path).st_mode | stat.S_IEXEC)
            print(f"Moved {binary} back to /usr/bin and restored executable permissions")
        except Exception as e:
            print(f"Error restoring {binary}: {e}")
    else:
        print(f"{binary} not found in {DEST_DIR}")

def main():
    # Create the destination directory if it does not exist
    if not os.path.isdir(DEST_DIR):
        os.makedirs(DEST_DIR)

    # Prompt the user for action
    print("Choose an action:")
    print("1. Move GTFOBins to a different location and make them non-executable")
    print("2. Restore GTFOBins to their original locations and make them executable")
    
    try:
        choice = int(input("Enter your choice (1 or 2): "))
        
        if choice == 1:
            bin_name = input("Enter the name of the binary to move (or 'all' to move all GTFOBins): ")
            if bin_name == "all":
                for bin in GTFOBINS:
                    move_bin(bin)
            else:
                move_bin(bin_name)
        elif choice == 2:
            bin_name = input("Enter the name of the binary to restore (or 'all' to restore all GTFOBins): ")
            if bin_name == "all":
                for bin in GTFOBINS:
                    restore_bin(bin)
            else:
                restore_bin(bin_name)
        else:
            print("Invalid choice. Please run the script again and choose 1 or 2.")
    except ValueError:
        print("Please enter a number (1 or 2).")

if __name__ == "__main__":
    main()