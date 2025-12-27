from console import run_command_sudo, run_command_sudo_check
import config
import hashlib
import os
from util import log, exit_with_error
import shutil
import logger
import time


base_name = None
git_dir_basename = None
repo_dir = None
git_log = None

def init():
    global base_name, git_dir_basename, repo_dir, git_log
    
    # helper for git_utils that depend on config
    base_name = os.path.basename(config.WATCH_DIR)
    git_dir_basename = base_name + "_" + hashlib.md5(base_name.encode()).hexdigest()
    repo_dir = os.path.join(config.BACKUP_DIR, git_dir_basename, "current.git")
    git_log = logger.Logger(2, log_file=os.path.join(config.LOG_DIR, config.WATCH_GIT_LOG_FILE))

def check_repo():
    # repo is a separate directory
    return os.path.isdir(repo_dir) and os.path.isfile(os.path.join(config.WATCH_DIR, ".git"))

def backup_init_repo():
    init_repo_dir = os.path.join(config.BACKUP_DIR,"init_" + git_dir_basename)
    if not os.path.isdir(init_repo_dir):
        git_log.log("Creating initial git repo backup")
        os.makedirs(init_repo_dir)

    if not os.path.isdir(config.WATCH_DIR):
        exit_with_error("Watch directory does not exist")
        return False

    if not os.path.isdir(repo_dir):
        log("Git repo does not exist in the directory", "ERROR")
        return False

    if not os.path.exists(os.path.join(config.WATCH_DIR, ".git")):
        log("Git repo does not exist in the directory", "ERROR")
        return

    if not run_command_sudo("git clone --mirror {} {}".format(config.WATCH_DIR, init_repo_dir)):
        log("Failed to clone git repo", "ERROR")
        return False

    log("Initial git repo backup created successfully")
    return True

def init_repo():

    if not os.path.isdir(config.WATCH_DIR):
        exit_with_error("Watch directory does not exist")

    if check_repo():
        log("Repo already exists")
        return False

    if not os.path.isdir(repo_dir):
        os.makedirs(repo_dir)

    old_dir = os.getcwd()
    os.chdir(config.WATCH_DIR)

    if not run_command_sudo("git config --global user.email 'admin@admin.com'"):
        os.chdir(old_dir)
        log("Failed to set git email", "ERROR")
        return False

    if not run_command_sudo("git config --global user.name 'watchdir'"):
        os.chdir(old_dir)
        log("Failed to set git name", "ERROR")
        return False

    if not run_command_sudo("git config --global --add safe.directory {}".format(config.WATCH_DIR)):
        os.chdir(old_dir)
        log("Failed to set safe directory", "ERROR")
        return False

    # creates  a separate git directory, but a .git file is created in the watch directory
    if not run_command_sudo("git init --separate-git-dir {} {}".format(repo_dir, config.WATCH_DIR)):
        os.chdir(old_dir)
        log("Failed to initialize git repo in separate dir", "ERROR")
        return False

    if not run_command_sudo("git branch -m main"):
        os.chdir(old_dir)
        log("Failed to rename branch", "ERROR")
        return False


    if len(os.listdir(config.WATCH_DIR)) == 0:
        os.chdir(old_dir)
        log("No files in the directory", "WARNING")
        log("Git repo initialized successfully")
        return True

    if not run_command_sudo("git add ."):
        os.chdir(old_dir)
        log("Failed to add files to git", "ERROR")
        return False

    if not run_command_sudo_check("git commit -m 'Initial commit'", "nothing to commit"):
        os.chdir(old_dir)
        log("Failed to commit files to git", "ERROR")
        return  False

    backup_init_repo()
    os.chdir(old_dir)
    log("Git repo initialized successfully")

    return True


def backup_git_directory():
    current_time = time.strftime("%Y_%m_%d_%I_%M_%S")
    backup_dir = os.path.join(config.BACKUP_DIR, git_dir_basename, current_time)
    if not os.path.isdir(backup_dir):
        os.makedirs(backup_dir)

    if not run_command_sudo("git clone --mirror {} {}".format(config.WATCH_DIR, backup_dir)):
        git_log.log("Failed to backup git directory", "ERROR")
        return False

    git_log.log("Backup created successfully")

    backup_count = len(os.listdir(os.path.join(config.BACKUP_DIR, git_dir_basename)))

    if backup_count > 6:
        oldest_backup = os.path.join(config.BACKUP_DIR, git_dir_basename, os.listdir(os.path.join(config.BACKUP_DIR, git_dir_basename))[0])
        shutil.rmtree(oldest_backup)
        git_log.log("Deleted oldest backup")


    return True

COMMIT_COUNT = 0 # global variable

def commit(event, file):
    if not os.path.isfile(file):
        git_log.log("File does not exist: {}".format(file), "ERROR")
        return False

    if not run_command_sudo("git -C {} add {}".format(config.WATCH_DIR, file)):
        git_log.log("Failed to add file to git", "ERROR")
        return False

    if not run_command_sudo_check("git -C {} commit -m '{} - {}'".format(config.WATCH_DIR, event, file), "nothing to commit"):
        git_log.log("Failed to commit file to git", "ERROR")
        return False

    git_log.log("{} - {}".format(event, file))

    global COMMIT_COUNT

    COMMIT_COUNT += 1

    if COMMIT_COUNT > 10:
        backup_git_directory()
        COMMIT_COUNT = 0

    return True
