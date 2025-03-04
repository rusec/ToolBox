#! /usr/bin/python3
import config
from util import log
from console import run_command_sudo, check_command, install_pkg
import git_utils
import sys
import auditctl
import logger
import os
import atexit
import subprocess
import threading

watchdir_log = logger.Logger(2, log_to_console=True, log_file=config.WATCH_DIR_LOG_FILE)
watchdir_access_log = logger.Logger(2, log_file=config.WATCH_ACCESS_LOG_FILE)

def watchable(file:str):


    if ".git" in file:
        return False

    ext_not_to_watch = [
        ".swp",
        ".swx",
        ".swpx",
        "~",
        ".part",
        ".crdownload",
        ".tmp",
        ".temp",
        ".lock",
        ".git",
        ".log"
    ]
    paths_not_to_watch = [
        "/proc",
        "/sys",
        "/run",
    ]

    for path in paths_not_to_watch:
        if file.startswith(path):
            return False

    for ext in ext_not_to_watch:
        if ext in file:
            return False

    if file.startswith("."):
        return False


    return True

def log_change(event, file):
    if not git_utils.check_repo():
        log("Git repo does not exist", "ERROR")
        return False

    if not watchable(file):
        return False

    if "ACCESS" in str.upper(event) or  "CLOSE" in str.upper(event) :
        watchdir_access_log.log("File {} was accessed".format(file))
        return True

    if not os.path.exists(file):
        watchdir_log.log("File {} was deleted - might be a dropped executable".format(file), "WARNING")
        return True

    watchdir_log.log("{} - {}".format(event, file), "INFO")


    git_utils.commit(event, file)


def on_exit():
    watchdir_log._flush(True)
    watchdir_access_log._flush(True)
    git_utils.git_log._flush(True)

atexit.register(on_exit)


def set_interval(func, sec):

    def func_wrapper():
        set_interval(func, sec)
        func()
    t = threading.Timer(sec, func_wrapper)
    t.start()
    return t


def inotify_generator(path:str) -> str:

    if not check_command("inotifywait"):
        log("inotify-tools package is not installed", "ERROR")
        return

    process = subprocess.Popen(['inotifywait', '-m', '-r', '-e', 'modify,attrib,close_write,move,create,delete', path, '--format', "'%e, %w%f'"],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    try:
        if not process:
            log("Failed to start inotifywait process", "ERROR")
            return

        if not process.stdout:
            log("Failed to start inotifywait process", "ERROR")
            return

        for stdout_line in iter(process.stdout.readline, ""):
            yield stdout_line.strip()

    except Exception as e:
        log("Error in inotify_generator: {}".format(e), "ERROR")
    finally:

        if not process:
            return

        if not process.stdout:
            return

        if not process.stderr:
            return

        process.stdout.close()
        process.stderr.close()
        process.terminate()


def main():
    log("Starting script on directory: {}".format(config.WATCH_DIR))

    if config.DEBUG:
        log("Debug mode is enabled will not install packages")

    # Check if inotifywait is installed
    log("Checking dependencies")
    if not check_command("inotifywait"):
        log("Installing inotify-tools package")
        if not install_pkg("inotify-tools"):
            log("Failed to install inotify-tools package", "ERROR")
            sys.exit(1)

    else:
        log("inotify-tools package is already installed")

    # Check if git is installed
    if not check_command("git"):
        log("Installing git package")
        if not install_pkg("git"):
            log("Failed to install git package", "ERROR")
            sys.exit(1)
    else:
        log("git package is already installed")

    # Check if auditd is installed
    if not check_command("auditctl"):
        log("Installing auditd package")
        if not install_pkg("auditd"):
            log("Failed to install auditd package", "ERROR")
            sys.exit(1)
    else:
        log("auditd package is already installed")


    # Check if git repo exists
    if not run_command_sudo("git -C {} status".format(config.WATCH_DIR)):
        # init git repo and auditd
        log("Initializing git repo")
        if not git_utils.init_repo():
            log("Failed to initialize git repo", "ERROR")
            sys.exit(1)
        auditctl.init_auditd()

    # General info
    info = '''
        _________________________________________________
        |                                               |
        |              Useful Commands                  |
        |_______________________________________________|
        |                                               |
        |    - git reset --hard <Sha256 commit hash>    |
        |    - git log                                  |
        |    - git status                               |
        |_______________________________________________|
        |                                               |
        | AUDITD:                                       |
        |    - ausearch -k $AUDITDKEY                   |
        |    - aureport -k                              |
        |    - auditctl -l                              |
        |_______________________________________________|


    '''
    print(info)

    config.print_config()
    
    try:
        # Start inotifywait
        log("Starting inotifywait")
        for line in inotify_generator(config.WATCH_DIR):
            if not line:
                continue

            event, file = line.replace("'", "").split(" ")

            log_change(event, file)


        set_interval(git_utils.backup_git_directory, config.BACKUP_INTERVAL)
    except KeyboardInterrupt:
        log("Exiting script")
        sys.exit(0)
    except Exception as e:
        log("Error in main: {}".format(e), "ERROR")
        sys.exit(1)
