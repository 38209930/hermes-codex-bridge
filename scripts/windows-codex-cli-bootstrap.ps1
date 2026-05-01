param(
  [string]$Distribution = "Ubuntu",
  [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"

function Write-Step {
  param([string]$Message)
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Command {
  param([string]$Name)
  $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-IsAdministrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Command "wsl.exe")) {
  throw "wsl.exe was not found. Run this on Windows 10/11 with WSL support enabled."
}

if (-not $RepoRoot) {
  $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$wslScriptWindowsPath = Join-Path $RepoRoot "scripts\wsl-install-codex-cli.sh"
if (-not (Test-Path $wslScriptWindowsPath)) {
  throw "Missing WSL install script: $wslScriptWindowsPath"
}

Write-Step "Checking WSL status"
wsl.exe --status

$installedDistros = @(wsl.exe -l -q | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$hasDistribution = $installedDistros -contains $Distribution

if (-not $hasDistribution) {
  if (-not (Test-IsAdministrator)) {
    throw "$Distribution is not installed. Re-run PowerShell as Administrator, then run this script again."
  }

  Write-Step "Installing $Distribution through WSL"
  wsl.exe --install -d $Distribution
  Write-Host ""
  Write-Host "If Windows asks for a reboot, reboot now. Then open $Distribution once to create the Linux user, and rerun this script." -ForegroundColor Yellow
  exit 0
}

Write-Step "Converting script path for WSL"
$wslScriptLinuxPath = (wsl.exe -d $Distribution -- wslpath -a "$wslScriptWindowsPath").Trim()
if (-not $wslScriptLinuxPath) {
  throw "Could not convert script path for WSL."
}

Write-Step "Running Ubuntu installer"
wsl.exe -d $Distribution -- bash "$wslScriptLinuxPath"

Write-Step "Codex CLI smoke test"
wsl.exe -d $Distribution -- bash -lc "export NVM_DIR=`"`$HOME/.nvm`"; [ -s `"`$NVM_DIR/nvm.sh`" ] && . `"`$NVM_DIR/nvm.sh`"; node -v && npm -v && codex --version"

Write-Host ""
Write-Host "Done. Next step: open $Distribution and run 'codex login'." -ForegroundColor Green
