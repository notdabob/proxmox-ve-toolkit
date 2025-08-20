---
applyTo: ["scripts/**/*.ps1", "scripts/**/*.psm1", "scripts/**/*.psd1"]
---

# PowerShell Architecture Instructions

## Overview

This file provides guidance on organizing PowerShell code architecture, deciding when to split functionality
across multiple files, and establishing consistent patterns for the Proxmox VE toolkit project.

## Project Architecture Principles

### Modular Design

Organize PowerShell code into logical, reusable components:

```text
scripts/
├── powershell/                     # PowerShell modules and scripts
│   ├── Core/                       # Core functionality modules
│   │   ├── Install-QualityTool.psm1
│   │   ├── Install-QualityTool.psd1
│   │   ├── Invoke-QualityChecks.psm1
│   │   └── Invoke-QualityChecks.psd1
│   ├── Proxmox/                    # Proxmox-specific modules
│   │   ├── Get-ProxmoxConfig.psm1
│   │   ├── Set-ProxmoxConfig.psm1
│   │   └── Invoke-ProxmoxMaintenance.psm1
│   ├── Utilities/                  # General utility modules
│   │   ├── Invoke-Python.psm1
│   │   └── Get-SystemInfo.psm1
│   └── Scripts/                    # Standalone scripts
│       ├── install.ps1
│       └── setup-environment.ps1
├── shell/                          # Shell scripts for bootstrapping
│   └── install.sh
```

### Separation of Concerns

Each module should have a single, well-defined responsibility:

**✅ Good Separation:**

- `Install-QualityTool.psm1` - Tool installation only
- `Invoke-QualityChecks.psm1` - Quality checking only
- `Get-ProxmoxConfig.psm1` - Configuration retrieval only
- `Set-ProxmoxConfig.psm1` - Configuration management only

**❌ Poor Separation:**

- `ProxmoxUtils.psm1` - Mixed functionality (too generic)
- `Everything.psm1` - All functions in one module
- `Helper.psm1` - Vague purpose

## When to Create New Files

### Script vs Module Decision Matrix

| Criteria         | Standalone Script (.ps1)       | Module (.psm1)                   |
| ---------------- | ------------------------------ | -------------------------------- |
| **Reusability**  | Single-use, specific task      | Reusable across multiple scripts |
| **Complexity**   | < 200 lines, simple logic      | > 200 lines or complex functions |
| **Scope**        | One main operation             | Multiple related operations      |
| **Dependencies** | Minimal external dependencies  | May depend on other modules      |
| **Testing**      | Basic validation               | Comprehensive unit testing       |
| **Examples**     | install.ps1, backup-config.ps1 | Install-QualityTool.psm1         |

### Module Splitting Guidelines

**Keep as Single Module When:**

- Functions are tightly coupled
- Total module size < 1000 lines
- All functions serve the same core purpose
- < 10 public functions

**Split into Multiple Modules When:**

- Functions can operate independently
- Module size > 1000 lines
- Distinct functional areas emerge
- > 10 public functions
- Different versioning/release cycles needed

### Function Organization Within Modules

**Single Function per File (.ps1) Pattern:**
Use when functions are large (> 100 lines) or complex:

```text
MyModule/
├── MyModule.psm1              # Main module file (dot-sources others)
├── MyModule.psd1              # Module manifest
├── Private/                   # Internal helper functions
│   ├── Helper-Validation.ps1
│   ├── Helper-Formatting.ps1
│   └── Helper-Logging.ps1
└── Public/                    # Exported functions
    ├── Get-ModuleData.ps1
    ├── Set-ModuleConfig.ps1
    ├── Test-ModuleHealth.ps1
    └── Invoke-ModuleOperation.ps1
```

**All Functions in Module (.psm1) Pattern:**
Use when functions are small (< 100 lines) and related:

```text
SimpleModule/
├── SimpleModule.psm1          # Contains all functions
└── SimpleModule.psd1          # Module manifest
```

## Naming Conventions and Standards

### File Naming Patterns

**Scripts (.ps1):**

- Use descriptive action-oriented names
- Include the main verb: `install.ps1`, `backup-config.ps1`, `test-connection.ps1`
- Avoid generic names: `script.ps1`, `utils.ps1`, `helper.ps1`

