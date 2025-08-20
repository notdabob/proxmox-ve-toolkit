# PowerShell Installer Script for Proxmox VE Toolkit

Write-Host "🚀 Starting Proxmox VE Toolkit installation..."

# Import required modules for installation
Import-Module -Force "$(Join-Path $PSScriptRoot 'Invoke-Python.psm1')"
Import-Module -Force "$(Join-Path $PSScriptRoot 'Install-QualityTools.psm1')"

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

function Install-AllComponents {
    <#
    .SYNOPSIS
        Installs all toolkit components and quality tools
    #>
    Write-Host ""
    Write-Host "🔧 Installing toolkit components..."
    
    try {
        # Install quality check tools
        Write-Host ""
        Write-Host "📦 Installing quality check tools..."
        Install-AllQualityTool -Scope CurrentUser
        
        # Install SuperClaude
        Install-SuperClaude
        
        # Test installation
        Write-Host ""
        Write-Host "🧪 Testing installation..."
        Import-Module -Force "$(Join-Path $PSScriptRoot 'Invoke-QualityChecks.psm1')"
        
        # Test that quality tools are working
        if (Test-QualityToolsInstallation) {
            Write-Host "✅ Quality tools installation verified!" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Some quality tools may not be fully installed" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "🎉 Installation completed successfully!"
        Write-Host ""
        
        # Show next steps
        Write-Host "📋 Next Steps:" -ForegroundColor Cyan
        Write-Host "  1. Configure your environment variables in .env file"
        Write-Host "  2. Run quality checks: Import-Module ./scripts/powershell/Invoke-QualityChecks.psm1; Invoke-AllQualityCheck"
        Write-Host "  3. Start developing your Proxmox VE toolkit!"
        Write-Host ""
        
    } catch {
        Write-Error "❌ Installation failed: $($_.Exception.Message)"
        throw
    }
}

# Main installation process
Install-AllComponents
