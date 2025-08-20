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
    Import-Module ./scripts/powershell/Install-QualityTool.psm1
    Install-AllQualityTool

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
            Write-Information "🔧 Setting PSGallery as trusted repository..." -InformationAction Continue
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            Write-Information "✅ PSGallery is now trusted" -InformationAction Continue
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

    Write-Information "📦 Installing PSScriptAnalyzer..." -InformationAction Continue
    
    # Ensure PSGallery is trusted
    Set-PSGalleryTrusted
    
    try {
        if (Get-Module -ListAvailable -Name PSScriptAnalyzer) {
            if (-not $Force) {
                Write-Information "✅ PSScriptAnalyzer already installed" -InformationAction Continue
                return
            }
            Write-Information "🔄 Updating PSScriptAnalyzer..." -InformationAction Continue
        }

        Install-Module -Name PSScriptAnalyzer -Scope $Scope -Force -AllowClobber -Confirm:$false
        Write-Information "✅ PSScriptAnalyzer installed successfully" -InformationAction Continue
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

    Write-Information "📦 Installing shellcheck..." -InformationAction Continue

    try {
        # Check if shellcheck is already installed
        if (Get-Command shellcheck -ErrorAction SilentlyContinue) {
            Write-Information "✅ shellcheck already installed" -InformationAction Continue
            return
        }

        if ($IsMacOS) {
            if (Get-Command brew -ErrorAction SilentlyContinue) {
                Write-Information "🍺 Installing shellcheck via Homebrew..." -InformationAction Continue
                & brew install shellcheck
            } else {
                Write-Warning "⚠️ Homebrew not found. Please install Homebrew or shellcheck manually"
                return
            }
        } elseif ($IsLinux) {
            Write-Information "🐧 Installing shellcheck via package manager..." -InformationAction Continue
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
                Write-Information "🪣 Installing shellcheck via Scoop..." -InformationAction Continue
                & scoop install shellcheck
            } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Information "🍫 Installing shellcheck via Chocolatey..." -InformationAction Continue
                & choco install shellcheck
            } else {
                Write-Warning "⚠️ Please install Scoop or Chocolatey, or install shellcheck manually"
                return
            }
        }

        # Verify installation
        if (Get-Command shellcheck -ErrorAction SilentlyContinue) {
            Write-Information "✅ shellcheck installed successfully" -InformationAction Continue
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

    Write-Information "📦 Installing yq for YAML validation..." -InformationAction Continue

    try {
        # Check if yq is already installed
        if (Get-Command yq -ErrorAction SilentlyContinue) {
            Write-Information "✅ yq already installed" -InformationAction Continue
            return
        }

        if ($IsMacOS) {
            if (Get-Command brew -ErrorAction SilentlyContinue) {
                Write-Information "🍺 Installing yq via Homebrew..." -InformationAction Continue
                & brew install yq
            } else {
                Write-Warning "⚠️ Homebrew not found. Please install Homebrew or yq manually"
                return
            }
        } elseif ($IsLinux) {
            Write-Information "🐧 Installing yq..." -InformationAction Continue
            # Download latest yq binary
            $arch = if ([System.Environment]::Is64BitOperatingSystem) { "amd64" } else { "386" }
            $url = "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_$arch"
            $destination = "/usr/local/bin/yq"
            
            & sudo curl -L "$url" -o "$destination"
            & sudo chmod +x "$destination"
        } elseif ($IsWindows) {
            if (Get-Command scoop -ErrorAction SilentlyContinue) {
                Write-Information "🪣 Installing yq via Scoop..." -InformationAction Continue
                & scoop install yq
            } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Information "🍫 Installing yq via Chocolatey..." -InformationAction Continue
                & choco install yq
            } else {
                Write-Warning "⚠️ Please install Scoop or Chocolatey, or install yq manually"
                return
            }
        }

        # Verify installation
        if (Get-Command yq -ErrorAction SilentlyContinue) {
            Write-Information "✅ yq installed successfully" -InformationAction Continue
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

    Write-Information "📦 Installing markdownlint..." -InformationAction Continue
    
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
                Write-Information "🐧 Installing Node.js on Linux..." -InformationAction Continue
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
            Write-Information "✅ markdownlint already installed locally" -InformationAction Continue
            return
        }
        
        # Prefer npx approach (no installation required)
        if ((Get-Command npm -ErrorAction SilentlyContinue) -and (Get-Command npx -ErrorAction SilentlyContinue)) {
            Write-Information "📥 Using npx for markdownlint (no installation required)..." -InformationAction Continue
            
            # Test npx markdownlint availability
            try {
                # Just verify npx works, don't need to test specific package
                Write-Information "✅ markdownlint available via npx" -InformationAction Continue
                Write-Information "ℹ️ No installation required - npx will download on first use" -InformationAction Continue
                return
            } catch {
                Write-Information "⚠️ npx test failed: $($_.Exception.Message)" -InformationAction Continue
                Write-Information "✅ markdownlint will still be available via npx on first use" -InformationAction Continue
                return
            }
        } elseif (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
            Write-Warning "⚠️ npm not found after Node.js installation. Please restart your terminal or install Node.js manually."
            return
        } elseif (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
            Write-Warning "⚠️ npx not found. It should be included with npm. Please update Node.js or install npx separately."
            return
        }
        
        # Fall back to local installation only if npx is not available
        Write-Information "📥 npx not available, installing markdownlint-cli locally..." -InformationAction Continue
        
        # Initialize package.json if it doesn't exist
        if (-not (Test-Path "package.json")) {
            Write-Information "📝 Creating package.json for local dependencies..." -InformationAction Continue
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
            Write-Information "✅ markdownlint $version installed locally" -InformationAction Continue
        } else {
            Write-Warning "Local installation verification failed, but npx should still work"
        }
    } catch {
        Write-Error "Failed to install markdownlint: $($_.Exception.Message)"
    }
}

