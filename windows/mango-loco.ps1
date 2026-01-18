<# 
  Check-LegacyWindowsFeatures.ps1
  Purpose: Produce a per-host CSV validating legacy/high-risk Windows features.
  Output schema (one row):
    Hostname,OSVersion,SMBv1Enabled,LLMNREnabled,NTLMv1Allowed,NetBIOSoverTcpipEnabled,
    AutoPlayEnabled,TelnetInstalled,TelnetRunning,MSDTProtocolEnabled,Timestamp
#>

[CmdletBinding()]
param(
  [string]$OutDir = "C:\Reports",
  [switch]$VerboseErrors
)

function Write-Note($msg){ Write-Host "[*] $msg" }

# Ensure output folder
if (-not (Test-Path -LiteralPath $OutDir)) {
  New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$hostName = $env:COMPUTERNAME
try {
  $os = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop)
  $osVersion = "{0} ({1})" -f $os.Caption, $os.Version
} catch {
  $osVersion = [System.Environment]::OSVersion.VersionString
  if ($VerboseErrors) { Write-Warning "OS query fallback used: $($_.Exception.Message)" }
}

# --- Checks ---

# SMBv1 (feature name can be missing on some editions; treat missing as Disabled)
function Test-SMBv1Enabled {
  try {
    $feat = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop
    return ($feat.State -eq 'Enabled' -or $feat.State -eq 'EnablePending')
  } catch {
    # If feature not present, assume disabled
    return $false
  }
}

# LLMNR (0 = disabled by policy; missing means Windows default -> effectively enabled)
function Test-LLMNREnabled {
  try {
    $val = (Get-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Windows NT\DNSClient' -Name 'EnableMulticast' -ErrorAction Stop).EnableMulticast
    return -not ($val -eq 0)
  } catch {
    return $true  # default behavior allows LLMNR
  }
}

# NTLMv1 allowed?  LmCompatibilityLevel >= 5 => NTLMv1 refused  => NOT allowed
function Test-NTLMv1Allowed {
  try {
    $lvl = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'LmCompatibilityLevel' -ErrorAction Stop).LmCompatibilityLevel
    return ($lvl -lt 5)  # True means NTLMv1 MAY be allowed
  } catch {
    # Missing often means older/looser defaults; treat as allowed to be conservative
    return $true
  }
}

# NetBIOS over TCP/IP enabled?  2 = disabled. If ANY NIC is not 2, treat as enabled.
function Test-NetBIOSoverTcpipEnabled {
  try {
    $nics = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True"
    if (-not $nics) { return $false }
    foreach ($n in $nics) {
      # TcpipNetbiosOptions: 0=Default, 1=Enabled, 2=Disabled
      if ($n.TcpipNetbiosOptions -ne 2) { return $true }
    }
    return $false
  } catch {
    if ($VerboseErrors) { Write-Warning "NetBIOS check fallback: $($_.Exception.Message)" }
    return $true
  }
}

# AutoPlay enabled?  NoDriveTypeAutoRun = 255 (0xFF) disables for all drives.
function Test-AutoPlayEnabled {
  try {
    $val = (Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDriveTypeAutoRun' -ErrorAction Stop).NoDriveTypeAutoRun
    return -not ($val -eq 255)
  } catch {
    # Missing means not hardened -> treat as Enabled
    return $true
  }
}

# Telnet service status
function Get-TelnetServiceState {
  try {
    $svc = Get-Service -Name 'Telnet' -ErrorAction Stop
    return @{
      Installed = $true
      Running   = ($svc.Status -eq 'Running')
    }
  } catch {
    return @{
      Installed = $false
      Running   = $false
    }
  }
}

# MSDT protocol handler present? (DogWalk/URL handler surface)
function Test-MSDTProtocolEnabled {
  try {
    return Test-Path 'HKCR:\ms-msdt'
  } catch {
    return $false
  }
}

# --- Evaluate ---
$smb1      = Test-SMBv1Enabled
$llmnr     = Test-LLMNREnabled
$ntlmv1    = Test-NTLMv1Allowed
$netbios   = Test-NetBIOSoverTcpipEnabled
$autoplay  = Test-AutoPlayEnabled
$telnet    = Get-TelnetServiceState
$msdt      = Test-MSDTProtocolEnabled
$timestamp = (Get-Date).ToString('s')  # ISO 8601 (sortable)

$row = [PSCustomObject]@{
  Hostname                 = $hostName
  OSVersion                = $osVersion
  SMBv1Enabled             = [bool]$smb1
  LLMNREnabled             = [bool]$llmnr
  NTLMv1Allowed            = [bool]$ntlmv1
  NetBIOSoverTcpipEnabled  = [bool]$netbios
  AutoPlayEnabled          = [bool]$autoplay
  TelnetInstalled          = [bool]$telnet.Installed
  TelnetRunning            = [bool]$telnet.Running
  MSDTProtocolEnabled      = [bool]$msdt
  Timestamp                = $timestamp
}

$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$outFile = Join-Path $OutDir ("LegacyFeatures-{0}-{1}.csv" -f $hostName,$stamp)
$row | Export-Csv -Path $outFile -NoTypeInformation -Encoding UTF8

Write-Note "Report written to: $outFile"
