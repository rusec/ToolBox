import until
from sys import argv
# Constants
AUDITDKEY="watchdir-script"
BACKUP_DIR="/tmp/windex"
DEBUG = os.getenv("DEBUG", False) == "True"
WATCH_DIR = argv[1] or until.exit_with_error("Please provide a directory to watch")
LOG_DIR = os.getenv("LOG_DIR", "/var/log/watchdir")
LOG_FILE = os.getenv("LOG_FILE", "/var/log/watchdir/watchdir.log")

if not os.path.isdir(os.path.dirname(LOG_FILE)):
    os.makedirs(os.path.dirname(LOG_FILE))


# Check if directory exists
if WATCH_DIR.startswith("~"):
    WATCH_DIR = os.path.expanduser(WATCH_DIR)
elif WATCH_DIR.startswith("."):
    WATCH_DIR = os.path.abspath(WATCH_DIR)
elif not os.path.isdir(WATCH_DIR):
    exit_with_error("Directory does not exist: {}".format(WATCH_DIR))

if not os.path.isdir(WATCH_DIR):
    exit_with_error("Directory does not exist: {}".format(WATCH_DIR))

if DEBUG:
    BACKUP_INTERVAL = 60
else:
    BACKUP_INTERVAL = 3600

if not os.path.isdir(BACKUP_DIR):
    os.makedirs(BACKUP_DIR)