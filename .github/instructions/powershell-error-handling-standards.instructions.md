---
applyTo: ["scripts/**/*.ps1", "scripts/**/*.psm1", "scripts/**/*.psd1"]
---

# PowerShell Error Handling Standards

## Overview

This file establishes consistent error handling patterns across all PowerShell scripts and modules in the
Proxmox VE toolkit. These standards ensure robust, predictable error behavior and proper user feedback.

## Core Error Handling Principles

### 1. Consistent Error Action Preference

All PowerShell files should set explicit error handling behavior:

```powershell
# At top of all .ps1 scripts and .psm1 modules
$ErrorActionPreference = "Stop"
```

### 2. Structured Try-Catch Patterns

Use specific exception types for predictable error handling:

```powershell
try {
    $result = Invoke-RiskyOperation -Path $ConfigPath
    return $result
}
catch [System.IO.FileNotFoundException] {
    Write-Error "❌ Configuration file not found: $ConfigPath"
    Write-LogMessage -Level Error -Message "Config file missing: $ConfigPath"
    exit 1
}
catch [System.UnauthorizedAccessException] {
    Write-Error "❌ Access denied. Run as administrator or check permissions."
    Write-LogMessage -Level Error -Message "Permission denied accessing: $ConfigPath"
    exit 1
}
catch [System.InvalidOperationException] {
    Write-Error "❌ Invalid operation: $($_.Exception.Message)"
    Write-LogMessage -Level Error -Message "Invalid operation: $($_.Exception.Message)"
    throw  # Re-throw for caller to handle
}
catch {
    Write-Error "❌ Unexpected error: $($_.Exception.Message)"
    Write-LogMessage -Level Error -Message "Unexpected error in $($MyInvocation.MyCommand.Name): $($_.Exception.Message)"
    Write-Debug $_.ScriptStackTrace
    throw  # Re-throw with context preserved
}
finally {
    # Cleanup operations (file handles, connections, etc.)
    if ($fileHandle) { $fileHandle.Close() }
}
```

### 3. Parameter Validation

Use PowerShell parameter validation attributes and custom validation:

```powershell
function Get-ConfigurationData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$ConfigPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Development", "Staging", "Production")]
        [string]$Environment = "Development"
    )

    # Additional custom validation
    if (-not $ConfigPath.EndsWith('.yaml')) {
        throw [System.ArgumentException] "Configuration file must be a YAML file: $ConfigPath"
    }

    # Function implementation...
}
```

## Error Handling by File Type

### Scripts (.ps1)

Scripts should use terminating error handling with exit codes:

```powershell
<# Script header documentation #>

[CmdletBinding()]
param(
    # Parameters with validation
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "🚀 Starting $($MyInvocation.MyCommand.Name)" -ForegroundColor Cyan

    # Validate prerequisites
    Test-Prerequisites

    # Main script operations
    Invoke-MainOperation

    Write-Host "✅ Operation completed successfully" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Debug "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
finally {
    # Cleanup operations
    Write-Progress -Activity "Processing" -Completed
}
```

### Modules (.psm1)

Modules should use non-terminating errors for most operations, allowing callers to handle errors:

```powershell
function Get-ModuleData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        # Validate input
        if (-not (Test-Path $Path)) {
            Write-Error "Path not found: $Path" -Category ObjectNotFound -ErrorAction Stop
        }

        # Operation logic
        $data = Import-Data -Path $Path
        return $data
    }
    catch {
        # Log the error
        Write-LogMessage -Level Error -Message "Failed to get module data: $($_.Exception.Message)"

        # Re-throw for caller to handle
        throw
    }
}

# For utility/helper functions, allow caller to specify error handling
function Invoke-UtilityOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation,

        [Parameter(Mandatory = $false)]
        [switch]$ThrowOnError
    )

    try {
        # Operation logic
        $result = Invoke-Operation $Operation
        return $result
    }
    catch {
        if ($ThrowOnError) {
            throw
        } else {
            Write-Warning "Operation failed: $($_.Exception.Message)"
            return $null
        }
    }
}
```

## Logging Integration

### Consistent Logging Pattern

All error handling should integrate with centralized logging:

```powershell
# Module-level logging function
function Write-LogMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Debug", "Info", "Warning", "Error")]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Include error details if provided
    if ($ErrorRecord) {
        $logEntry += " | Exception: $($ErrorRecord.Exception.Message)"
        if ($Level -eq "Debug") {
            $logEntry += " | Stack: $($ErrorRecord.ScriptStackTrace)"
        }
    }

    # Output to console with colors
    $color = switch ($Level) {
        "Debug" { "Gray" }
        "Info" { "Cyan" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
    }

    Write-Host $logEntry -ForegroundColor $color

    # Write to log file if configured
    if ($script:LogFilePath) {
        Add-Content -Path $script:LogFilePath -Value $logEntry
    }
}

# Usage in error handling
try {
    $result = Invoke-Operation
}
catch {
    Write-LogMessage -Level Error -Message "Operation failed in $($MyInvocation.MyCommand.Name)" -ErrorRecord $_
    throw
}
```

## User-Friendly Error Messages

### Consistent Error Formatting

Use consistent symbols and formatting for user-facing errors:

