Import-Module GroupPolicy

$GPOName = "Default Domain Policy"
$GPODescription = "Configured via PowerShell."

$VerbosePreference = "Continue"

$GPO = Get-GPO -Name $GPOName -ErrorAction Stop
Write-Host "Using Default Domain Policy."

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

$Domain = "RUSEC.org"

Set-ADDefaultDomainPasswordPolicy -Identity $Domain -MinPasswordLength 25  
Set-ADDefaultDomainPasswordPolicy -Identity $Domain -LockoutDuration 00:10:00 
Set-ADDefaultDomainPasswordPolicy -Identity $Domain -LockoutObservationWindow 20
Set-ADDefaultDomainPasswordPolicy -Identity $Domain -ComplexityEnabled $true 
Set-ADDefaultDomainPasswordPolicy -Identity $Domain -ReversibleEncryptionEnabled $false 
Set-ADDefaultDomainPasswordPolicy -Identity $Domain -MinPasswordAge 1.00:00:00 
Set-ADDefaultDomainPasswordPolicy -Identity $Domain -MaxPasswordAge 7.00:00:00 
Set-ADDefaultDomainPasswordPolicy -Identity $Domain -PasswordHistoryCount 0
Write-Host "Password policies applied."

$AuditCategories = @(
    "Account Logon", "Account Management", "Directory Service Access",
    "Logon Events", "Object Access", "Policy Change",
    "Privilege Use", "Process Tracking", "System Events"
)

Write-Host "Configuring audit policies..."
foreach ($Category in $AuditCategories) {
    try {
        # Set audit policy for the category
        Set-GPAuditPolicy -Name $GPOName -AuditCategory $Category -Success $true -Failure $true
        Write-Host "Configured audit policy for category: $Category."
    } catch {
        Write-Warning "Error configuring audit policy for category: $Category"
    }
}


$UserRights = @{
    "Access this computer from the network"        = @("Administrators", "Authenticated Users")
    "Allow log on locally"                         = @("Administrators", "Backup Operators")
    "Allow log on through Remote Desktop Services" = @("Administrators")
}

Write-Host "Configuring user rights assignments..."
foreach ($Right in $UserRights.Keys) {
    $Accounts = $UserRights[$Right]
    try {
        # Set user rights assignment
        Set-GPUserRight -Name $GPOName -PolicyName $Right -Users $Accounts
        Write-Host "Configured user right: $Right for accounts: $($Accounts -join ', ')."
    } catch {
        Write-Warning "Error configuring user right: $Right"
    }
}

Write-Host "Audit policies and user rights assignments configured"

$ReportPath = "$env:TEMP\$GPOName.html"
Get-GPOReport -Name $GPOName -ReportType HTML -Path $ReportPath
Write-Host "GPO Report generated: $ReportPath"
Invoke-GPUpdate -Force -RandomDelayInMinutes 0
