#!/bin/bash
# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if WATCH_DIR is passed as an argument
if [ -z "$1" ]; then
    # If not provided, prompt the user
    read -r -p "Dir Path: " WATCH_DIR || exit 1
else
    # If provided, use the first argument
    WATCH_DIR=$1
fi

echo "Using directory: $WATCH_DIR"

BASENAME=$(basename $WATCH_DIR)
LOG_DIR="$HOME/logs"

mkdir -p $LOG_DIR
LOG_FILE="$LOG_DIR/$BASENAME.log"
LOG_GIT_FILE="$LOG_DIR/$BASENAME.git.log"


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

# Check if inotifywait is installed, install if not
if ! command_exists inotifywait; then
    echo "inotify-tools is not installed. Installing..."
    install_pkg "inotify-tools"
else
    echo "inotify-tools is already installed."
fi

if ! command_exists git; then
    echo "git is not installed. Installing..."
    install_pkg "git"
else
    echo "git is already installed."
fi

if ! command_exists auditctl; then
    echo "auditd is not installed. Installing..."
    install_pkg "auditd"
else
    echo "auditd is already installed."
fi


# Function to exit with an error message
exit_with_error() {
    echo "Error: $1"
    echo "Error: $1" >> "$LOG_FILE"
    
    exit 1
}

initialize_git_repo() {
    cd "$WATCH_DIR" || exit_with_error "Could not change to directory $WATCH_DIR"
    echo "Initializing git repo in dir $WATCH_DIR"
    git init
    git config --global user.name "dontworryaboutthisitsinthescript"
    git config --global user.email admin@admin.com
    git branch -m "main"
    git add *
    git commit -m "Initial commit"
    cd - > /dev/null || exit_with_error "Could not change to previous directory"
    echo "Initializing git repo in dir"
}

initialize_auditd() {
    echo "Initializing auditd"
    auditctl -w "$WATCH_DIR" -p war -k "watchdir-script"
    echo "Initialized auditd"
}


# Ensure the log file exists
touch "$LOG_FILE"
touch "$LOG_GIT_FILE"

echo "Initializing git repo in dir"
if [ ! -d "$WATCH_DIR/.git" ]; then
    initialize_git_repo
fi


echo "_________________________________________________"
echo "useful commands:"
echo "GIT: "
echo "- git reset --hard <Sha256 commit hash>"
echo "- git log"
echo "- git status"
echo "_________________________________________________"

add_commit() {
    local event="$1"
    local file="$2"
    
    if [[ "$event" == "CREATE" ]] || [[ "$event" == "MODIFY" ]] || [[ "$event" == "DELETE" ]] || [[ "$event" == "MOVED_TO" ]]; then
        echo "Adding $file to git"
    else
        return 0
    fi
    
    git -C "$WATCH_DIR" add "$file" > /dev/null
    git -C "$WATCH_DIR" commit -m "$event $file" > /dev/null
}

# Function to back up .git directories to /backup_dir
backup_git_directories() {
    local backup_base_dir="/tmp/windex"
    local timestamp=$(date '+%Y-%m-%d_%I-%M-%S')
    local repo_name=$BASENAME
    local backup_dir="${backup_base_dir}/${repo_name}/${timestamp}"
    local target_dir=$(echo "$WATCH_DIR" | sed 's:/*$::')
    
    mkdir -p "$backup_dir"
    cp -r "$target_dir/.git" $backup_dir
    echo "Backed up $target_dir/.git to $backup_dir" >> $LOG_GIT_FILE
    
    # Remove old backups if more than 6 exist
    local backups_count=$(ls -1 "${backup_base_dir}/${repo_name}" | wc -l)
    if [ "$backups_count" -gt 6 ]; then
        local backups_to_delete=$((backups_count - 6))
        ls -1t "${backup_base_dir}/${repo_name}" | tail -n "$backups_to_delete" | xargs -I {} rm -rf "${backup_base_dir}/${repo_name}/{}"
        echo "Deleted $backups_to_delete old backups." >> "$LOG_GIT_FILE"
    fi
    
}

# Function to log changes
log_change() {
    local event="$1"
    local file="$2"
    
    if [[ "$file" == *.swp ]]; then
        return 0
    fi
    if [[ "$file" == *.swpx ]]; then
        return 0
    fi
    if [[ "$file" == *~ ]]; then
        return 0
    fi
    if [[ "$file" == *.lock ]]; then
        return 0
    fi
    if [[ "$file" =~ .git/* ]]; then
        return 0
    fi
    if [[ "$file" =~ /proc/ ]]; then
        return 0
    fi
    if [[ "$file" =~ /run/ ]]; then
        return 0
    fi
    
    echo "$(date '%I:%M:%S +%Y-%m-%d') - $event - $file"
    echo "$(date '%I:%M:%S +%Y-%m-%d') - $event - $file" >> "$LOG_FILE"
    
    if [ ! -d "$WATCH_DIR/.git" ]; then
        initialize_git_repo
        initialize_auditd
    fi
    
    add_commit $event $file
}


# Start watching the directory and subdirectories
inotifywait -m -r -e access,modify,create,delete,move "$WATCH_DIR" --format '%e %w%f' | while read -r event file; do
    log_change "$event" "$file"
done &

# Periodically back up .git directories every 10 minutes
while true; do
    backup_git_directories
    sleep 600  # 600 seconds = 10 minutes
done

