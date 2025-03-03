#! /usr/bin/python3
import config
from until import log
from console import run_command_sudo, check_command, install_pkg
import sys

def main():
    log("Starting watchdir.py script on directory: {}".format(WATCH_DIR))

    if config.DEBUG:
        log("Debug mode is enabled will not install packages")

    log("Checking if package is installed")
    if not check_command("inotifywait"):
        log("Installing inotify-tools package")
        if not install_pkg("inotify-tools"):
            log("Failed to install inotify-tools package", "ERROR")
            sys.exit(1)

    else:
        log("inotify-tools package is already installed")
    
    if not check_command("git"):
        log("Installing git package")
        if not install_pkg("git"):
            log("Failed to install git package", "ERROR")
            sys.exit(1)
    else:
        log("git package is already installed")
    
    if not check_command("auditctl"):
        log("Installing auditd package")
        if not install_pkg("auditd"):
            log("Failed to install auditd package", "ERROR")
            sys.exit(1)
    else:
        log("auditd package is already installed")
    
    log("Creating auditd rule")
    if not run_command_sudo("auditctl -w {} -k {}".format(config.WATCH_DIR, config.AUDITDKEY)):
        log("Failed to create auditd rule", "ERROR")
        sys.exit(1)
    else:
        log("Auditd rule created successfully")
    
