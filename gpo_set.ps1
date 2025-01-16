Import-Module GroupPolicy

# Define domain and GPO details
$DomainName = (Get-ADDomain).DNSRoot
$GPOName = "Custom Group Policy Settings"
$GPODescription = "This GPO is configured by PowerShell to enforce organization-wide security settings."

# Check if the GPO  exists
$ExistingGPO = Get-GPO -Name $GPOName -ErrorAction SilentlyContinue
if (-not $ExistingGPO) {
    $GPO = New-GPO -Name $GPOName -Domain $DomainName -Comment $GPODescription
    Write-Host "New GPO '$GPOName' created successfully."
} else {
    $GPO = $ExistingGPO
    Write-Host "Using existing GPO '$GPOName'."
}

# Settings to configure
$Settings = @(
    @{
        KeyPath = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        ValueName = "NoAutoUpdate"
        ValueType = "DWord"
        ValueData = 1
    },
    @{
        KeyPath = "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
        ValueName = "RestrictNullSessAccess"
        ValueType = "DWord"
        ValueData = 1
    },
    @{
        KeyPath = "HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\DomainProfile"
        ValueName = "EnableFirewall"
        ValueType = "DWord"
        ValueData = 1
    }
)


foreach ($Setting in $Settings) {
    try {
        # Ensure all required keys exist in $Setting
        if (-not ($Setting.KeyPath -and $Setting.ValueName -and $Setting.ValueType -and $Setting.ValueData)) {
            throw "Incomplete setting configuration: $($Setting | Out-String)"
        }

        Set-GPRegistryValue -Name $GPOName -Key $Setting.KeyPath -ValueName $Setting.ValueName -Type $Setting.ValueType -Value $Setting.ValueData
        Write-Host "Configured registry setting: $($Setting.ValueName) at $($Setting.KeyPath)"
    } catch {
        Write-Warning "Failed to configure setting: $($_.Exception.Message)"
    }
}

$OU = "OU=Domain Controllers,DC=RUSEC,DC=org" # CHANGE FOR OU PATH 


try {
    $OUCheck = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OU'"
    if (-not $OUCheck) {
        throw "The specified OU does not exist in Active Directory."
    }

    New-GPLink -Name $GPOName -Target $OU -Enforced $true
    Write-Host "GPO '$GPOName' linked to $OU successfully."
} catch {
    Write-Warning "Failed to link GPO"
}

Write-Host "Group Policy configuration complete."
