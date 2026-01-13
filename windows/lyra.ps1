dnscmd /Config /CacheLockingPercent 100
dnscmd /Config /SocketPoolSize 10000

if (-not $RegPath) {
    $RegPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters'
}

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

$allowedShares = @('C$', 'ADMIN$', 'IPC$')

while ($true) {
    try {
        $smbCfg = Get-SmbServerConfiguration -ErrorAction SilentlyContinue
        if ($smbCfg -and $smbCfg.EnableSMB1Protocol) {
            Set-SmbServerConfiguration -EnableSMB1Protocol $false -Confirm:$false -Force
            Set-SmbServerConfiguration -EnableSMB2Protocol $true -Confirm:$false -Force
            Write-Host "[lyra] Disabled SMBv1 and ensured SMB2+"
        }

        $cur = (Get-ItemProperty -Path $RegPath -Name FullSecureChannelProtection -ErrorAction SilentlyContinue).FullSecureChannelProtection
        if ($cur -ne 1) {
            Set-ItemProperty -Path $RegPath -Name FullSecureChannelProtection -Value 1 -Type DWord -ErrorAction SilentlyContinue
            Write-Host "[lyra] Set FullSecureChannelProtection=1"
        }

        $sambaServiceNames = @('smb', 'smbd', 'samba')
        foreach ($svcName in $sambaServiceNames) {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.Status -ne 'Stopped') { Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue }
                Set-Service -Name $svcName -StartupType Disabled -ErrorAction SilentlyContinue
                Write-Host "[lyra] Stopped and disabled service: $svcName"
            }
        }

        $procNames = @('smbd', 'samba', 'nmbd')
        foreach ($p in $procNames) {
            Get-Process -Name $p -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill(); Write-Host "[lyra] Killed process: $($p)" }
        }
            $forbidden = '(?i)\b(?:Remove-Item|ri|del|erase|rm|Unlink-Item)\b[^\r\n]*\bdns(?:\.exe)?\b'
            if ($inputCommand -and ($inputCommand -match $forbidden)) { 
                Write-Host "[lyra] Blocked attempt to delete dns.exe"; 
                throw "Forbidden operation" 
            }

            $forbiddenUserAdd = '(?i)\b(?:New-LocalUser|Add-LocalUser|New-LocalGroupMember|Add-LocalGroupMember|New-ADUser|Add-ADGroupMember|dsadd\s+user|net\s+user\s+\S+\s+/add)\b'
            if ($inputCommand -and ($inputCommand -match $forbiddenUserAdd)) {
                Write-Host "[lyra] Blocked user-creation attempt: $inputCommand"
                throw "Forbidden operation"
            }

        $shares = Get-SmbShare -ErrorAction SilentlyContinue
        if ($shares) {
            foreach ($sh in $shares) {
                if ($allowedShares -notcontains $sh.Name) {
                    try {
                        Remove-SmbShare -Name $sh.Name -Force -ErrorAction SilentlyContinue
                        Write-Host "[lyra] Removed unauthorized share: $($sh.Name)"
                    } catch {
                        Write-Host "[lyra] Failed to remove share: $($sh.Name) - $($_.Exception.Message)"
                    }
                }
            }
        }
    } catch {
        Write-Host "[lyra] Enforcement loop error: $($_.Exception.Message)"
    }

    Start-Sleep -Seconds 10
}
