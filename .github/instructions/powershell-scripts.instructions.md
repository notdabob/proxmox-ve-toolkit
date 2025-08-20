---
applyTo: ["scripts/**/*.ps1"]
---

# PowerShell Scripts Instructions

## Overview

This file provides specific guidance for standalone PowerShell script files (`.ps1`). These are typically
executables, installers, utilities, or cmdlets that perform specific tasks.

## Script Standards

### Script Header Requirements

Every `.ps1` script MUST include a comprehensive header following the unified PowerShell documentation
standards. See `powershell-documentation-standards.instructions.md` for complete requirements.

**Quick Reference - All sections are mandatory:**

```powershell
<#
.SYNOPSIS
    A brief, one-line summary of the script's purpose.

.DESCRIPTION
    A detailed description of the script's functionality, purpose, and behavior.
    Explain what the script accomplishes, any prerequisites not covered in .NOTES,
    and important usage considerations.

.PARAMETER ParameterName
    Description of each parameter, including its type, purpose, and valid values.
    This section should be repeated for each parameter.

.EXAMPLE
    PS C:\> .\ScriptName.ps1 -Parameter "value"
    Description of what this example achieves.

.EXAMPLE
    PS C:\> .\ScriptName.ps1 -Parameter "value" -AnotherParam
    A second example demonstrating different usage or parameters.

.OUTPUTS
    System.String
    Description of the objects that the script returns to the pipeline. If the
    script does not return any output, specify "None".

.NOTES
    File Name      : ScriptName.ps1
    Author         : [Author Name]
    Prerequisite   : PowerShell 7.0+, Posh-SSH Module
    Copyright      : [Copyright Info]
    Additional notes, known issues, or other relevant information.

.LINK
    https://github.com/your-repo/docs/path/to/relevant/doc.md
#/>
```

### Parameter Declaration

Use consistent parameter patterns for all scripts:

```powershell
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Primary input parameter")]
    [ValidateNotNullOrEmpty()]
    [string]$InputValue,

    [Parameter(Mandatory = $false, HelpMessage = "Optional configuration parameter")]
    [ValidateSet("Option1", "Option2", "Option3")]
    [string]$Mode = "Option1",

    [Parameter(Mandatory = $false, HelpMessage = "Enable verbose output")]
    [switch]$Verbose,

    [Parameter(Mandatory = $false, HelpMessage = "Perform dry run without making changes")]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false, HelpMessage = "Force operation without confirmation")]
    [switch]$Force
)
```

### Script Structure Pattern

Follow this consistent structure for all scripts:

```powershell
<# Header documentation here #>

[CmdletBinding(SupportsShouldProcess)]
param(
    # Parameters here
)

# Set error handling
$ErrorActionPreference = "Stop"

# Script-level variables and constants
$ScriptName = $MyInvocation.MyCommand.Name
$ScriptPath = $PSScriptRoot
$LogPath = Join-Path $ScriptPath "logs"

# Helper functions (if needed)
function Write-ScriptLog {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $(
        switch ($Level) {
            "Error" { "Red" }
            "Warning" { "Yellow" }
            "Success" { "Green" }
            "Info" { "Cyan" }
            default { "White" }
        }
    )
}

# Main execution block
try {
    Write-ScriptLog "🚀 Starting $ScriptName" "Info"

    # Validate prerequisites
    if (-not $Force) {
        # Add confirmation prompts for destructive operations
    }

    # Main script logic here

    Write-ScriptLog "✅ $ScriptName completed successfully" "Success"
}
catch {
    Write-ScriptLog "❌ $ScriptName failed: $($_.Exception.Message)" "Error"
    exit 1
}
finally {
    # Cleanup operations if needed
}
```

## Script Types and Patterns

### Installation Scripts

For installation and setup scripts:

