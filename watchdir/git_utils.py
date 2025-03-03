from console import run_command_sudo, check_command
import config
import hashlib
import os
from until import log, exit_with_error
import sys
import shutil
import logger
base_name = os.path.basename(config.WATCH_DIR)
git_dir_basename = base_name + "_" +hashlib.md5(base_name.encode()).hexdigest()
repo_dir = os.path.join(config.BACKUP_DIR, git_dir_basename, "current.git")

log = logger.Logger(2, os.path.join(config.LOG_DIR, git_dir_basename + ".log"))

def check_repo():
    # repo is a separate directory
    return os.path.isdir(repo_dir)

def backup_init_repo():
    current_time = time.time()
    init_repo_dir = os.path.join(config.BACKUP_DIR,"init_" + git_dir_basename)
    if not os.path.isdir(init_repo_dir):
        log.log("Creating initial git repo backup")
        os.makedirs(init_repo_dir)

    if not os.path.isdir(config.WATCH_DIR):
        exit_with_error("Watch directory does not exist")
        return False
    
    if not os.path.isdir(git_repo_dir):
        log("Git repo does not exist in the directory", "ERROR")
        return False
    if not os.path.join(config.WATCH_DIR, ".git"):
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
        return False
    
    old_dir = os.getcwd()
    os.chdir(repo_dir)
    
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
        log("Failed to initialize git repo", "ERROR")
        return False

    if not run_command_sudo("git branch -m main"):
        os.chdir(old_dir)
        log("Failed to rename branch", "ERROR")
        return False
    
    if not run_command_sudo("git add *"):
        os.chdir(old_dir)
        log("Failed to add files to git", "ERROR")
        return False

    if not run_command_sudo("git commit -m 'Initial commit'"):
        os.chdir(old_dir)
        log("Failed to commit files to git", "ERROR")
        return  False

    backup_init_repo()
    os.chdir(old_dir)
    log("Git repo initialized successfully")

def backup_repo():

    if not os.path.isdir(config.WATCH_DIR):
        exit_with_error("Watch directory does not exist")
    
    if not check_repo():
        log("Repo does not exist")
        return False

    timestamp = time.time().strftime("%Y-%m-%d_%H:%M:%S")
    backup_dir = os.path.join(config.BACKUP_DIR, git_dir_basename, timestamp + ".git") 
    if not os.path.isdir(backup_dir):
        os.makedirs(backup_dir)
    
    shutil.copytree(repo_dir, backup_dir)
    log("Backup created successfully")
    
    
