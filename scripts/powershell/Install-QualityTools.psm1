<#
.SYNOPSIS
    Cross-platform quality tools installer for PowerShell and shell script projects

.DESCRIPTION
    Automatically installs and configures code quality tools including:
    - PSScriptAnalyzer for PowerShell linting
    - shellcheck for shell script validation
    - yq for YAML validation
    - Additional quality check dependencies

.EXAMPLE
    Import-Module ./scripts/powershell/Install-QualityTools.psm1
    Install-AllQualityTools

.EXAMPLE
    Install-PowerShellAnalyzer -Force
    Install-ShellCheck -Scope CurrentUser
#>

# Set consistent error handling
$ErrorActionPreference = "Stop"

function Set-PSGalleryTrusted {
    <#
    .SYNOPSIS
        Sets PSGallery as a trusted repository to avoid installation prompts
    #>
    [CmdletBinding()]
    param()
    
    try {
        $psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if ($psGallery -and $psGallery.InstallationPolicy -ne 'Trusted') {
            Write-Host "🔧 Setting PSGallery as trusted repository..." -ForegroundColor Yellow
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            Write-Host "✅ PSGallery is now trusted" -ForegroundColor Green
        }
    } catch {
        Write-Warning "⚠️ Could not set PSGallery trust policy: $($_.Exception.Message)"
    }
}

function Install-PowerShellAnalyzer {
    <#
    .SYNOPSIS
        Installs PSScriptAnalyzer module for PowerShell linting

    .PARAMETER Scope
        Installation scope: CurrentUser or AllUsers

    .PARAMETER Force
        Force reinstallation if already installed
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("CurrentUser", "AllUsers")]
        [string]$Scope = "CurrentUser",
        
        [switch]$Force
    )

    Write-Host "📦 Installing PSScriptAnalyzer..." -ForegroundColor Blue
    
    # Ensure PSGallery is trusted
    Set-PSGalleryTrusted
    
    try {
        if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
            if (-not $Force) {
                Write-Host "✅ PSScriptAnalyzer already installed" -ForegroundColor Green
                return
            }
            Write-Host "🔄 Updating PSScriptAnalyzer..." -ForegroundColor Yellow
        }

        Install-Module -Name PSScriptAnalyzer -Scope $Scope -Force -AllowClobber -Confirm:$false
        Write-Host "✅ PSScriptAnalyzer installed successfully" -ForegroundColor Green
    } catch {
        Write-Error "❌ Failed to install PSScriptAnalyzer: $($_.Exception.Message)"
        throw
    }
}

function Install-ShellCheck {
    <#
    .SYNOPSIS
        Installs shellcheck for shell script validation
    #>
    [CmdletBinding()]
    param()

    Write-Host "📦 Installing shellcheck..." -ForegroundColor Blue

    try {
        # Check if shellcheck is already installed
        if (Get-Command shellcheck -ErrorAction SilentlyContinue) {
            Write-Host "✅ shellcheck already installed" -ForegroundColor Green
            return
        }

        if ($IsMacOS) {
            if (Get-Command brew -ErrorAction SilentlyContinue) {
                Write-Host "🍺 Installing shellcheck via Homebrew..."
                & brew install shellcheck
            } else {
                Write-Warning "⚠️ Homebrew not found. Please install Homebrew or shellcheck manually"
                return
            }
        } elseif ($IsLinux) {
            Write-Host "🐧 Installing shellcheck via package manager..."
            if (Get-Command apt-get -ErrorAction SilentlyContinue) {
                & sudo apt-get update
                & sudo apt-get install -y shellcheck
            } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
                & sudo yum install -y ShellCheck
            } elseif (Get-Command dnf -ErrorAction SilentlyContinue) {
                & sudo dnf install -y ShellCheck
            } else {
                Write-Warning "⚠️ Package manager not recognized. Please install shellcheck manually"
                return
            }
        } elseif ($IsWindows) {
            if (Get-Command scoop -ErrorAction SilentlyContinue) {
                Write-Host "🪣 Installing shellcheck via Scoop..."
                & scoop install shellcheck
            } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Host "🍫 Installing shellcheck via Chocolatey..."
                & choco install shellcheck
            } else {
                Write-Warning "⚠️ Please install Scoop or Chocolatey, or install shellcheck manually"
                return
            }
        }

        # Verify installation
        if (Get-Command shellcheck -ErrorAction SilentlyContinue) {
            Write-Host "✅ shellcheck installed successfully" -ForegroundColor Green
        } else {
            Write-Error "❌ shellcheck installation failed"
        }
    } catch {
        Write-Error "❌ Failed to install shellcheck: $($_.Exception.Message)"
        throw
    }
}

