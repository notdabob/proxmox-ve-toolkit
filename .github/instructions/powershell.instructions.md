---
applyTo: ["scripts/**/*.ps1", "scripts/**/*.psm1", "scripts/**/*.psd1"]
---

# PowerShell Cross-Platform Guidelines

## Overview

This file provides general cross-platform guidelines for PowerShell development in the Proxmox VE toolkit.
For specific guidance on scripts, modules, or architecture, refer to the specialized instruction files:

- **Scripts (`.ps1`)**: See `powershell-scripts.instructions.md`
- **Modules (`.psm1`, `.psd1`)**: See `powershell-modules.instructions.md`
- **Architecture & Organization**: See `powershell-architecture.instructions.md`

## Cross-Platform Compatibility Requirements

### PowerShell Version Support

- **Required**: PowerShell 7.0+ for all scripts and modules
- **Testing**: Validate on Windows, macOS, and Linux when possible
- **Syntax**: Use only cross-platform compatible PowerShell features

### Platform Detection

Use built-in platform variables for conditional logic:

```powershell
if ($IsWindows) {
    # Windows-specific code
    $PathSeparator = ";"
    $DefaultEditor = "notepad.exe"
} elseif ($IsMacOS) {
    # macOS-specific code
    $PathSeparator = ":"
    $DefaultEditor = "nano"
} elseif ($IsLinux) {
    # Linux-specific code
    $PathSeparator = ":"
    $DefaultEditor = "nano"
}
```

### File System Operations

Always use PowerShell cmdlets for cross-platform compatibility:

```powershell
# ✅ Cross-platform file operations
$ConfigPath = Join-Path $PSScriptRoot "config.yaml"
$TempDir = [System.IO.Path]::GetTempPath()
$UserHome = [System.Environment]::GetFolderPath("UserProfile")

# ✅ Path handling
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputFile = Join-Path $ScriptDir "output.log"

# ❌ Avoid platform-specific paths
$ConfigPath = "$PSScriptRoot\config.yaml"  # Windows only
$LogFile = "/tmp/app.log"                  # Unix only
```

### Package Manager Integration

Handle different package managers gracefully:

```powershell
function Install-CrossPlatformTool {
    param([string]$ToolName)

    if ($IsWindows) {
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            choco install $ToolName -y
        } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
            scoop install $ToolName
        } else {
            Write-Warning "Please install Chocolatey or Scoop package manager"
        }
    } elseif ($IsMacOS) {
        if (Get-Command brew -ErrorAction SilentlyContinue) {
            brew install $ToolName
        } else {
            Write-Warning "Please install Homebrew package manager"
        }
    } elseif ($IsLinux) {
        if (Get-Command apt-get -ErrorAction SilentlyContinue) {
            sudo apt-get install -y $ToolName
        } elseif (Get-Command yum -ErrorAction SilentlyContinue) {
            sudo yum install -y $ToolName
        } elseif (Get-Command pacman -ErrorAction SilentlyContinue) {
            sudo pacman -S $ToolName
        } else {
            Write-Warning "Unsupported Linux distribution package manager"
        }
    }
}
```

## Environment Configuration

### Node.js/npm Integration

For tools requiring Node.js (like markdownlint):

```powershell
function Test-NodeJsAvailability {
    $npmAvailable = Get-Command npm -ErrorAction SilentlyContinue
    $npxAvailable = Get-Command npx -ErrorAction SilentlyContinue

    if (-not $npmAvailable) {
        Write-Warning "npm not found. Please install Node.js from https://nodejs.org/"
        return $false
    }

    if (-not $npxAvailable) {
        Write-Warning "npx not found. Please update Node.js to a version that includes npx"
        return $false
    }

    return $true
}
```

### PowerShell Module Dependencies

Ensure PowerShell modules are available across platforms:

```powershell
function Install-RequiredModule {
    param([string]$ModuleName, [string]$MinimumVersion = $null)

    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "📦 Installing $ModuleName module..." -ForegroundColor Blue

        # Trust PSGallery if needed
        if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }

        $installParams = @{
            Name = $ModuleName
            Scope = 'CurrentUser'
            Force = $true
            AllowClobber = $true
            Confirm = $false
        }

        if ($MinimumVersion) {
            $installParams.MinimumVersion = $MinimumVersion
        }

        Install-Module @installParams
        Write-Host "✅ $ModuleName installed successfully" -ForegroundColor Green
    }
}
```

