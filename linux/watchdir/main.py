#! /usr/bin/python3

"""
Watch a directory for changes and log them to a git repository.
This script uses inotifywait to watch for changes in a directory and logs them to a git repository.
It also uses auditd to log access to files in the directory.


This script is designed to be run as a daemon and will run in the background.
It will log all changes to the directory and its subdirectories to a git repository.

Meant to be run for a couple of hours, to gather information about changes on a system and revert them without the need to see backups.
auditd is used to log access to files in the directory, while inotifywait is used to watch for changes in the directory. 
git is used to see what changes were made to the directory and revert them if needed.
"""


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
import argparse



# create two loggers, one for the watchdir and one for access logs, to order to not mix them up, makes them easier to read
watchdir_log = None
watchdir_access_log = None



def watchable(file:str):
    """
    Check if the file is watchable or not.
    :param file: The file to check
    :return: True if the file is watchable, False otherwise.
    """


    # check if .git is in the file path
    # this is to prevent the script from watching the .git directory
    if ".git" in file:
        return False


    # check if the following extensions are in the file path, making sure to not watch them
    # this is to prevent the script from watching temporary files, and creating non-sense commits
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
    # check if the file is in the following paths, making sure to not watch them
    # this is to prevent the script from watching system files, and creating non-sense commits
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

    # check if the file is a directory
    if file.startswith("."):
        return False

    return True


def log_change(event, file):
    """
    Log the change to the git repository and auditd.
    :param event: The event that occurred (modify, create, delete, etc.)
    :param file: The file that was changed
    :return: True if the change was logged, False otherwise.
    """

    # Check if the git repo is initialized and active
    if not git_utils.check_repo():
        log("Git repo does not exist", "ERROR")
        return False

    # Check if the file is watchable
    if not watchable(file):
        return False

    # Check if the Event is a file change event, One where the file content is changed

    # if its not just log that the file was accessed, and return
    if "ACCESS" in str.upper(event) or  "CLOSE" in str.upper(event) :
        watchdir_access_log.log("File {} was accessed".format(file))
        return True

    # else check if the file still exists, if it was deleted, and log the event
    if not os.path.exists(file) and not "DELETE" in str.upper(event):
        watchdir_log.log("File {} was deleted - might be a dropped executable".format(file), "WARNING")
        return True

    watchdir_log.log("{} - {}".format(event, file), "INFO")


    # Add the file to the git repo
    git_utils.commit(event, file)



def on_exit():
    """
    Flush the logs and close the git repo.
    """
    if watchdir_log:
        watchdir_log._flush(True)
    if watchdir_access_log:
        watchdir_access_log._flush(True)
    if git_utils.git_log:
        git_utils.git_log._flush(True)

# Close the git repo on exit
atexit.register(on_exit)


def set_interval(func, sec):
    """
    Set a timer to call a function every sec seconds.
    :param func: The function to call
    :param sec: The number of seconds to wait before calling the function
    :return: The timer object
    """
    def func_wrapper():
        set_interval(func, sec)
        func()
    t = threading.Timer(sec, func_wrapper)
    t.start()
    return t


def inotify_generator(path:str):
    """
    Generator that yields events from inotifywait.
    :param path: The path to watch
    :return: A generator that yields events from inotifywait.
    """

    # Check if inotifywait is installed
    if not check_command("inotifywait"):
        log("inotify-tools package is not installed", "ERROR")
        return

    # Open a subprocess to run inotifywait
    # and yield the events as they come in
    # The -m flag is used to monitor the directory recursively, and -e with the events to watch for
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


def start():
    """
    Start the script and watch the directory for changes.
    :return: None
    """
    log("Starting script on directory: {}".format(config.WATCH_DIR))

    if config.DEBUG:
        log("Debug mode is enabled will not install packages")

    # Check dependencies, inotifywait, git, and auditd

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


    # Check if git repo exists, initialize it if it doesn't
    if not run_command_sudo("git -C {} status".format(config.WATCH_DIR)):
        # init git repo and auditd
        log("Initializing git repo")
        if not git_utils.init_repo():
            log("Failed to initialize git repo", "ERROR")
            sys.exit(1)

        # init git repo and auditd
        auditctl.init_auditd()

    # General info and useful commands
    # This is just a simple info message to help the user
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

        # Set the interval to backup the git directory
        set_interval(git_utils.backup_git_directory, config.BACKUP_INTERVAL)
    except KeyboardInterrupt:
        log("Exiting script")
        sys.exit(0)
    except Exception as e:
        log("Error in main: {}".format(e), "ERROR")
        sys.exit(1)


def parse_args():
    parser = argparse.ArgumentParser(description="Watch a directory for changes and log them to a git repository.")
    parser.add_argument("directory", help="The directory to watch")
    return parser.parse_args()


def main():
    args = parse_args()
    config.init(args.directory)
    git_utils.init()

    global watchdir_log, watchdir_access_log
    watchdir_log = logger.Logger(2, log_to_console=True, log_file=config.WATCH_DIR_LOG_FILE)
    watchdir_access_log = logger.Logger(2, log_file=config.WATCH_ACCESS_LOG_FILE)

    start()

if __name__ == "__main__":
    main()