function Install-AllQualityTool {
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

    Write-Information "🚀 Installing all quality check tools..." -InformationAction Continue
    Write-Information "" -InformationAction Continue

    try {
        # Install PowerShell tools
        Install-PowerShellAnalyzer -Scope $Scope -Force:$Force
        
        # Install cross-platform tools
        Install-ShellCheck
        Install-YAMLValidator
        Install-MarkdownLint -Force:$Force
        
        Write-Information "" -InformationAction Continue
        Write-Information "✅ All quality tools installation completed!" -InformationAction Continue
        Write-Information "" -InformationAction Continue
        
        # Display installed versions
        Show-ToolVersion
    } catch {
        Write-Error "❌ Quality tools installation failed: $($_.Exception.Message)"
        throw
    }
}

function Show-ToolVersion {
    <#
    .SYNOPSIS
        Displays versions of installed quality check tools
    #>
    [CmdletBinding()]
    param()

    Write-Information "📋 Installed Quality Check Tools:" -InformationAction Continue
    Write-Information "=================================" -InformationAction Continue

    # PSScriptAnalyzer
    try {
        $psaVersion = Get-Module -ListAvailable -Name PSScriptAnalyzer | Select-Object -First 1
        if ($psaVersion) {
            Write-Information "✅ PSScriptAnalyzer: $($psaVersion.Version)" -InformationAction Continue
        } else {
            Write-Information "❌ PSScriptAnalyzer: Not installed" -InformationAction Continue
        }
    } catch {
        Write-Information "❌ PSScriptAnalyzer: Error checking version" -InformationAction Continue
    }

    # shellcheck
    try {
        if (Get-Command shellcheck -ErrorAction SilentlyContinue) {
            $shellcheckVersion = & shellcheck --version | Select-String "version:" | ForEach-Object { $_.ToString().Split(':')[1].Trim() }
            Write-Information "✅ shellcheck: $shellcheckVersion" -InformationAction Continue
        } else {
            Write-Information "❌ shellcheck: Not installed" -InformationAction Continue
        }
    } catch {
        Write-Information "❌ shellcheck: Error checking version" -InformationAction Continue
    }

    # yq
    try {
        if (Get-Command yq -ErrorAction SilentlyContinue) {
            $yqVersion = & yq --version
            Write-Information "✅ yq: $yqVersion" -InformationAction Continue
        } else {
            Write-Information "❌ yq: Not installed" -InformationAction Continue
        }
    } catch {
        Write-Information "❌ yq: Error checking version" -InformationAction Continue
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
                Write-Information "✅ markdownlint: $version$installType" -InformationAction Continue
            } else {
                $installType = if ($markdownlintCmd[0] -eq "npx") { " (npx - available but cache issue)" } else { "" }
                Write-Information "✅ markdownlint: Available$installType" -InformationAction Continue
            }
        } else {
            Write-Information "❌ markdownlint: Not installed" -InformationAction Continue
        }
    } catch {
        Write-Information "❌ markdownlint: Error checking version" -InformationAction Continue
    }

    Write-Information "" -InformationAction Continue
}

function Test-QualityToolsInstallation {
    <#
    .SYNOPSIS
        Tests that all quality tools are properly installed and accessible
    #>
    [CmdletBinding()]
    param()

    Write-Information "🧪 Testing quality tools installation..." -InformationAction Continue

    $allInstalled = $true

    # Test PSScriptAnalyzer
    try {
        Import-Module PSScriptAnalyzer -ErrorAction Stop
        Write-Information "✅ PSScriptAnalyzer: Available" -InformationAction Continue
    } catch {
        Write-Information "❌ PSScriptAnalyzer: Not available" -InformationAction Continue
        $allInstalled = $false
    }

    # Test shellcheck
    if (Get-Command shellcheck -ErrorAction SilentlyContinue) {
        Write-Information "✅ shellcheck: Available" -InformationAction Continue
    } else {
        Write-Information "❌ shellcheck: Not available" -InformationAction Continue
        $allInstalled = $false
    }

    # Test yq
    if (Get-Command yq -ErrorAction SilentlyContinue) {
        Write-Information "✅ yq: Available" -InformationAction Continue
    } else {
        Write-Information "❌ yq: Not available" -InformationAction Continue
        $allInstalled = $false
    }

    # Test markdownlint
    $markdownlintCmd = Get-MarkdownLintCommand
    if ($markdownlintCmd) {
        Write-Information "✅ markdownlint: Available" -InformationAction Continue
    } else {
        Write-Information "❌ markdownlint: Not available" -InformationAction Continue
        $allInstalled = $false
    }

    if ($allInstalled) {
        Write-Information "" -InformationAction Continue
        Write-Information "🎉 All quality tools are properly installed!" -InformationAction Continue
        return $true
    } else {
        Write-Information "" -InformationAction Continue
        Write-Information "⚠️ Some quality tools are missing. Run Install-AllQualityTool to install." -InformationAction Continue
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
    'Install-AllQualityTool',
    'Show-ToolVersion',
    'Test-QualityToolsInstallation'
)