## Output and User Experience

### Consistent Output Formatting

Use standard symbols and colors across all scripts:

```powershell
# Status indicators
Write-Host "🚀 Starting process..." -ForegroundColor Cyan
Write-Host "📦 Installing component..." -ForegroundColor Blue
Write-Host "🔍 Checking configuration..." -ForegroundColor Blue
Write-Host "✅ Operation completed successfully" -ForegroundColor Green
Write-Host "⚠️ Warning: Check configuration" -ForegroundColor Yellow
Write-Host "❌ Operation failed" -ForegroundColor Red
Write-Host "ℹ️ Information: Process skipped" -ForegroundColor Gray
```

### Progress Indication

For long-running operations:

```powershell
function Show-Progress {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete
    )

    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
}

# Usage
$steps = @("Step 1", "Step 2", "Step 3")
for ($i = 0; $i -lt $steps.Count; $i++) {
    $percentComplete = [math]::Round(($i / $steps.Count) * 100)
    Show-Progress -Activity "Processing" -Status $steps[$i] -PercentComplete $percentComplete

    # Perform step work
    Start-Sleep -Seconds 1
}
```

## Error Handling Standards

### Consistent Error Handling

```powershell
# Set consistent error behavior
$ErrorActionPreference = "Stop"

function Invoke-SafeOperation {
    param([string]$FilePath)

    try {
        # Validate inputs
        if (-not (Test-Path $FilePath)) {
            throw "File not found: $FilePath"
        }

        # Perform operation
        $result = Get-Content $FilePath
        Write-Host "✅ File processed successfully" -ForegroundColor Green
        return $result
    }
    catch {
        Write-Host "❌ Failed to process file: $($_.Exception.Message)" -ForegroundColor Red
        throw  # Re-throw to maintain error chain
    }
    finally {
        # Cleanup operations
        Write-Progress -Completed
    }
}
```

## Quality Integration

### Automated Quality Checks

This project includes comprehensive quality checking. All PowerShell code should integrate with:

```powershell
# Install all quality tools (no sudo required)
Import-Module ./scripts/powershell/Install-QualityTools.psm1
Install-AllQualityTools

# Run all quality checks
Import-Module ./scripts/powershell/Invoke-QualityChecks.psm1
$allPassed = Invoke-AllQualityChecks -Path "." -ExitOnFailure
```

### Quality Standards Summary

All PowerShell code must:

1. **Pass PSScriptAnalyzer** without warnings
2. **Use cross-platform compatible syntax** only
3. **Include comprehensive help documentation**
4. **Implement proper error handling** with try/catch blocks
5. **Use consistent output formatting** with emojis and colors
6. **Handle dependencies gracefully** with availability checks
7. **Follow established naming conventions** (Verb-Noun patterns)

## Integration Patterns

### Configuration Loading

Standard pattern for YAML configuration loading:

```powershell
function Get-ProjectConfig {
    param([string]$ConfigName = "default")

    $configPath = Join-Path $PSScriptRoot "../../../configs/$ConfigName.yaml"

    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found: $configPath"
    }

    # Use yq if available, fallback to PowerShell-Yaml
    if (Get-Command yq -ErrorAction SilentlyContinue) {
        $yamlContent = & yq eval '.' $configPath | ConvertFrom-Json
    } else {
        Install-RequiredModule -ModuleName "powershell-yaml"
        $yamlContent = Get-Content $configPath -Raw | ConvertFrom-Yaml
    }

    return $yamlContent
}
```

### Module Import Pattern

Consistent module loading across the project:

```powershell
function Import-ProjectModule {
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName,

        [switch]$Force
    )

    $modulePath = Join-Path $PSScriptRoot "../powershell/$ModuleName.psm1"

    if (-not (Test-Path $modulePath)) {
        throw "Module not found: $modulePath"
    }

    Import-Module $modulePath -Force:$Force
    Write-Host "✅ Imported module: $ModuleName" -ForegroundColor Green
}

# Usage
Import-ProjectModule -ModuleName "Install-QualityTools" -Force
Import-ProjectModule -ModuleName "Invoke-QualityChecks"
```

This file focuses on cross-platform compatibility and integration patterns.
Refer to the specialized instruction files for detailed guidance on specific PowerShell file types.