function Install-YAMLValidator {
    <#
    .SYNOPSIS
        Installs yq for YAML validation and processing
    #>
    [CmdletBinding()]
    param()

    Write-Host "📦 Installing yq for YAML validation..." -ForegroundColor Blue

    try {
        # Check if yq is already installed
        if (Get-Command yq -ErrorAction SilentlyContinue) {
            Write-Host "✅ yq already installed" -ForegroundColor Green
            return
        }

        if ($IsMacOS) {
            if (Get-Command brew -ErrorAction SilentlyContinue) {
                Write-Host "🍺 Installing yq via Homebrew..."
                & brew install yq
            } else {
                Write-Warning "⚠️ Homebrew not found. Please install Homebrew or yq manually"
                return
            }
        } elseif ($IsLinux) {
            Write-Host "🐧 Installing yq..."
            # Download latest yq binary
            $arch = if ([System.Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
            $url = "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$arch"
            $destination = "/usr/local/bin/yq"
            
            & sudo curl -L "$url" -o "$destination"
            & sudo chmod +x "$destination"
        } elseif ($IsWindows) {
            if (Get-Command scoop -ErrorAction SilentlyContinue) {
                Write-Host "🪣 Installing yq via Scoop..."
                & scoop install yq
            } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Host "🍫 Installing yq via Chocolatey..."
                & choco install yq
            } else {
                Write-Warning "⚠️ Please install Scoop or Chocolatey, or install yq manually"
                return
            }
        }

        # Verify installation
        if (Get-Command yq -ErrorAction SilentlyContinue) {
            Write-Host "✅ yq installed successfully" -ForegroundColor Green
        } else {
            Write-Error "❌ yq installation failed"
        }
    } catch {
        Write-Error "❌ Failed to install yq: $($_.Exception.Message)"
        throw
    }
}

function Install-MarkdownLint {
    <#
    .SYNOPSIS
        Installs markdownlint for markdown file validation

    .PARAMETER Force
        Force reinstallation if already installed
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    Write-Host "📦 Installing markdownlint..." -ForegroundColor Blue
    
    try {
        # Check if npm is available
        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
            Write-Warning "npm not found. Installing Node.js first..."
            
            if ($IsWindows) {
                # Try chocolatey first, then manual install
                if (Get-Command choco -ErrorAction SilentlyContinue) {
                    choco install nodejs -y
                } else {
                    Write-Error "Please install Node.js manually from https://nodejs.org/"
                    return
                }
            } elseif ($IsMacOS) {
                # Try homebrew first
                if (Get-Command brew -ErrorAction SilentlyContinue) {
                    brew install node
                } else {
                    Write-Error "Please install Node.js manually from https://nodejs.org/ or install Homebrew"
                    return
                }
            } else {
                # Linux
                Write-Host "🐧 Installing Node.js on Linux..." -ForegroundColor Yellow
                if (Get-Command apt-get -ErrorAction SilentlyContinue) {
                    sudo apt-get update && sudo apt-get install -y nodejs npm
                } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
                    sudo yum install -y nodejs npm
                } elseif (Get-Command pacman -ErrorAction SilentlyContinue) {
                    sudo pacman -S nodejs npm
                } else {
                    Write-Error "Please install Node.js manually for your Linux distribution"
                    return
                }
            }
        }

        # Check if we have a local installation
        $projectRoot = Get-Location
        $localMarkdownlint = Join-Path $projectRoot "node_modules/.bin/markdownlint"
        
        if ((Test-Path $localMarkdownlint) -and -not $Force) {
            Write-Host "✅ markdownlint already installed locally" -ForegroundColor Green
            return
        }
        
        # Prefer npx approach (no installation required)
        if (Get-Command npx -ErrorAction SilentlyContinue) {
            Write-Host "📥 Using npx for markdownlint (no installation required)..." -ForegroundColor Yellow
            
            # Test npx markdownlint
            try {
                $testOutput = npx --yes markdownlint-cli --version 2>$null
                if ($testOutput) {
                    Write-Host "✅ markdownlint available via npx: $testOutput" -ForegroundColor Green
                    Write-Host "ℹ️ No installation required - npx will download on first use" -ForegroundColor Blue
                    return
                } else {
                    Write-Host "⚠️ npx test returned empty, but npx is available" -ForegroundColor Yellow
                    Write-Host "✅ markdownlint will be available via npx on first use" -ForegroundColor Green
                    return
                }
            } catch {
                Write-Host "⚠️ npx test failed: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "✅ markdownlint will still be available via npx on first use" -ForegroundColor Green
                return
            }
        }
        
        # Fall back to local installation only if npx is not available
        Write-Host "📥 npx not available, installing markdownlint-cli locally..." -ForegroundColor Yellow
        
        # Initialize package.json if it doesn't exist
        if (-not (Test-Path "package.json")) {
            Write-Host "📝 Creating package.json for local dependencies..." -ForegroundColor Blue
            npm init -y | Out-Null
        }
        
        # Try local installation with npm cache fix
        try {
            npm install markdownlint-cli --save-dev --no-fund --no-audit
        } catch {
            Write-Warning "Local installation failed. Markdownlint may still work via npx."
            return
        }
        
        # Verify local installation
        if (Test-Path $localMarkdownlint) {
            $version = & $localMarkdownlint --version
            Write-Host "✅ markdownlint $version installed locally" -ForegroundColor Green
        } else {
            Write-Warning "Local installation verification failed, but npx should still work"
        }
    } catch {
        Write-Error "Failed to install markdownlint: $($_.Exception.Message)"
    }
}