**Modules (.psm1):**

- Use Verb-Noun pattern: `Get-ProxmoxConfig.psm1`, `Install-QualityTool.psm1`
- Group related functions under same noun: `*-ProxmoxConfig.psm1`
- Avoid plural nouns: `Get-ProxmoxConfigs.psm1` → `Get-ProxmoxConfig.psm1`

**Manifests (.psd1):**

- Match the module name exactly: `Get-ProxmoxConfig.psd1`

### Directory Organization Standards

**By Functional Area:**

```
scripts/powershell/
├── Proxmox/                    # Proxmox VE specific functionality
├── Quality/                    # Quality assurance tools
├── System/                     # System administration
└── Network/                    # Network operations
```

**By Operation Type:**

```
scripts/powershell/
├── Get-Modules/                # Data retrieval modules
├── Set-Modules/                # Configuration modules
├── Invoke-Modules/             # Action/execution modules
└── Test-Modules/               # Validation/testing modules
```

## Dependency Management

### Module Dependencies

**Establish Clear Dependency Hierarchy:**

```
Level 1: Foundation Modules
├── Invoke-Python.psm1          # No dependencies
├── Get-SystemInfo.psm1         # No dependencies
└── Write-Log.psm1              # No dependencies

Level 2: Core Modules
├── Install-QualityTool.psm1   # Depends on: Invoke-Python, Get-SystemInfo
└── Get-ProxmoxConfig.psm1      # Depends on: Write-Log

Level 3: Composite Modules
├── Invoke-QualityChecks.psm1   # Depends on: Install-QualityTool, Write-Log
└── Set-ProxmoxEnvironment.psm1 # Depends on: Get-ProxmoxConfig, Install-QualityTool
```

**Avoid Circular Dependencies:**

```powershell
# ❌ BAD: Circular dependency
# ModuleA depends on ModuleB
# ModuleB depends on ModuleA

# ✅ GOOD: Hierarchical dependency
# ModuleA depends on CommonModule
# ModuleB depends on CommonModule
# No direct dependency between A and B
```

### Managing Dependencies in Code

**Explicit Dependency Loading:**

```powershell
#Requires -Version 7.0

# Define required modules at top of file
$RequiredModules = @(
    @{ Name = 'Write-Log'; Version = '1.0.0'; Path = "$PSScriptRoot/../Core/Write-Log.psm1" },
    @{ Name = 'Get-SystemInfo'; Version = '1.2.0'; Path = "$PSScriptRoot/../Utilities/Get-SystemInfo.psm1" }
)

# Import required modules with error handling
foreach ($module in $RequiredModules) {
    try {
        if (Test-Path $module.Path) {
            Import-Module $module.Path -Force -ErrorAction Stop
        } else {
            throw "Module file not found: $($module.Path)"
        }

        $importedModule = Get-Module $module.Name
        if (-not $importedModule -or $importedModule.Version -lt [version]$module.Version) {
            throw "Module $($module.Name) version $($module.Version) or higher is required"
        }

        Write-Verbose "Successfully imported $($module.Name) v$($importedModule.Version)"
    }
    catch {
        throw "Failed to import required module $($module.Name): $($_.Exception.Message)"
    }
}
```

## Configuration Management Architecture

### Centralized Configuration Pattern

**Configuration Module Structure:**

```
scripts/powershell/Configuration/
├── Get-ProjectConfig.psm1       # Configuration retrieval
├── Set-ProjectConfig.psm1       # Configuration management
├── Test-ProjectConfig.psm1      # Configuration validation
└── Private/
    ├── ConfigSchema.ps1         # Configuration schema definitions
    └── ConfigHelpers.ps1        # Internal configuration helpers
```

**Configuration Schema Example:**

```powershell
# ConfigSchema.ps1
$script:ConfigSchema = @{
    ProxmoxVE = @{
        Required = $true
        Type = 'hashtable'
        Properties = @{
            ServerUrl = @{ Type = 'string'; Required = $true; Pattern = '^https?://' }
            Username = @{ Type = 'string'; Required = $true }
            TokenId = @{ Type = 'string'; Required = $false }
        }
    }
    QualityTools = @{
        Required = $false
        Type = 'hashtable'
        Properties = @{
            PSScriptAnalyzer = @{ Type = 'boolean'; Required = $false; Default = $true }
            ShellCheck = @{ Type = 'boolean'; Required = $false; Default = $true }
        }
    }
}
```

