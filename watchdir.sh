#!/bin/bash
# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}
get_path(){
    if command_exists realpath; then
        realpath "$1"
        elif command_exists readlink; then
        readlink -f "$1"
    else
        echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
    fi
}

# Check if WATCH_DIR is passed as an argument
if [ -z "$1" ]; then
    # If not provided, prompt the user
    read -r -p "Dir Path: " WATCH_DIR || exit 1
else
    # If provided, use the first argument
    WATCH_DIR=$1
fi
WATCH_DIR=$(get_path "$WATCH_DIR")

echo "Using directory: $WATCH_DIR"

BASENAME=$(basename $WATCH_DIR)
LOG_DIR=$(get_path "./logs")



mkdir -p $LOG_DIR
LOG_FILE="$LOG_DIR/$BASENAME.log"
LOG_GIT_FILE="$LOG_DIR/$BASENAME.git.log"
LOG_ACCESS_LOG_FILE="$LOG_DIR/$BASENAME.access.log"
AUDITDKEY="watchdir-script"
BACKUP_DIR="/tmp/windex"

if [ "$IS_DEV" = "1" ]; then
    BACKUP_DELAY=60
else
    BACKUP_DELAY=600
fi

# Check and install a pkg if not present
install_pkg() {
    if command_exists apt-get; then
        sudo apt-get update
        sudo apt-get install -y $1
        elif command_exists dnf; then
        sudo dnf install -y $1
        elif command_exists yum; then
        sudo yum install -y $1
        elif command_exists zypper; then
        sudo zypper install -y $1
        elif command_exists pacman; then
        sudo pacman -S --noconfirm $1
        elif command_exists apk; then
        sudo apk add $1
        elif command_exists brew; then
        brew install $1
        elif command_exists pkg; then
        sudo pkg install -y $1
        elif command_exists emerge; then
        sudo emerge -av $1
        elif command_exists xbps-install; then
        sudo xbps-install -S $1
        elif command_exists eopkg; then
        sudo eopkg install -y $1
        elif command_exists guix; then
        guix package -i $1
        elif command_exists nix-env; then
        nix-env -i $1
    else
        echo "Package manager not supported. Please install $1 manually."
        exit 1
    fi
}

restart_service() {
    if command_exists systemctl; then
        sudo systemctl restart $1
        elif command_exists service; then
        sudo service $1 restart
        elif command_exists initctl; then
        sudo initctl restart $1
        elif command_exists rc-service; then
        sudo rc-service $1 restart
        elif command_exists sv; then
        sudo sv restart $1
        elif command_exists openrc-service; then
        sudo openrc-service $1 restart
        elif command_exists launchctl; then
        sudo launchctl stop $1
        sudo launchctl start $1
        elif command_exists rcctl; then
        sudo rcctl restart $1
        elif command_exists s6-svc; then
        sudo s6-svc -r /run/s6/services/$1
        elif command_exists supervisorctl; then
        sudo supervisorctl restart $1
        elif command_exists sv; then
        sudo sv restart $1
        elif command_exists runit; then
        sudo sv restart $1
        elif command_exists daemontools; then
        sudo svc -t /service/$1
        elif command_exists sysv-rc-conf; then
        sudo sysv-rc-conf $1 restart
        elif command_exists update-rc.d; then
        sudo update-rc.d $1 defaults
        elif command_exists chkconfig; then
        sudo chkconfig $1 on
    else
        echo "Service manager not supported. Please restart $1 manually."
    fi
}

echo "Checking dependencies..."

# Check if inotifywait is installed, install if not
if ! command_exists inotifywait; then
    echo "inotify-tools is not installed. Installing..."
    install_pkg "inotify-tools"
    
fi

if ! command_exists git; then
    echo "git is not installed. Installing..."
    install_pkg "git"
fi

if ! command_exists auditctl; then
    echo "auditd is not installed. Installing..."
    install_pkg "auditd"
fi



# Function to exit with an error message
exit_with_error() {
    echo "Error: $1"
    echo "Error: $1" >> "$LOG_FILE"
    
    exit 1
}

copy_initial_git_repo(){
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%I-%M-%S')
    local repo_name=$BASENAME
    local backup_dir="${BACKUP_DIR}/${repo_name}_init/${timestamp}"
    local target_dir
    target_dir=$(echo "$WATCH_DIR" | sed 's:/*$::')
    
    mkdir -p "$backup_dir"
    sudo cp -r "$target_dir/.git" $backup_dir
    echo "Backed up $target_dir/.git to $backup_dir" >> $LOG_GIT_FILE
}


initialize_git_repo() {
    cd "$WATCH_DIR" || exit_with_error "Could not change to directory $WATCH_DIR"
    echo "Initializing git repo in dir $WATCH_DIR"
    git init
    git config --global user.name "dontworryaboutthisitsinthescript"
    git config --global user.email admin@admin.com
    git config --global --add safe.directory $WATCH_DIR
    git branch -m "main"
    git add * || true
    git commit -m "Initial commit" || true
    cd - > /dev/null || exit_with_error "Could not change to previous directory"
    echo "Initializing git repo in dir"
    
    copy_initial_git_repo
}


