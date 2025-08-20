# PowerShell Installer Script for AI Code Assist Boilerplate

Write-Host "🚀 Starting full installation..."

# Import the Invoke-Python module for cross-platform Python execution
Import-Module -Force "$(Join-Path $PSScriptRoot 'Invoke-Python.psm1')"

function Install-SuperClaude {
    param(
        [string]$TargetDir = "$env:HOME/.claude",
        [switch]$Update,
        [switch]$DryRun,
        [switch]$Verbose,
        [switch]$Force,
        [string]$LogFile
    )
    Write-Host ""
    Write-Host "--- Installing SuperClaude ---"
    if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
        Write-Host "❌ bash is required but not found in PATH. Please install bash and try again."
        return
    }
    if (-not (Test-Path "SuperClaude")) {
        git clone https://github.com/NomenAK/SuperClaude.git
    }
    $origDir = Get-Location
    Set-Location SuperClaude
    $cmd = "./install.sh"
    if ($TargetDir -ne "$env:HOME/.claude") { $cmd += " --dir '$TargetDir'" }
    if ($Update) { $cmd += " --update" }
    if ($DryRun) { $cmd += " --dry-run" }
    if ($Verbose) { $cmd += " --verbose" }
    if ($Force) { $cmd += " --force" }
    if ($LogFile) { $cmd += " --log '$LogFile'" }
    Write-Host "Running: $cmd"
    bash -c "$cmd"
    Set-Location $origDir
    Write-Host "--- SuperClaude installation complete ---"
}

# --- Easy Button: Run all steps automatically ---
Install-SuperClaude

Write-Host "✅ All installation steps complete!"