```powershell
# Error message formatting standards
function Write-UserError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Action,

        [Parameter(Mandatory = $false)]
        [int]$ExitCode = 1
    )

    Write-Host "❌ Error: $Message" -ForegroundColor Red

    if ($Action) {
        Write-Host "💡 Suggested Action: $Action" -ForegroundColor Yellow
    }

    if ($ExitCode -gt 0) {
        exit $ExitCode
    }
}

# Usage examples
Write-UserError -Message "Configuration file not found" -Action "Run setup script first"
Write-UserError -Message "Insufficient permissions" -Action "Run PowerShell as Administrator"
```

### Progressive Error Details

Provide different levels of error detail based on verbosity:

```powershell
function Write-ProgressiveError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserMessage,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory = $false)]
        [string]$SuggestedAction
    )

    # Always show user-friendly message
    Write-Host "❌ $UserMessage" -ForegroundColor Red

    # Show suggested action if provided
    if ($SuggestedAction) {
        Write-Host "💡 $SuggestedAction" -ForegroundColor Yellow
    }

    # Show technical details if verbose
    if ($VerbosePreference -eq "Continue") {
        Write-Host "🔧 Technical Details:" -ForegroundColor Gray
        Write-Host "   Exception: $($ErrorRecord.Exception.GetType().Name)" -ForegroundColor Gray
        Write-Host "   Message: $($ErrorRecord.Exception.Message)" -ForegroundColor Gray
        Write-Host "   Location: $($ErrorRecord.InvocationInfo.ScriptName):$($ErrorRecord.InvocationInfo.ScriptLineNumber)" -ForegroundColor Gray
    }

    # Show stack trace if debug
    if ($DebugPreference -eq "Continue") {
        Write-Host "📋 Stack Trace:" -ForegroundColor DarkGray
        Write-Host $ErrorRecord.ScriptStackTrace -ForegroundColor DarkGray
    }
}
```

## Cross-Platform Error Handling

### Platform-Specific Error Handling

Handle platform differences gracefully:

```powershell
function Install-PlatformTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName
    )

    try {
        if ($IsWindows) {
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                & choco install $ToolName -y
            } else {
                throw [System.NotSupportedException] "Chocolatey package manager required on Windows"
            }
        }
        elseif ($IsMacOS) {
            if (Get-Command brew -ErrorAction SilentlyContinue) {
                & brew install $ToolName
            } else {
                throw [System.NotSupportedException] "Homebrew package manager required on macOS"
            }
        }
        elseif ($IsLinux) {
            if (Get-Command apt-get -ErrorAction SilentlyContinue) {
                & sudo apt-get install -y $ToolName
            } else {
                throw [System.NotSupportedException] "apt package manager required on this Linux distribution"
            }
        }
        else {
            throw [System.PlatformNotSupportedException] "Unsupported operating system"
        }
    }
    catch [System.NotSupportedException] {
        Write-UserError -Message $_.Exception.Message -Action "Install the required package manager or install $ToolName manually"
    }
    catch [System.PlatformNotSupportedException] {
        Write-UserError -Message $_.Exception.Message -Action "Use a supported operating system (Windows, macOS, or Linux)"
    }
    catch {
        Write-UserError -Message "Failed to install $ToolName" -Action "Check your internet connection and package manager configuration"
        Write-LogMessage -Level Error -Message "Tool installation failed" -ErrorRecord $_
        throw
    }
}
```

## Validation and Testing

### Error Handling Validation

Include error handling tests in all modules:

```powershell
# In module tests (using Pester)
Describe "Error Handling" {
    Context "When file not found" {
        It "Should throw FileNotFoundException with descriptive message" {
            { Get-ConfigurationData -ConfigPath "nonexistent.yaml" } |
                Should -Throw -ExceptionType [System.IO.FileNotFoundException]
        }
    }

    Context "When invalid parameters provided" {
        It "Should throw ArgumentException for invalid environment" {
            { Get-ConfigurationData -ConfigPath "config.yaml" -Environment "Invalid" } |
                Should -Throw -ExceptionType [System.ArgumentException]
        }
    }
}
```

### Quality Gate Requirements

All PowerShell code must:

1. **Handle expected exceptions** with specific catch blocks
2. **Provide user-friendly error messages** with actionable guidance
3. **Log errors appropriately** with sufficient detail for debugging
4. **Clean up resources** in finally blocks when applicable
5. **Use consistent error formatting** across all user-facing output
6. **Test error scenarios** with appropriate unit tests

## Integration with Quality Tools

### PSScriptAnalyzer Rules

Ensure compliance with PowerShell best practices:

```powershell
# Suppress only when justified with explanation
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '')]
param()

# Better: Handle the exception appropriately
try {
    $result = Get-OptionalData
}
catch [System.IO.FileNotFoundException] {
    # Expected for optional configuration
    Write-Verbose "Optional configuration file not found, using defaults"
    $result = Get-DefaultData
}
```

### Automated Error Testing

Include automated testing for error scenarios:

```powershell
# Test script for error handling validation
function Test-ErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModulePath
    )

    Import-Module $ModulePath -Force

    $exportedFunctions = Get-Command -Module (Get-Item $ModulePath).BaseName

    foreach ($function in $exportedFunctions) {
        Write-Host "Testing error handling for: $($function.Name)"

        # Test invalid parameters
        try {
            & $function.Name -ErrorAction Stop
            Write-Warning "$($function.Name) did not throw error for missing required parameters"
        }
        catch {
            Write-Host "✅ $($function.Name) properly handles missing parameters"
        }
    }
}
```

This error handling standards file ensures consistent, robust error management across all PowerShell code
in the project while providing clear guidance for both implementation and testing.
