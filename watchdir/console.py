import config
import until
import os
import sys
import platform

# Runs command as sudo 
def run_command_sudo(command)-> bool:
    if config.DEBUG:
        until.log("Running command as sudo: {}".format(command))
        return True
    
    if os.geteuid() != 0:
        return os.system("sudo", command) == 0
    elif os.geteuid() == 0:
        return os.system(command) == 0
    else:
        until.log("Cannot run command as sudo", "ERROR")
        sys.exit(1)
          
def run_command(command):
    if config.DEBUG:
        until.log("Running command: {}".format(command))
        return True

    return os.system(command) == 0

def check_command(command) -> bool:
    res = os.system("which {}".format(command)) == 0

    if config.DEBUG:
        until.log("Checking if command exists: {} {}".format(command,res))
        return True

    return res

def install_pkg(pkg) ->bool:
    if config.DEBUG:
        until.log("Installing package: {}".format(pkg))

    system_os = platform.system().lower()

    if system_os == "darwin":
        return run_command("brew install {} -y".format(pkg))
    elif system_os == "linux":
        if check_command("apt"):
            return run_command_sudo("apt install {} -y".format(pkg))
        elif check_command("apt-get"):
            return run_command_sudo("apt-get install {} -y".format(pkg))
        elif check_command("yum"):
            return run_command_sudo("yum install {}".format(pkg))
        elif check_command("dnf"):
            return run_command_sudo("dnf install {}".format(pkg))
        elif check_command("zypper"):
            return run_command_sudo("zypper install {} -y".format(pkg))
        elif check_command("pacman"):
            return run_command_sudo("pacman -S --noconfirm {}".format(pkg))
        elif check_command("apk"):
            return run_command_sudo("apk add {}".format(pkg))
        elif check_command("emerge"):
            return run_command_sudo("emerge install {} -y".format(pkg))
        else:
            return False


def restart_service(service_name):
    if check_command("systemctl"):
        return run_command_sudo("systemctl restart {}".format(service_name))
    elif check_command("service"):
        return run_command_sudo("service {} restart".format(service_name))
    elif check_command("initctl"):
        return run_command_sudo("initctl restart {}".format(service_name))
    elif check_command("rc-service"):
        return run_command_sudo("rc-service {} restart".format(service_name))
    elif check_command("sv"):
        return run_command_sudo("sv restart {}".format(service_name))
    elif check_command("openrc-service"):
        return run_command_sudo("openrc-service {} restart".format(service_name))
    elif check_command("launchctl"):
        return run_command_sudo("launchctl stop {}".format(service_name)) and run_command_sudo("launchctl start {}".format(service_name))
    elif check_command("rcctl"):
        return run_command_sudo("rcctl restart {}".format(service_name))
    elif check_command("s6-svc"):
        return run_command_sudo("s6-svc -r /run/s6/services/{}".format(service_name))
    elif check_command("supervisorctl"):
        return run_command_sudo("supervisorctl restart {}".format(service_name))
    elif check_command("runit"):
        return run_command_sudo("sv restart {}".format(service_name))
    elif check_command("daemontools"):
        return run_command_sudo("svc -t /service/{}".format(service_name))
    elif check_command("sysv-rc-conf"):
        return run_command_sudo("sysv-rc-conf {} restart".format(service_name))
    elif check_command("update-rc.d"):
        return run_command_sudo("update-rc.d {} defaults".format(service_name))
    elif check_command("chkconfig"):
        return run_command_sudo("chkconfig {} on".format(service_name))
    else:
        until.log("Service manager not supported. Please restart {} manually.".format(service_name), "ERROR")
        return False
