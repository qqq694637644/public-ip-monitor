param(
  [int]$IntervalMinutes = 10,
  [string]$TaskName = "PublicIpMonitor"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# This script should be run from repo root, so scripts/ip-monitor.ps1 exists.
$repoRoot = (Resolve-Path ".").Path
$scriptPath = Join-Path $repoRoot "scripts\ip-monitor.ps1"

if (-not (Test-Path -LiteralPath $scriptPath)) {
  throw "Cannot find $scriptPath. Run this from the repository root."
}

$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration ([TimeSpan]::MaxValue)

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null

Write-Host "Installed scheduled task '$TaskName' to run every $IntervalMinutes minutes."
Write-Host "Tip: ensure your proxy app is running and HTTP proxy $env:HTTP_PROXY (or the configured local port) is reachable."
