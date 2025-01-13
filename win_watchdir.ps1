
# Function to check if a command exists
function Command-Exists {
    param([string]$Command)
    Get-Command $Command -ErrorAction SilentlyContinue
}

if (-not (Command-Exists -Command "New-FileSystemWatcher")) {
    # Check and install FSWatcherEngineEvent if not present
    Install-Module -Name FSWatcherEngineEvent
}

if (-not (Command-Exists -Command "git")) {
    # get latest download url for git-for-windows 64-bit exe
    $git_url = "https://api.github.com/repos/git-for-windows/git/releases/latest"
    $asset = Invoke-RestMethod -Method Get -Uri $git_url | % assets | where name -like "*64-bit.exe"
    # download installer
    $installer = "$env:temp\$($asset.name)"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $installer
    # run installer
    $git_install_inf = "<install inf file>"
    $install_args = "/SP- /VERYSILENT /SUPPRESSMSGBOXES /NOCANCEL /NORESTART /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /LOADINF=""$git_install_inf"""
    Start-Process -FilePath $installer -ArgumentList $install_args -Wait
}


foreach($level in "Machine","User") {
   [Environment]::GetEnvironmentVariables($level).GetEnumerator() | % {
      # For Path variables, append the new values, if they're not already in there
      if($_.Name -match 'Path$') { 
         $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select -unique) -join ';'
      }
      $_
   } | Set-Content -Path { "Env:$($_.Name)" }
}
 

# Initialize a Git repository
function Initialize-GitRepo {
    param([string]$Directory)
    Push-Location $Directory
    git init
    git config --global user.name "dontworryaboutthisitsinthescript"
    git config --global user.email "admin@admin.com"
    git branch -m "main"
    git add *
    git commit -m "Initial commit"
    Pop-Location
    Write-Host "Git repository initialized in $Directory."
}

# Get WATCH_DIR from user input or argument
if (-not $args[0]) {
    $WATCH_DIR = Read-Host "Enter directory path: "
} else {
    $WATCH_DIR = $args[0]
}

Write-Host "Using directory: $WATCH_DIR"

# Setup log directories and files
$BASENAME = Split-Path $WATCH_DIR -Leaf
$LOG_DIR = Join-Path -Path "." -ChildPath "logs"
New-Item -ItemType Directory -Force -Path $LOG_DIR #| Out-Null

$LOG_FILE = Join-Path -Path $LOG_DIR -ChildPath "$BASENAME.log"
$LOG_GIT_FILE = Join-Path -Path $LOG_DIR -ChildPath "$BASENAME.git.log"

New-Item -ItemType File -Force -Path $LOG_FILE #| Out-Null
New-Item -ItemType File -Force -Path $LOG_GIT_FILE #| Out-Null

# Initialize Git repo if not already present
if (-not (Test-Path (Join-Path -Path $WATCH_DIR -ChildPath ".git"))) {
    Initialize-GitRepo -Directory $WATCH_DIR
}

# Function to log and commit changes
function Add-Commit {
    param([string]$Event, [string]$File)
    git -C $WATCH_DIR add $File | Out-Null
    git -C $WATCH_DIR commit -m "$Event $File" | Out-Null
}

# Backup .git directories
function Backup-GitDirectories {
    $BackupBaseDir = "/tmp/windex"
    $Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $BackupDir = Join-Path -Path $BackupBaseDir -ChildPath "$BASENAME/$Timestamp"
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    Copy-Item -Recurse -Force -Path (Join-Path -Path $WATCH_DIR -ChildPath ".git") -Destination $BackupDir
    Write-Host "Backed up .git directory to $BackupDir"
    Add-Content -Path $LOG_GIT_FILE -Value "Backed up $WATCH_DIR/.git to $BackupDir"
}

# Function to log changes
function Log-Change {
    param([string]$Event, [string]$File)
    if ($File -match '\.swp$|\.swpx$|~$|\.lock$|\.git|/proc/|/run/') {
        return
    }
    $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Event - $File"
    Write-Host $LogMessage
    Add-Content -Path $LOG_FILE -Value $LogMessage

    if (-not (Test-Path (Join-Path -Path $WATCH_DIR -ChildPath ".git"))) {
        Initialize-GitRepo -Directory $WATCH_DIR
    }
    Add-Commit -Event $Event -File $File
}

# Start watching the directory and subdirectories
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.path = $WATCH_DIR
$watcher.filter = "*.*"
$watcher.IncludeSubdirectories= $true
$watcher.EnableRaisingEvents = $true

$action = { log-change $event.sourceeventargs.changetype $event.sourceeventargs.fullpath }


Register-objectevent $watcher "Created" -Action $action
Register-objectevent $watcher "Changed" -Action $action
Register-objectevent $watcher "Deleted" -Action $action
Register-objectevent $watcher "Renamed" -Action $action



# Periodically back up .git directories
start-job -scriptblock {
    while ($true) {
        Backup-GitDirectories
        Start-Sleep -Seconds 600
    }
}
