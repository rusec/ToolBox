Write-Output "Log Paths: "$env:SystemRoot"\System32\Winevt\Logs"

$logname = Read-Host "Enter a log file name:"

# Taken from Stack Overflow https://stackoverflow.com/questions/15262196/powershell-tail-windows-event-log-is-it-possible
$idx = (Get-EventLog -LogName $logname -Newest 1).Index

while ($true)
{
  start-sleep -Seconds 1
  $idx2  = (Get-EventLog -LogName System -newest 1).index
  get-eventlog -logname system -newest ($idx2 - $idx) |  sort index
  $idx = $idx2
}