function Install-AllQualityTools {
    <#
    .SYNOPSIS
        Installs all quality check tools

    .PARAMETER Scope
        PowerShell module installation scope

    .PARAMETER Force
        Force reinstallation of all tools
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("CurrentUser", "AllUsers")]
        [string]$Scope = "CurrentUser",
        
        [switch]$Force
    )

    Write-Host "🚀 Installing all quality check tools..." -ForegroundColor Cyan
    Write-Host ""

    try {
        # Install PowerShell tools
        Install-PowerShellAnalyzer -Scope $Scope -Force:$Force
        
        # Install cross-platform tools
        Install-ShellCheck
        Install-YAMLValidator
        Install-MarkdownLint -Force:$Force
        
        Write-Host ""
        Write-Host "✅ All quality tools installation completed!" -ForegroundColor Green
        Write-Host ""
        
        # Display installed versions
        Show-ToolVersions
    } catch {
        Write-Error "❌ Quality tools installation failed: $($_.Exception.Message)"
        throw
    }
}

function Show-ToolVersions {
    <#
    .SYNOPSIS
        Displays versions of installed quality check tools
    #>
    [CmdletBinding()]
    param()

    Write-Host "📋 Installed Quality Check Tools:" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan

    # PSScriptAnalyzer
    try {
        $psaVersion = Get-Module -ListAvailable -Name PSScriptAnalyzer | Select-Object -First 1
        if ($psaVersion) {
            Write-Host "✅ PSScriptAnalyzer: $($psaVersion.Version)" -ForegroundColor Green
        } else {
            Write-Host "❌ PSScriptAnalyzer: Not installed" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ PSScriptAnalyzer: Error checking version" -ForegroundColor Red
    }

    # shellcheck
    try {
        if (Get-Command shellcheck -ErrorAction SilentlyContinue) {
            $shellcheckVersion = & shellcheck --version | Select-String "version:" | ForEach-Object { $_.ToString().Split(':')[1].Trim() }
            Write-Host "✅ shellcheck: $shellcheckVersion" -ForegroundColor Green
        } else {
            Write-Host "❌ shellcheck: Not installed" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ shellcheck: Error checking version" -ForegroundColor Red
    }

    # yq
    try {
        if (Get-Command yq -ErrorAction SilentlyContinue) {
            $yqVersion = & yq --version
            Write-Host "✅ yq: $yqVersion" -ForegroundColor Green
        } else {
            Write-Host "❌ yq: Not installed" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ yq: Error checking version" -ForegroundColor Red
    }

    # markdownlint
    try {
        $markdownlintCmd = Get-MarkdownLintCommand
        if ($markdownlintCmd) {
            try {
                $version = if ($markdownlintCmd.Count -gt 1) {
                    # Handle npx case - suppress error output
                    & $markdownlintCmd[0] $markdownlintCmd[1] $markdownlintCmd[2] --version 2>$null
                } else {
                    # Handle local or global case
                    & $markdownlintCmd[0] --version 2>$null
                }
            } catch {
                $version = $null
            }
            
            if ($version -and $LASTEXITCODE -eq 0) {
                $installType = if ($markdownlintCmd[0] -like "*node_modules*") { " (local)" } 
                elseif ($markdownlintCmd[0] -eq "npx") { " (npx)" } 
                else { " (global)" }
                Write-Host "✅ markdownlint: $version$installType" -ForegroundColor Green
            } else {
                $installType = if ($markdownlintCmd[0] -eq "npx") { " (npx - available but cache issue)" } else { "" }
                Write-Host "✅ markdownlint: Available$installType" -ForegroundColor Green
            }
        } else {
            Write-Host "❌ markdownlint: Not installed" -ForegroundColor Red
        }
    } catch {
        Write-Host "❌ markdownlint: Error checking version" -ForegroundColor Red
    }

    Write-Host ""
}

function Test-QualityToolsInstallation {
    <#
    .SYNOPSIS
        Tests that all quality tools are properly installed and accessible
    #>
    [CmdletBinding()]
    param()

    Write-Host "🧪 Testing quality tools installation..." -ForegroundColor Cyan

    $allInstalled = $true

    # Test PSScriptAnalyzer
    try {
        Import-Module PSScriptAnalyzer -ErrorAction Stop
        Write-Host "✅ PSScriptAnalyzer: Available" -ForegroundColor Green
    } catch {
        Write-Host "❌ PSScriptAnalyzer: Not available" -ForegroundColor Red
        $allInstalled = $false
    }

    # Test shellcheck
    if (Get-Command shellcheck -ErrorAction SilentlyContinue) {
        Write-Host "✅ shellcheck: Available" -ForegroundColor Green
    } else {
        Write-Host "❌ shellcheck: Not available" -ForegroundColor Red
        $allInstalled = $false
    }

    # Test yq
    if (Get-Command yq -ErrorAction SilentlyContinue) {
        Write-Host "✅ yq: Available" -ForegroundColor Green
    } else {
        Write-Host "❌ yq: Not available" -ForegroundColor Red
        $allInstalled = $false
    }

    # Test markdownlint
    $markdownlintCmd = Get-MarkdownLintCommand
    if ($markdownlintCmd) {
        Write-Host "✅ markdownlint: Available" -ForegroundColor Green
    } else {
        Write-Host "❌ markdownlint: Not available" -ForegroundColor Red
        $allInstalled = $false
    }

    if ($allInstalled) {
        Write-Host ""
        Write-Host "🎉 All quality tools are properly installed!" -ForegroundColor Green
        return $true
    } else {
        Write-Host ""
        Write-Host "⚠️ Some quality tools are missing. Run Install-AllQualityTools to install." -ForegroundColor Yellow
        return $false
    }
}

function Get-MarkdownLintCommand {
    <#
    .SYNOPSIS
        Gets the appropriate markdownlint command (local, npx, or global)
    #>
    [CmdletBinding()]
    param()
    
    # Check for local installation first
    $projectRoot = Get-Location
    $localMarkdownlint = Join-Path $projectRoot "node_modules/.bin/markdownlint"
    
    if (Test-Path $localMarkdownlint) {
        return @($localMarkdownlint)
    }
    
    # Check if we can use npx (preferred for no-install approach)
    if (Get-Command npx -ErrorAction SilentlyContinue) {
        return @("npx", "--yes", "markdownlint-cli")
    }
    
    # Fall back to global installation
    if (Get-Command markdownlint -ErrorAction SilentlyContinue) {
        return @("markdownlint")
    }
    
    return $null
}

# Export functions
Export-ModuleMember -Function @(
    'Get-MarkdownLintCommand',
    'Set-PSGalleryTrusted',
    'Install-PowerShellAnalyzer',
    'Install-ShellCheck', 
    'Install-YAMLValidator',
    'Install-MarkdownLint',
    'Install-AllQualityTools',
    'Show-ToolVersions',
    'Test-QualityToolsInstallation'
)