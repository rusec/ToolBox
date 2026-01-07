dnscmd /Config /CacheLockingPercent 100
dnscmd /Config /SocketPoolSize 10000

if ((Get-SmbServerConfiguration).EnableSMB1Protocol -eq $true) {
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Confirm:$false -Force
    Set-SMBServerConfiguration -EnableSMB2Protocol $true -Confirm:$false -Force
    Write-Host "v1 -> v2"
} else {
    Write-Host ":)"
}

Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol
Get-DomainUser -PreauthNotRequired | Set-DomainUser -PreauthNotRequired $false
Get-ADUSer -Filter 'DoesNotRequirePreAuth -eq $true'
Set-ADAccountControl -DoesNotRequirePreAuth $false

$CurrentValue = (Get-ItemProperty -Path $RegPath -Name FullSecureChannelProtection -ErrorAction SilentlyContinue).FullSecureChannelProtection

if ($CurrentValue -ne 1) {
    Set-ItemProperty -Path $RegPath -Name FullSecureChannelProtection -Value 1 -Type DWord
} 

if (Get-ItemProperty -Path $RegPath -Name AllowList -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $RegPath -Name AllowList
} else {
    Write-Host "no allowlist present"
}

Restart-Service Netlogon -Force

$PostCheck = (Get-ItemProperty -Path $RegPath -Name FullSecureChannelProtection).FullSecureChannelProtection

if ($PostCheck -eq 1) {
    Write-Host "Success"
} else {
    Write-Error "Failed"
}

Write-Host "Latest NLO Events:"
Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    Id = 5827,5828,5829
} -MaxEvents 10 | Format-Table TimeCreated, Id, Message -AutoSize