### Environment-Specific Configuration

**Multi-Environment Support:**

```powershell
function Get-EnvironmentConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Development', 'Testing', 'Production')]
        [string]$Environment = 'Development'
    )

    $configPath = Join-Path $PSScriptRoot "../../configs"
    $baseConfigPath = Join-Path $configPath "base-config.yaml"
    $envConfigPath = Join-Path $configPath "$Environment.yaml"

    # Load base configuration
    $config = Get-ConfigFromFile -Path $baseConfigPath

    # Override with environment-specific settings
    if (Test-Path $envConfigPath) {
        $envConfig = Get-ConfigFromFile -Path $envConfigPath
        $config = Merge-Configuration -Base $config -Override $envConfig
    }

    return $config
}
```

## Error Handling Architecture

### Centralized Error Handling

**Error Handler Module:**

```powershell
# Write-ErrorHandler.psm1
function Write-ErrorHandler {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [Parameter(Mandatory = $false)]
        [string]$Context = "Unknown",

        [Parameter(Mandatory = $false)]
        [switch]$Terminate
    )

    $errorInfo = @{
        Context = $Context
        Message = $ErrorRecord.Exception.Message
        ScriptName = $ErrorRecord.InvocationInfo.ScriptName
        LineNumber = $ErrorRecord.InvocationInfo.ScriptLineNumber
        Command = $ErrorRecord.InvocationInfo.MyCommand.Name
        Timestamp = Get-Date
    }

    # Log error details
    Write-Log -Message "ERROR in $Context`: $($errorInfo.Message)" -Level Error
    Write-Log -Message "  Script: $($errorInfo.ScriptName):$($errorInfo.LineNumber)" -Level Error
    Write-Log -Message "  Command: $($errorInfo.Command)" -Level Error

    # Optional: Send to logging system
    if ($script:ModuleConfig.EnableRemoteLogging) {
        Send-ErrorToLoggingSystem -ErrorInfo $errorInfo
    }

    if ($Terminate) {
        throw $ErrorRecord.Exception
    }
}

# Usage in other modules
try {
    Invoke-RiskyOperation
}
catch {
    Write-ErrorHandler -ErrorRecord $_ -Context "Proxmox Configuration" -Terminate
}
```

## Testing Architecture

### Test Organization

**Test Structure:**

```
Tests/
├── Unit/                       # Unit tests for individual functions
│   ├── Core/
│   │   ├── Install-QualityTool.Tests.ps1
│   │   └── Invoke-QualityChecks.Tests.ps1
│   └── Proxmox/
│       └── Get-ProxmoxConfig.Tests.ps1
├── Integration/                # Integration tests for module interactions
│   ├── QualityTools-Integration.Tests.ps1
│   └── Proxmox-Integration.Tests.ps1
└── End-to-End/                # Full workflow tests
    └── Complete-Setup.Tests.ps1
```

**Test Helpers Module:**

```powershell
# TestHelpers.psm1
function New-TestEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TestName = "DefaultTest"
    )

    $testDir = Join-Path $TestDrive $TestName
    New-Item -Path $testDir -ItemType Directory -Force

    # Create test configuration files
    $testConfig = @{
        TestMode = $true
        LogLevel = "Debug"
        TestDirectory = $testDir
    }

    $configPath = Join-Path $testDir "test-config.json"
    $testConfig | ConvertTo-Json | Set-Content $configPath

    return @{
        TestDirectory = $testDir
        ConfigPath = $configPath
        Config = $testConfig
    }
}

