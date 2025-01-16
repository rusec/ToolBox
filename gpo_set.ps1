# Import Group Policy module
Import-Module GroupPolicy

# Define variables
$GPOName = "Default Domain Policy"
$GPODescription = "Configured via PowerShell."

# Enable verbose logging for debugging
$VerbosePreference = "Continue"

# Retrieve the Default Domain Policy
$GPO = Get-GPO -Name $GPOName -ErrorAction Stop
Write-Host "Using Default Domain Policy."

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

# Security settings (password, account lockout, Kerberos policies)
$SecTemplate = @"
[System Access]
MinimumPasswordAge = 1
MaximumPasswordAge = 7
MinimumPasswordLength = 25
PasswordComplexity = 1
PasswordHistorySize = 0
LockoutBadCount = 5
ResetLockoutCount = 10
LockoutDuration = 10

[Kerberos Policy]
MaxTicketAge = 1
MaxRenewAge = 7
MaxServiceAge = 600
MaxClockSkew = 5
ForceLogoffWhenHourExpire = 1
"@

$SecTemplatePath = "$env:TEMP\SecurityTemplate.inf"
$SecTemplate | Out-File -FilePath $SecTemplatePath -Encoding ASCII
secedit /configure /db secedit.sdb /cfg $SecTemplatePath /quiet

Write-Host "Security settings applied."

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
        Write-Warning "Error configuring audit policy for $Category"
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

# Generate and display GPO report
$ReportPath = "$env:TEMP\$GPOName.html"
Get-GPOReport -Name $GPOName -ReportType HTML -Path $ReportPath
Write-Host "GPO Report generated: $ReportPath"

# Force a GPUpdate
Invoke-GPUpdate -Force -RandomDelayInMinutes 0
