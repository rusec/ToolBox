from console import run_command_sudo, check_command
import util


def restart_service(service_name):
    commands = [
        ("systemctl", "systemctl restart {}"),
        ("service", "service {} restart"),
        ("initctl", "initctl restart {}"),
        ("rc-service", "rc-service {} restart"),
        ("sv", "sv restart {}"),
        ("openrc-service", "openrc-service {} restart"),
        ("launchctl", "launchctl stop {} && launchctl start {}"),
        ("rcctl", "rcctl restart {}"),
        ("s6-svc", "s6-svc -r /run/s6/services/{}"),
        ("supervisorctl", "supervisorctl restart {}"),
        ("runit", "sv restart {}"),
        ("daemontools", "svc -t /service/{}"),
        ("sysv-rc-conf", "sysv-rc-conf {} restart"),
        ("update-rc.d", "update-rc.d {} defaults"),
        ("chkconfig", "chkconfig {} on")
    ]

    for cmd, command in commands:
        if check_command(cmd):
            if "&&" in command:
                parts = command.split(" && ")
                for part in parts:
                    if not run_command_sudo(part.format(service_name)):
                        return False
            else:
                if not run_command_sudo(command.format(service_name)):
                    return False
            return True

    util.log("Service manager not supported. Please restart {} manually.".format(service_name), "ERROR")
    return False
