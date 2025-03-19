function Show-Popup {
    param ([string]$message)
    
    Add-Type -TypeDefinition @"
    using System;
    using System.Windows.Forms;
    public class Notification {
        public static void Show(string message) {
            MessageBox.Show(message, "New Service Created", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }
"@
    
    [Notification]::Show($message)
}

# Store existing services
$existingServices = Get-WmiObject -Class Win32_Service | Select-Object -ExpandProperty Name

# Register an event for service creation
Register-WmiEvent -Query "SELECT * FROM __InstanceCreationEvent WITHIN 5 WHERE TargetInstance ISA 'Win32_Service'" `
                  -SourceIdentifier "NewServiceEvent" `
                  -Action {
                      $newService = $Event.SourceEventArgs.NewEvent.TargetInstance
                      $newServiceName = $newService.Name
                      if ($existingServices -notcontains $newServiceName) {
                          $existingServices += $newServiceName
                          Show-Popup -message "A new service has been created: $newServiceName"
                      }
                  }

Write-Host "Monitoring new services and tasks. Press Ctrl+C to stop."
$existingTasks = Get-ScheduledTask | Select-Object -ExpandProperty TaskName

# Keep script running indefinitely
while ($true) { Start-Sleep -Seconds 60 
 # Check for new scheduled tasks
 $currentTasks = Get-ScheduledTask | Select-Object -ExpandProperty TaskName
 $newTasks = $currentTasks | Where-Object { $existingTasks -notcontains $_ }
 
 foreach ($task in $newTasks) {
     $existingTasks += $task
     Show-Popup -message "A new scheduled task has been created: $task"

    }

}

