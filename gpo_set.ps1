Import-Module GroupPolicy

$DomainName = (Get-ADDomain).DNSRoot
$GPOName = "Custom Group Policy Settings"
$GPODescription = "Configured via PowerShell."

$ExistingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if (-not $ExistingGPO) {
    $GPO = New-GPO -Name $GPOName -Domain $DomainName -Comment $GPODescription
    Write-Host "GPO '$GPOName' created."
} else {
    $GPO = $ExistingGPO
    Write-Host "Using existing GPO '$GPOName'."
}

$Settings = @(
    @{ KeyPath = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"; ValueName = "NoAutoUpdate"; ValueType = "DWord"; ValueData = 1 },
    @{ KeyPath = "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"; ValueName = "RestrictNullSessAccess"; ValueType = "DWord"; ValueData = 1 },
    @{ KeyPath = "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile"; ValueName = "EnableFirewall"; ValueType = "DWord"; ValueData = 1 }
)

foreach ($Setting in $Settings) {
    try {
        Set-GPRegistryValue -Name $GPOName -Key $Setting.KeyPath -ValueName $Setting.ValueName -Type $Setting.ValueType -Value $Setting.ValueData
    } catch {
        Write-Warning "Error configuring $($Setting.ValueName) at $($Setting.KeyPath)"
    }
}

$PasswordPolicies = @(
    @{ Key = "EnforcePasswordHistory"; Value = 0 },
    @{ Key = "MaxPasswordAge"; Value = 7 },
    @{ Key = "MinPasswordAge"; Value = 1 },
    @{ Key = "MinPasswordLength"; Value = 25 },
    @{ Key = "PasswordComplexity"; Value = 1 },
    @{ Key = "ClearTextPassword"; Value = 0 }
)
foreach ($Policy in $PasswordPolicies) {
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName $Policy.Key -Type DWord -Value $Policy.Value
}

$AccountLockoutPolicies = @(
    @{ Key = "LockoutDuration"; Value = 10 },
    @{ Key = "LockoutThreshold"; Value = 5 },
    @{ Key = "ResetLockoutCount"; Value = 10 }
)
foreach ($Policy in $AccountLockoutPolicies) {
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName $Policy.Key -Type DWord -Value $Policy.Value
}

$KerberosPolicies = @(
    @{ Key = "EnforceUserLogonRestrictions"; Value = 1 },
    @{ Key = "MaxLifetimeServiceTicket"; Value = 60 },
    @{ Key = "MaxLifetimeUserTicket"; Value = 60 },
    @{ Key = "MaxLifetimeUserTicketRenewal"; Value = 1440 },
    @{ Key = "MaxClockSyncTolerance"; Value = 5 }
)
foreach ($Policy in $KerberosPolicies) {
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -ValueName $Policy.Key -Type DWord -Value $Policy.Value
}

$AuditCategories = @(
    "Account Logon", "Account Management", "Directory Service Access",
    "Logon Events", "Object Access", "Policy Change",
    "Privilege Use", "Process Tracking", "System Events"
)
foreach ($Category in $AuditCategories) {
    Set-GPAuditPolicy -Name $GPOName -AuditCategory $Category -Success $true -Failure $false
}

$UserRights = @{
    "Access this computer from the network" = @("Administrators", "Authenticated Users")
    "Add workstations to domain" = @("Administrators")
    "Allow log on locally" = @("Administrators", "Backup Operators")
    "Allow log on through Remote Desktop Services" = @("Administrators")
    "Back up files and directories" = @("Administrators", "Backup Operators")
    "Deny access to this computer from the network" = @("Guests", "Local Account", "Local Service")
    "Deny log on locally" = @("Guests")
}
foreach ($Right in $UserRights.Keys) {
    $Accounts = $UserRights[$Right]
    try {
        Set-GPUserRight -Name $GPOName -PolicyName $Right -Users $Accounts
    } catch {
        Write-Warning "Error configuring $Right"
    }
}

$OU = "OU=Domain Controllers,DC=RUSEC,DC=org"
try {
    $OUCheck = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OU'"
    if (-not $OUCheck) { throw "OU not found." }
    New-GPLink -Name $GPOName -Target $OU -Enforced $true
    Write-Host "GPO linked to $OU."
} catch {
    Write-Warning "Error linking GPO"
}
