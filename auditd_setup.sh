#!/bin/bash

# Define the audit rules file and log file location
AUDIT_RULES_FILE="/etc/audit/rules.d/command_monitor.rules"
LOG_FILE="/var/log/audit/audit.log"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect OS and package manager
detect_os() {
    if command_exists apt; then
        echo "apt"
    elif command_exists yum; then
        echo "yum"
    elif command_exists dnf; then
        echo "dnf"
    elif command_exists zypper; then
        echo "zypper"
    elif command_exists pacman; then
        echo "pacman"
    else
        echo "unsupported"
    fi
}

# Function to install auditd
install_auditd() {
    local package_manager=$1
    case $package_manager in
    apt)
        sudo apt update && sudo apt install -y auditd audispd-plugins
        ;;
    yum|dnf)
        sudo $package_manager install -y audit
        ;;
    zypper)
        sudo zypper install -y audit
        ;;
    pacman)
        sudo pacman -Sy --noconfirm audit
        ;;
    *)
        echo "Unsupported package manager. Exiting."
        exit 1
        ;;
    esac
}

# Function to configure auditd for command monitoring
configure_auditd() {
    # Create an audit rule to log executed commands
    echo "-a always,exit -F arch=b64 -S execve -k commands" | sudo tee "$AUDIT_RULES_FILE" >/dev/null
    echo "-a always,exit -F arch=b32 -S execve -k commands" | sudo tee -a "$AUDIT_RULES_FILE" >/dev/null
    echo "-a exit,always -F arch=b64 -F euid=0 -S execve -k  commands" | sudo tee -a "$AUDIT_RULES_FILE" >/dev/null
    echo "-a exit,always -F arch=b32 -F euid=0 -S execve -k  commands" | sudo tee -a "$AUDIT_RULES_FILE" >/dev/null

    # Restart auditd to apply the new rules
    sudo systemctl restart auditd

    # Ensure auditd starts on boot
    sudo systemctl enable auditd

    echo "Auditd has been configured to monitor executed commands."
    echo "Logs can be found at: $LOG_FILE"
}

# Main script logic
echo "Detecting OS and package manager..."
PACKAGE_MANAGER=$(detect_os)

if [ "$PACKAGE_MANAGER" = "unsupported" ]; then
    echo "Unsupported operating system or package manager. Exiting."
    exit 1
fi

echo "Installing auditd..."
install_auditd "$PACKAGE_MANAGER"

echo "Configuring auditd for command monitoring..."
configure_auditd

echo "Setup complete. Monitoring is now active."
