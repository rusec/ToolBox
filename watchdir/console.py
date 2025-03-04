import config
import util
import os
import platform
from subprocess import getstatusoutput
# Runs command as sudo
def run_command_sudo(command)-> bool:

    if os.geteuid() != 0:
        res = getstatusoutput("sudo {}".format(command))

        if config.DEBUG:
            util.log(res[1])
        return res[0] == 0


    elif os.geteuid() == 0:
        res = getstatusoutput(command)

        if config.DEBUG:
            util.log(res[1])
        return res[0] == 0

    else:
        util.log("Cannot run command as sudo", "ERROR")
        return False

def run_command(command):
    if config.DEBUG:
        util.log("Running command: {}".format(command))
        return True

    return os.system(command) == 0

def check_command(command) -> bool:
    res = getstatusoutput("which {}".format(command))

    if config.DEBUG:
        util.log(res[1])

    return res[0] == 0

def install_pkg(pkg):
    if config.DEBUG:
        util.log("Installing package: {}".format(pkg))

    system_os = platform.system().lower()

    if system_os == "darwin":
        return run_command("brew install {} -y".format(pkg))

    commands = [
        ("apt", "apt install {} -y"),
        ("apt-get", "apt-get install {} -y"),
        ("yum", "yum install {} -y"),
        ("dnf", "dnf install {} -y"),
        ("zypper", "zypper install {} -y"),
        ("pacman", "pacman -S --noconfirm {}"),
        ("apk", "apk add {}"),
        ("emerge", "emerge install {} -y")
    ]

    for cmd, command in commands:
        if check_command(cmd):
            return run_command_sudo(command.format(pkg)) ==  0

    return False
