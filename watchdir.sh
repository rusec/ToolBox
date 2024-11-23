#!/bin/bash

: <<'END'
# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check and install inotify-tools if not present
install_pkg() {
    if command_exists apt-get; then
        sudo apt-get update
        sudo apt-get install -y $1
    elif command_exists dnf; then
        sudo dnf install -y $1
    elif command_exists yum; then
        sudo yum install -y $1
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

END

initizialize_git_repo() {
    cd "$WATCH_DIR" 
    git init
    git config --global user.name "dontworryaboutthisitsinthescript"
    git config --global user.email admin@admin.com
    git branch -m "main"
    git add * 
    git commit -m "Initial commit" 
    cd - > /dev/null
    echo "Initializing git repo in dir"
}

# Check if WATCH_DIR is passed as an argument
if [ -z "$1" ]; then
  # If not provided, prompt the user
  read -p "Dir Path: " WATCH_DIR
else
  # If provided, use the first argument
  WATCH_DIR=$1
fi

echo "Using directory: $WATCH_DIR"

BASENAME=$(basename $WATCH_DIR)
$LOG_DIR= "./logs"

mkdir -p $LOG_DIR
LOG_FILE="$LOG_DIR/$BASENAME.log"
LOG_GIT_FILE="$LOG_DIR/$BASENAME.git.log"

# Ensure the log file exists
touch "$LOG_FILE"
touch "$LOG_GIT_FILE"

echo "Initializing git repo in dir"
if [ ! -d "$WATCH_DIR/.git" ]; then 
   initizialize_git_repo
fi
echo "_________________________________________________"
echo "useful commands:"
echo "- git reset --hard <Sha256 commit hash>"
echo "- git log"
echo "_________________________________________________"

add_commit() {
    local event="$1"
    local file="$2"
    git -C "$WATCH_DIR" add "$file" > /dev/null
    git -C "$WATCH_DIR" commit -m "$event $file" > /dev/null
}
# Function to back up .git directories to /backup_dir
backup_git_directories() {
    local backup_base_dir="/tmp/windex"
    local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local repo_name=$BASENAME
    local backup_dir="${backup_base_dir}/${repo_name}/${timestamp}"
    local target_dir=$(echo "$WATCH_DIR" | sed 's:/*$::')
    mkdir -p "$backup_dir"
    cp -r "$target_dir/.git" $backup_dir
    echo "Backed up $target_dir/.git to $backup_dir" >> $LOG_GIT_FILE
    # Remove old backups if more than 6 exist
    local backups_count=$(ls -1 "${backup_base_dir}/${repo_name}" | wc -l)
    if [ "$backups_count" -gt 10 ]; then
        local backups_to_delete=$((backups_count - 10))
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
    
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $event - $file"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $event - $file" >> "$LOG_FILE"
    
    if [ ! -d "$WATCH_DIR/.git" ]; then 
       initizialize_git_repo
    fi
    add_commit $event $file 
}


# Start watching the directory and subdirectories
inotifywait -m -r -e modify,create,delete,move "$WATCH_DIR" --format '%e %w%f' | while read event file; do
    log_change "$event" "$file"
done & 

# Periodically back up .git directories every 10 minutes
while true; do
    backup_git_directories
    sleep 60  # 600 seconds = 10 minutes
done

