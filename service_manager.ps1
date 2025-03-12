function Show-Popup {
    param (
        [string]$message
    )
    
    Add-Type -TypeDefinition @"
    using System;
    using System.Windows.Forms;
    public class Notification {
        public static void Show(string message) {
            MessageBox.Show(message, "New Service or Task Created", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }
"@
    
    [Notification]::Show($message)
}


$serviceQuery = Get-WmiObject -Class Win32_Service | Select-Object Name
$existingServices = $serviceQuery.Name

$scheduledTaskQuery = Get-ScheduledTask | Select-Object TaskName
$existingTasks = $scheduledTaskQuery.TaskName

$serviceWatcher = New-Object Management.ManagementEventWatcher -ArgumentList "SELECT * FROM __InstanceCreationEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_Service'"
$taskWatcher = New-Object Management.ManagementEventWatcher -ArgumentList "SELECT * FROM __InstanceCreationEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_ScheduledJob'"

$serviceWatcher.EventArrived += {
    $newService = $_.NewEvent.TargetInstance
    $newServiceName = $newService.Name
    if ($existingServices -notcontains $newServiceName) {
        $existingServices += $newServiceName
        Show-Popup -message "A new service has been created: $newServiceName"
    }
}

$taskWatcher.EventArrived += {
    $newTask = $_.NewEvent.TargetInstance
    $newTaskName = $newTask.TaskName
    if ($existingTasks -notcontains $newTaskName) {
        $existingTasks += $newTaskName
        Show-Popup -message "A new scheduled task has been created: $newTaskName"
    }
}

$serviceWatcher.Start()
$taskWatcher.Start()

Write-Host "Monitoring new services and scheduled tasks. Press Ctrl+C to stop."
while ($true) { Start-Sleep -Seconds 60 }