initialize_auditd() {
    echo "Initializing auditd"
    
    if ! sudo auditctl -w "$WATCH_DIR" -p war -k "$AUDITDKEY"; then
        sudo auditctl -a always,exit -F dir="$WATCH_DIR" -F perm=war -k "$AUDITDKEY"
    fi
    
    echo "Initialized auditd"
    
    restart_service auditd
    
    echo "Restarted auditd"
}


# Ensure the log file exists
touch "$LOG_FILE"
touch "$LOG_GIT_FILE"
touch "$LOG_ACCESS_LOG_FILE"


if [ ! -d "$WATCH_DIR/.git" ]; then
    echo "Initializing git repo in dir"
    initialize_git_repo
    initialize_auditd
fi

echo ""
echo "_________________________________________________"
echo "|                                               |"
echo "|              Useful Commands                  |"
echo "|_______________________________________________|"
echo "|                                               |"
echo "| GIT:                                          |"
echo "|    - git reset --hard <Sha256 commit hash>    |"
echo "|    - git log                                  |"
echo "|    - git status                               |"
echo "|_______________________________________________|"
echo "|                                               |"
echo "| AUDITD:                                       |"
echo "|    - ausearch -k $AUDITDKEY                   |"
echo "|    - aureport -k                              |"
echo "|    - auditctl -l                              |"
echo "|_______________________________________________|"
echo ""


# Function to back up .git directories to /backup_dir
backup_git_directories() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%I-%M-%S')
    local repo_name=$BASENAME
    local backup_dir="${BACKUP_DIR}/${repo_name}/${timestamp}"
    local target_dir
    target_dir=$(echo "$WATCH_DIR" | sed 's:/*$::')
    
    mkdir -p "$backup_dir"
    sudo cp -r "$target_dir/.git" $backup_dir
    echo "Backed up $target_dir/.git to $backup_dir" >> $LOG_GIT_FILE
    
    # Remove old backups if more than 6 exist
    local backups_count
    backups_count=$(ls -1 "${BACKUP_DIR}/${repo_name}" | wc -l)
    if [ "$backups_count" -gt 6 ]; then
        local backups_to_delete=$((backups_count - 6))
        ls -1t "${BACKUP_DIR}/${repo_name}" | tail -n "$backups_to_delete" | xargs -I {} sudo rm -rf "${BACKUP_DIR}/${repo_name}/{}"
        echo "Deleted $backups_to_delete old backups." >> "$LOG_GIT_FILE"
    fi
}

COMMIT_COUNT=0

add_commit() {
    local event="$1"
    local file="$2"
    
    if [[ "$event" = "ACCESS" ]] ||  [[ "$event" = "ACCESS,ISDIR" ]]; then
        return 0
    fi
    
    
    git -C "$WATCH_DIR" add "$file" > /dev/null || true
    git -C "$WATCH_DIR" commit -m "$event $file" > /dev/null || true
    
    echo "logged $event $file to git" >> "$LOG_GIT_FILE"
    
    # Backup git directories every 10 commits
    
    COMMIT_COUNT=$((COMMIT_COUNT + 1))
    if [ "$COMMIT_COUNT" -gt 10 ]; then
        backup_git_directories
        COMMIT_COUNT=0
    fi
    
}



# Function to log changes
log_change() {
    local event="$1"
    local file="$2"
    
    
    if [[ "$file" == *.swp ]] || [[ "$file" == *.swpx ]] || [[ "$file" == *~ ]] || [[ "$file" == *.lock ]] || [[ "$file" == *.git/* ]] || [[ "$file" == /proc/ ]] || [[ "$file" == /run/ ]]; then
        return 0
    fi
    
    
    if [[ "$event" = "ACCESS" ]] || [[ "$event" = "ACCESS,ISDIR" ]]; then
        echo "$(date '+%I:%M:%S %Y-%m-%d') - $event - $file" >> "$LOG_ACCESS_LOG_FILE"
    else
        echo "$(date '+%I:%M:%S %Y-%m-%d') - $event - $file"
        echo "$(date '+%I:%M:%S %Y-%m-%d') - $event - $file" >> "$LOG_FILE"
    fi
    
    if [ ! -d "$WATCH_DIR/.git" ]; then
        initialize_git_repo
        initialize_auditd
    fi
    
    
    add_commit $event $file
}


echo "Watching directory $WATCH_DIR"
echo "Logs are stored in $LOG_FILE"
echo "Git logs are stored in $LOG_GIT_FILE"
echo "Access logs are stored in $LOG_ACCESS_LOG_FILE"
echo "Backup gits are stored in $BACKUP_DIR/$BASENAME"
echo "Backup of init gits are stored in $BACKUP_DIR/${BASENAME}_init"

echo "Backing up every $BACKUP_DELAY seconds"
echo ""

trap 'echo "Cleaning up...";kill $(jobs -p); exit' SIGINT SIGTERM

inotifywait -m -r -e access,modify,create,delete,move "$WATCH_DIR" --format '%e %w%f' | while read -r event file; do
    log_change "$event" "$file"
done &

# Periodically back up .git directories every $BACKUP_DELAY seconds
while true; do
    backup_git_directories
    sleep $BACKUP_DELAY
done
