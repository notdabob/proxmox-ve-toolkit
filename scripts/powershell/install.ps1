# PowerShell Installer Script for Proxmox VE Toolkit

Write-Host "🚀 Starting Proxmox VE Toolkit installation..."

# Import required modules for installation
Import-Module -Force "$(Join-Path $PSScriptRoot 'Invoke-Python.psm1')"
Import-Module -Force "$(Join-Path $PSScriptRoot 'Install-QualityTool.psm1')"

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