```powershell
<#
.SYNOPSIS
    Installs and configures [component name]
#/>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$InstallPath = "$env:USERPROFILE\.toolname",

    [Parameter(Mandatory = $false)]
    [switch]$Update,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Test-Prerequisites {
    # Check for required dependencies
    $missing = @()

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $missing += "git"
    }

    if ($missing.Count -gt 0) {
        throw "Missing prerequisites: $($missing -join ', ')"
    }
}

function Install-Component {
    param([string]$Path)

    Write-Host "📦 Installing to: $Path" -ForegroundColor Blue

    if (Test-Path $Path -and -not $Force) {
        if ($Update) {
            Write-Host "🔄 Updating existing installation..." -ForegroundColor Yellow
        } else {
            throw "Installation path already exists. Use -Update or -Force"
        }
    }

    # Installation logic here

    Write-Host "✅ Installation completed" -ForegroundColor Green
}

try {
    Write-Host "🚀 Starting installation..." -ForegroundColor Cyan

    Test-Prerequisites
    Install-Component -Path $InstallPath

    Write-Host "🎉 Setup completed successfully!" -ForegroundColor Green
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Configure your settings"
    Write-Host "  2. Run initial setup"
}
catch {
    Write-Error "❌ Installation failed: $($_.Exception.Message)"
    exit 1
}
```

### Utility Scripts

For utility and helper scripts:

```powershell
<#
.SYNOPSIS
    Utility script for [specific task]
#/>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string[]]$InputItems,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$Recurse
)

begin {
    $ErrorActionPreference = "Stop"
    $processedCount = 0
    $results = @()
}

process {
    foreach ($item in $InputItems) {
        try {
            Write-Progress -Activity "Processing Items" -Status "Processing: $item" -PercentComplete (($processedCount / $InputItems.Count) * 100)

            # Processing logic here
            $result = Process-Item -Item $item
            $results += $result
            $processedCount++

            Write-Verbose "✅ Processed: $item"
        }
        catch {
            Write-Warning "⚠️ Failed to process: $item - $($_.Exception.Message)"
        }
    }
}

end {
    Write-Host "📊 Processing Summary:" -ForegroundColor Cyan
    Write-Host "  Total items: $($InputItems.Count)"
    Write-Host "  Processed: $processedCount"
    Write-Host "  Failed: $(($InputItems.Count) - $processedCount)"

    if ($OutputPath) {
        $results | Export-Csv -Path $OutputPath -NoTypeInformation
        Write-Host "💾 Results saved to: $OutputPath" -ForegroundColor Green
    }
}
```

## Error Handling Standards

### Consistent Error Patterns

```powershell
# Use try/catch for expected failures
try {
    $result = Invoke-RiskyOperation
}
catch [System.UnauthorizedAccessException] {
    Write-Error "❌ Access denied. Run as administrator or check permissions."
    exit 1
}
catch [System.IO.FileNotFoundException] {
    Write-Error "❌ Required file not found: $($_.Exception.Message)"
    exit 1
}
catch {
    Write-Error "❌ Unexpected error: $($_.Exception.Message)"
    Write-Debug $_.ScriptStackTrace
    exit 1
}

# Use validation for parameter checking
if (-not (Test-Path $ConfigPath)) {
    throw [System.IO.FileNotFoundException] "Configuration file not found: $ConfigPath"
}

# Use Write-Error for non-terminating errors
if ($warningCondition) {
    Write-Warning "⚠️ Non-critical issue detected: $details"
}
```

## Cross-Platform Considerations

### Path Handling

```powershell
# Always use Join-Path for path construction
$configPath = Join-Path $PSScriptRoot "config.yaml"
$logPath = Join-Path $env:TEMP "script.log"

# Use System.IO.Path for advanced operations
$fileName = [System.IO.Path]::GetFileNameWithoutExtension($inputFile)
$directory = [System.IO.Path]::GetDirectoryName($inputPath)
```

### Platform Detection

```powershell
# Detect operating system
if ($IsMacOS) {
    $defaultPath = "~/Library/Application Support/ToolName"
} elseif ($IsLinux) {
    $defaultPath = "~/.config/toolname"
} elseif ($IsWindows) {
    $defaultPath = "$env:APPDATA\ToolName"
} else {
    throw "Unsupported operating system"
}

# Check for platform-specific commands
$gitCommand = if (Get-Command git -ErrorAction SilentlyContinue) {
    "git"
} else {
    throw "Git is required but not found in PATH"
}
```

