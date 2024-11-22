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

# Check if WATCH_DIR is passed as an argument
if [ -z "$1" ]; then
  # If not provided, prompt the user
  read -p "Dir Path: " WATCH_DIR
else
  # If provided, use the first argument
  WATCH_DIR=$1
fi

echo "Using directory: $WATCH_DIR"


LOG_FILE="${WATCH_DIR//\//_}.log"
# Ensure the log file exists
touch "$LOG_FILE"

echo "Initializing git repo in dir"
if [ ! -d "$WATCH_DIR/.git" ]; then 
    cd "$WATCH_DIR" 
    git init
    git config --global user.name "dontworryaboutthisitsinthescript"
    git config --global user.email admin@admin.com
    git branch -m "main"
    git add * 
    git commit -m "Initial commit" 
    cd - > /dev/null
fi
echo "_________________________________________________"
echo "useful commands:"
echo "- git reset --hard <Sha256 commit hash>"
echo "- git log"
echo "_________________________________________________"

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
    # dont commit on swp files
    if [[ "$file" != *.swp ]]; then 
        git -C "$WATCH_DIR" add "$file" > /dev/null
        git -C "$WATCH_DIR" commit -m "$event $file" > /dev/null
    fi
}

# Start watching the directory and subdirectories
inotifywait -m -r -e modify,create,delete,move "$WATCH_DIR" --format '%e %w%f' | while read event file; do
    log_change "$event" "$file"
done
