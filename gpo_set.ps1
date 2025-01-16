# Import Group Policy module
Import-Module GroupPolicy

# Define variables
$DomainName = (Get-ADDomain).DNSRoot
$GPOName = "Custom Group Policy Settings"
$GPODescription = "Configured via PowerShell."

# Enable verbose logging for debugging
$VerbosePreference = "Continue"

# Create or retrieve the GPO
$GPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if (-not $GPO) {
    $GPO = New-GPO -Name $GPOName -Domain $DomainName -Comment $GPODescription
    Write-Host "GPO '$GPOName' created."
} else {
    Write-Host "Using existing GPO '$GPOName'."
}

# Registry-based settings
$RegistrySettings = @(
    @{ KeyPath = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; ValueName = "NoAutoUpdate"; ValueType = "DWord"; ValueData = 1 },
    @{ KeyPath = "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"; ValueName = "RestrictNullSessAccess"; ValueType = "DWord"; ValueData = 1 },
    @{ KeyPath = "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile"; ValueName = "EnableFirewall"; ValueType = "DWord"; ValueData = 1 }
)
foreach ($Setting in $RegistrySettings) {
    try {
        Set-GPRegistryValue -Name $GPOName -Key $Setting.KeyPath -ValueName $Setting.ValueName -Type $Setting.ValueType -Value $Setting.ValueData
        Write-Host "Configured registry setting: $($Setting.ValueName) at $($Setting.KeyPath)."
    } catch {
        Write-Warning "Error configuring $($Setting.ValueName) at $($Setting.KeyPath): $_"
    }
}

# Password policies (modify Default Domain Policy if needed)
$PasswordPolicies = @(
    @{ Key = "EnforcePasswordHistory"; Value = 0 },
    @{ Key = "MaxPasswordAge"; Value = 7 },
    @{ Key = "MinPasswordAge"; Value = 1 },
    @{ Key = "MinPasswordLength"; Value = 25 },
    @{ Key = "PasswordComplexity"; Value = 1 },
    @{ Key = "ClearTextPassword"; Value = 0 }
)
foreach ($Policy in $PasswordPolicies) {
    try {
        Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName $Policy.Key -Type DWord -Value $Policy.Value
        Write-Host "Configured password policy: $($Policy.Key)."
    } catch {
        Write-Warning "Error configuring password policy $($Policy.Key): $_"
    }
}

# Account lockout policies
$AccountLockoutPolicies = @(
    @{ Key = "LockoutDuration"; Value = 10 },
    @{ Key = "LockoutThreshold"; Value = 5 },
    @{ Key = "ResetLockoutCount"; Value = 10 }
)
foreach ($Policy in $AccountLockoutPolicies) {
    try {
        Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName $Policy.Key -Type DWord -Value $Policy.Value
        Write-Host "Configured account lockout policy: $($Policy.Key)."
    } catch {
        Write-Warning "Error configuring account lockout policy $($Policy.Key): $_"
    }
}

# Kerberos policies
$KerberosPolicies = @(
    @{ Key = "EnforceUserLogonRestrictions"; Value = 1 },
    @{ Key = "MaxLifetimeServiceTicket"; Value = 60 },
    @{ Key = "MaxLifetimeUserTicket"; Value = 60 },
    @{ Key = "MaxLifetimeUserTicketRenewal"; Value = 1000 },
    @{ Key = "MaxClockSyncTolerance"; Value = 5 }
)
foreach ($Policy in $KerberosPolicies) {
    try {
        Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName $Policy.Key -Type DWord -Value $Policy.Value
        Write-Host "Configured Kerberos policy: $($Policy.Key)."
    } catch {
        Write-Warning "Error configuring Kerberos policy $($Policy.Key): $_"
    }
}

# Configure audit policies
$AuditCategories = @(
    "Account Logon", "Account Management", "Directory Service Access",
    "Logon Events", "Object Access", "Policy Change",
    "Privilege Use", "Process Tracking", "System Events"
)
foreach ($Category in $AuditCategories) {
    try {
        Set-GPAuditPolicy -Name $GPOName -AuditCategory $Category -Success $true -Failure $true
        Write-Host "Configured audit policy for category: $Category."
    } catch {
        Write-Warning "Error configuring audit policy for $Category: $_"
    }
}

# Configure user rights assignments
$UserRights = @{
    "Access this computer from the network" = @("Administrators", "Authenticated Users")
    "Allow log on locally" = @("Administrators", "Backup Operators")
    "Allow log on through Remote Desktop Services" = @("Administrators")
}
foreach ($Right in $UserRights.Keys) {
    $Accounts = $UserRights[$Right]
    try {
        Set-GPUserRight -Name $GPOName -PolicyName $Right -Users $Accounts
        Write-Host "Configured user right: $Right."
    } catch {
        Write-Warning "Error configuring user right"
    }
}

# Link the GPO to an OU
$OU = "OU=Domain Controllers,DC=RUSEC,DC=org"
try {
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OU'")) {
        throw "OU not found: $OU"
    }
    New-GPLink -Name $GPOName -Target $OU -Enforced $true
    Write-Host "GPO linked to $OU successfully."
} catch {
    Write-Warning "Error linking GPO"
}

# Generate and display GPO report
$ReportPath = "$env:TEMP\$GPOName.html"
Get-GPOReport -Name $GPOName -ReportType HTML -Path $ReportPath
Write-Host "GPO Report generated: $ReportPath"
