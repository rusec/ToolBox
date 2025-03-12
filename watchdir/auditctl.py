from console import check_command, install_pkg, run_command_sudo
from util import log
import config
import sysctl

def init_auditd():

    log("Checking dependencies")
    if not check_command("auditctl"):
        log("Installing auditd package")
        if not install_pkg("auditd"):
            log("Failed to install auditd package", "ERROR")
            return False


    log("Creating auditd rule")
    if not run_command_sudo("auditctl -w {} -k {}".format(config.WATCH_DIR, config.AUDITDKEY)):
        if not run_command_sudo("auditctl -a always,exit -F dir={}  -F perm=war -k {}".format(config.WATCH_DIR, config.AUDITDKEY)):
            log("Failed to create auditd rule", "ERROR")
            return False
        else:
            log("Auditd rule created successfully")
    else:
        log("Auditd rule created successfully")

    sysctl.restart_service("auditd")

    return True
