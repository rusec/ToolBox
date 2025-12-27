from util import exit_with_error, log
from sys import argv
import os
import hashlib
import shutil
# Constants
AUDITDKEY = "watchdir-script"
BACKUP_DIR = "/tmp/windex"
DEBUG = os.getenv("DEBUG", False) == "True"

WATCH_DIR = None
BASE_DIR = None
BASE_NAME = None
LOG_DIR = os.getenv("LOG_DIR", "/var/log/watchdir")
WATCH_DIR_LOG_FILE = None
WATCH_ACCESS_LOG_FILE = None
WATCH_GIT_LOG_FILE = None
BACKUP_INTERVAL = 3600

def init(directory_to_watch):
    global WATCH_DIR, BASE_DIR, BASE_NAME, LOG_DIR, WATCH_DIR_LOG_FILE, WATCH_ACCESS_LOG_FILE, WATCH_GIT_LOG_FILE, BACKUP_INTERVAL

    if not directory_to_watch:
        exit_with_error("Please provide a directory to watch")

    WATCH_DIR = os.path.abspath(directory_to_watch)
    
    # Check if directory exists
    if WATCH_DIR.startswith("~"):
        WATCH_DIR = os.path.expanduser(WATCH_DIR)
    elif WATCH_DIR.startswith("."):
        WATCH_DIR = os.path.abspath(WATCH_DIR)
    
    if not os.path.isdir(WATCH_DIR):
        exit_with_error("Directory does not exist: {}".format(WATCH_DIR))

    BASE_DIR = os.path.basename(WATCH_DIR)
    BASE_NAME = BASE_DIR + "_" + hashlib.md5(BASE_DIR.encode()).hexdigest()
    
    WATCH_DIR_LOG_FILE = os.getenv("LOG_FILE", "/var/log/watchdir/{}.log".format(BASE_NAME))
    WATCH_ACCESS_LOG_FILE = os.getenv("ACCESS_LOG_FILE", "/var/log/watchdir/{}.access.log".format(BASE_NAME))
    WATCH_GIT_LOG_FILE = os.getenv("GIT_LOG_FILE", "/var/log/watchdir/{}.git.log".format(BASE_NAME))

    if os.getuid() != 0:
        exit_with_error("Please run this script as sudo")

    if not os.path.isdir(LOG_DIR):
        os.makedirs(LOG_DIR)

    if not os.path.isdir(BACKUP_DIR):
        os.makedirs(BACKUP_DIR)
        
    if DEBUG:
        BACKUP_INTERVAL = 60
    else:
        BACKUP_INTERVAL = 3600

def print_config():


    log("WATCH_DIR: {}".format(WATCH_DIR))
    log("AUDITDKEY: {}".format(AUDITDKEY))
    log("LOG_DIR: {}".format(LOG_DIR))
    log("WATCH_DIR_LOG_FILE: {}".format(WATCH_DIR_LOG_FILE))
    log("WATCH_ACCESS_LOG_FILE: {}".format(WATCH_ACCESS_LOG_FILE))
    log("WATCH_GIT_LOG_FILE: {}".format(WATCH_GIT_LOG_FILE))
    log("DEBUG: {}".format(DEBUG))
    log("BACKUP_DIR: {}".format(BACKUP_DIR))
    log("BACKUP_INTERVAL: {}".format(BACKUP_INTERVAL))


def clean_up():

    log("Cleaning up")
    if os.path.isdir(BACKUP_DIR):
        shutil.rmtree(BACKUP_DIR)
        log("Backup directory deleted")
    else:
        log("Backup directory does not exist")

    if os.path.isdir(LOG_DIR):
        shutil.rmtree(LOG_DIR)
        log("Log directory deleted")
    else:
        log("Log directory does not exist")

    log("Exiting")
    exit(0)