function Remove-TestEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestDirectory
    )

    if (Test-Path $TestDirectory) {
        Remove-Item $TestDirectory -Recurse -Force
    }
}
```

## Performance Architecture

### Performance Monitoring Module

```powershell
# Measure-Performance.psm1
function Measure-ModulePerformance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [string]$OperationName = "Unknown Operation"
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $memoryBefore = [System.GC]::GetTotalMemory($false)

    try {
        $result = & $ScriptBlock
        $success = $true
    }
    catch {
        $success = $false
        $error = $_.Exception.Message
        throw
    }
    finally {
        $stopwatch.Stop()
        $memoryAfter = [System.GC]::GetTotalMemory($false)
        $memoryUsed = $memoryAfter - $memoryBefore

        $performanceData = @{
            OperationName = $OperationName
            ExecutionTime = $stopwatch.Elapsed
            MemoryUsed = $memoryUsed
            Success = $success
            Timestamp = Get-Date
        }

        if (-not $success) {
            $performanceData.Error = $error
        }

        # Log performance data
        Write-PerformanceLog -Data $performanceData
    }

    return $result
}

# Usage
$result = Measure-ModulePerformance -OperationName "Quality Check Execution" -ScriptBlock {
    Invoke-AllQualityCheck -Path $ProjectRoot
}
```

## Documentation Architecture

### Automated Documentation Generation

```powershell
# Generate-ModuleDocs.psm1
function New-ModuleDocumentation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModulePath,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "docs"
    )

    Import-Module $ModulePath -Force
    $module = Get-Module (Split-Path $ModulePath -LeafBase)

    $documentation = @{
        ModuleName = $module.Name
        Version = $module.Version
        Author = $module.Author
        Description = $module.Description
        Functions = @()
    }

    foreach ($functionName in $module.ExportedFunctions.Keys) {
        $help = Get-Help $functionName -Full

        $functionDoc = @{
            Name = $functionName
            Synopsis = $help.Synopsis
            Description = $help.Description.Text
            Parameters = @()
            Examples = @()
        }

        # Add parameters
        foreach ($parameter in $help.Parameters.Parameter) {
            $functionDoc.Parameters += @{
                Name = $parameter.Name
                Type = $parameter.Type.Name
                Description = $parameter.Description.Text
                Required = $parameter.Required
            }
        }

        # Add examples
        foreach ($example in $help.Examples.Example) {
            $functionDoc.Examples += @{
                Title = $example.Title
                Code = $example.Code
                Remarks = $example.Remarks.Text
            }
        }

        $documentation.Functions += $functionDoc
    }

    # Generate markdown documentation
    $markdown = ConvertTo-MarkdownDocumentation -Documentation $documentation

    $outputFile = Join-Path $OutputPath "$($module.Name).md"
    $markdown | Set-Content $outputFile -Encoding UTF8

    Write-Host "✅ Documentation generated: $outputFile" -ForegroundColor Green
}
```

## Deployment Architecture

### Module Packaging and Distribution

```powershell
# Build-ModulePackage.psm1
function New-ModulePackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModulePath,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "dist",

        [Parameter(Mandatory = $false)]
        [switch]$IncludeTests
    )

    $moduleName = Split-Path $ModulePath -LeafBase
    $manifest = Test-ModuleManifest (Join-Path $ModulePath "$moduleName.psd1")

    $packagePath = Join-Path $OutputPath "$moduleName-$($manifest.Version)"

    # Create package directory
    New-Item -Path $packagePath -ItemType Directory -Force

    # Copy module files
    Copy-Item -Path "$ModulePath/*.psm1" -Destination $packagePath
    Copy-Item -Path "$ModulePath/*.psd1" -Destination $packagePath

    if ($IncludeTests -and (Test-Path "$ModulePath/Tests")) {
        Copy-Item -Path "$ModulePath/Tests" -Destination $packagePath -Recurse
    }

    # Create package manifest
    $packageInfo = @{
        Name = $moduleName
        Version = $manifest.Version.ToString()
        Author = $manifest.Author
        Description = $manifest.Description
        PackageDate = Get-Date
        Files = Get-ChildItem $packagePath -Recurse | Select-Object -ExpandProperty Name
    }

    $packageInfo | ConvertTo-Json | Set-Content (Join-Path $packagePath "package.json")

    Write-Host "✅ Module package created: $packagePath" -ForegroundColor Green
}
```

This architecture ensures scalable, maintainable PowerShell code organization for the Proxmox VE toolkit project.
