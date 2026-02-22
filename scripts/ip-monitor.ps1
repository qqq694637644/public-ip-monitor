#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Ensure TLS 1.2 on older Windows PowerShell
try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch { }

# ================== CONFIG ==================
# Your local HTTP proxy (China mainland typical setup)
$ProxyUrl = "http://127.0.0.1:10809"

# GitHub repo info (edit these)
$GitHubOwner  = "YOUR_GH_USER"
$GitHubRepo   = "YOUR_REPO"
$GitHubBranch = "main"

# Pages source folder is /docs (方式1)
# These paths are inside the repo:
$DocsIpTxt  = "docs/ip.txt"
$DocsIpJson = "docs/ip.json"

# Local state (stores last seen IP + a simple local history)
$StateDir   = Join-Path $env:ProgramData "PublicIpMonitor"
$LastIpFile = Join-Path $StateDir "last_ip.txt"
$HistoryLog = Join-Path $StateDir "ip_history.log"

# Public IP endpoints (all requests go through proxy). Multiple fallbacks.
$IpEndpoints = @(
  "https://api.ipify.org",
  "https://api64.ipify.org",
  "https://ifconfig.me/ip",
  "https://icanhazip.com",
  "https://ip.sb"
)
# ============================================

function Ensure-Dir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Read-TextIfExists([string]$File) {
  if (Test-Path -LiteralPath $File) {
    return (Get-Content -LiteralPath $File -Raw).Trim()
  }
  return ""
}

function Append-Log([string]$File, [string]$Line) {
  Add-Content -LiteralPath $File -Value $Line
}

function Invoke-RestMethodViaProxy {
  param(
    [Parameter(Mandatory)] [string] $Uri,
    [ValidateSet("Get","Post","Put","Delete","Patch")] [string] $Method = "Get",
    [hashtable] $Headers = $null,
    [int] $TimeoutSec = 20,
    [string] $ContentType = $null,
    $Body = $null
  )

  $params = @{
    Uri        = $Uri
    Method     = $Method
    TimeoutSec = $TimeoutSec
    Proxy      = $ProxyUrl
  }
  if ($Headers)     { $params.Headers = $Headers }
  if ($ContentType) { $params.ContentType = $ContentType }
  if ($Body)        { $params.Body = $Body }

  return Invoke-RestMethod @params
}

function Extract-IpFromText([string]$Text) {
  $t = ($Text | Out-String).Trim()

  # IPv4
  if ($t -match '(\d{1,3}\.){3}\d{1,3}') { return $Matches[0] }

  # IPv6 (loose match)
  if ($t -match '([0-9a-fA-F]{0,4}:){2,}[0-9a-fA-F]{0,4}') { return $Matches[0] }

  return $null
}

function Get-PublicIp {
  foreach ($url in $IpEndpoints) {
    try {
      $resp = Invoke-RestMethodViaProxy -Uri $url -Method Get -TimeoutSec 10
      $ip = Extract-IpFromText ($resp | Out-String)
      if ($ip) { return @{ ip = $ip; source = $url } }
    } catch {
      # ignore and try next
    }
  }
  throw "Failed to fetch public IP from all endpoints via proxy $ProxyUrl"
}

function Get-GitHubHeaders {
  $token = $env:GITHUB_TOKEN
  if ([string]::IsNullOrWhiteSpace($token)) {
    throw "GITHUB_TOKEN environment variable is not set. Run: setx GITHUB_TOKEN ""ghp_..."""
  }
  return @{
    Authorization = "Bearer $token"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "PublicIpMonitor-PowerShell"
  }
}

function GitHub-GetFileSha([string]$Owner, [string]$Repo, [string]$PathInRepo, [string]$Branch) {
  $api = "https://api.github.com/repos/$Owner/$Repo/contents/$PathInRepo?ref=$Branch"
  $headers = Get-GitHubHeaders

  try {
    $resp = Invoke-RestMethodViaProxy -Uri $api -Headers $headers -Method Get -TimeoutSec 20
    return $resp.sha
  } catch {
    return $null  # 404 or other: treat as missing
  }
}

function GitHub-PutFile([string]$Owner, [string]$Repo, [string]$PathInRepo, [string]$Branch, [string]$ContentText, [string]$CommitMessage) {
  $headers = Get-GitHubHeaders
  $sha = GitHub-GetFileSha -Owner $Owner -Repo $Repo -PathInRepo $PathInRepo -Branch $Branch

  $bytes = [System.Text.Encoding]::UTF8.GetBytes($ContentText + "`n")
  $b64   = [Convert]::ToBase64String($bytes)

  $body = @{
    message = $CommitMessage
    content = $b64
    branch  = $Branch
  }
  if ($sha) { $body.sha = $sha }

  $api = "https://api.github.com/repos/$Owner/$Repo/contents/$PathInRepo"
  Invoke-RestMethodViaProxy -Uri $api -Headers $headers -Method Put -Body ($body | ConvertTo-Json -Depth 4) -TimeoutSec 20 | Out-Null
}

# ================== MAIN ==================
Ensure-Dir $StateDir

$now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$result = Get-PublicIp
$newIp = $result.ip
$src  = $result.source

$oldIp = Read-TextIfExists $LastIpFile

if ($newIp -ne $oldIp) {
  Set-Content -LiteralPath $LastIpFile -Value $newIp -Encoding ASCII
  Append-Log -File $HistoryLog -Line "$now $newIp"

  Write-Host "Public IP changed: $oldIp -> $newIp (source: $src)"

  # docs/ip.txt (simple "API")
  $txt = "$newIp"
  GitHub-PutFile -Owner $GitHubOwner -Repo $GitHubRepo -PathInRepo $DocsIpTxt -Branch $GitHubBranch `
    -ContentText $txt -CommitMessage "Update docs/ip.txt: $newIp"

  # docs/ip.json (for web display)
  $obj = @{
    ip = $newIp
    updated_utc = $now
    source = $src
  }
  $json = ($obj | ConvertTo-Json -Depth 4)
  GitHub-PutFile -Owner $GitHubOwner -Repo $GitHubRepo -PathInRepo $DocsIpJson -Branch $GitHubBranch `
    -ContentText $json -CommitMessage "Update docs/ip.json: $newIp"

} else {
  Write-Host "Public IP unchanged: $newIp"
}