## Output and User Experience

### Consistent Visual Feedback

```powershell
# Use emoji and colors consistently
Write-Host "🚀 Starting operation..." -ForegroundColor Cyan
Write-Host "📦 Installing dependencies..." -ForegroundColor Blue
Write-Host "⚠️ Warning: This will modify files" -ForegroundColor Yellow
Write-Host "❌ Operation failed" -ForegroundColor Red
Write-Host "✅ Operation completed successfully" -ForegroundColor Green

# Progress indicators for long operations
for ($i = 0; $i -lt $items.Count; $i++) {
    Write-Progress -Activity "Processing Items" -Status "Item $($i + 1) of $($items.Count)" -PercentComplete (($i / $items.Count) * 100)
    # Process item
}
Write-Progress -Activity "Processing Items" -Completed
```

### User Interaction

```powershell
# Confirmation prompts
if (-not $Force) {
    $confirmation = Read-Host "This will delete existing files. Continue? (y/N)"
    if ($confirmation -notmatch '^[yY]') {
        Write-Host "Operation cancelled by user" -ForegroundColor Yellow
        exit 0
    }
}

# ShouldProcess support
if ($PSCmdlet.ShouldProcess($targetPath, "Delete directory")) {
    Remove-Item $targetPath -Recurse -Force
}
```

## Performance Considerations

### Efficient Operations

```powershell
# Use pipeline operations where possible
$results = $inputItems |
    Where-Object { $_.IsValid } |
    ForEach-Object { Process-Item $_ } |
    Sort-Object Name

# Avoid unnecessary loops
# BAD:
$results = @()
foreach ($item in $items) {
    $results += Process-Item $item
}

# GOOD:
$results = $items | ForEach-Object { Process-Item $_ }

# Cache expensive operations
$cachedValue = $null
function Get-ExpensiveValue {
    if (-not $cachedValue) {
        $cachedValue = Invoke-ExpensiveOperation
    }
    return $cachedValue
}
```

## Testing and Validation

### Built-in Validation

```powershell
# Add validation to all scripts
function Test-ScriptPrerequisites {
    $errors = @()

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        $errors += "PowerShell 7.0+ required"
    }

    # Check required commands
    $requiredCommands = @('git', 'curl')
    foreach ($cmd in $requiredCommands) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            $errors += "Required command not found: $cmd"
        }
    }

    # Check file permissions
    if (-not (Test-Path $workingDirectory -PathType Container)) {
        $errors += "Working directory not accessible: $workingDirectory"
    }

    if ($errors.Count -gt 0) {
        throw "Prerequisites not met:`n  - $($errors -join "`n  - ")"
    }
}

# Call at script start
Test-ScriptPrerequisites
```

## Integration with Quality Tools

### PSScriptAnalyzer Compliance

```powershell
# Suppress specific rules where justified
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

# Follow naming conventions
function Verb-Noun {           # ✅ Good: Approved verb + singular noun
function Get-UserData {        # ✅ Good: Clear, descriptive
function Start-ProcessingTask { # ✅ Good: Follows PowerShell conventions

# Avoid
function GetData {             # ❌ Bad: Not PowerShell convention
function Process-Datas {       # ❌ Bad: Plural noun
function Custom-Action {       # ❌ Bad: Non-approved verb
```

### Module Integration

When scripts need to use modules from the project:

```powershell
# Import project modules with error handling
try {
    $modulePath = Join-Path $PSScriptRoot "../powershell/Install-QualityTools.psm1"
    Import-Module $modulePath -Force -ErrorAction Stop
}
catch {
    Write-Error "❌ Failed to import required module: $($_.Exception.Message)"
    exit 1
}

# Use module functions
try {
    Install-AllQualityTool -Scope CurrentUser
}
catch {
    Write-Error "❌ Quality tools installation failed: $($_.Exception.Message)"
    exit 1
}
```
