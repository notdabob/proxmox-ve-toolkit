---
applyTo: ["scripts/**/*.psm1", "scripts/**/*.psd1"]
---

# PowerShell Module Export Standards

## Overview

This file establishes consistent standards for what functions, variables, and aliases should be exported
from PowerShell modules, ensuring a clean public API surface and maintainable code organization.

## Export Philosophy

### Public vs Private Principle

#### Export Only What Users Need

- Functions that provide direct value to module consumers
- Functions that represent the primary module interface
- Utility functions used by multiple external scripts

#### Keep Internal What Users Don't Need

- Helper functions used only within the module
- Implementation details and intermediate processing functions
- Validation and formatting functions used internally

## Function Export Standards

### Determining What to Export

Use this decision matrix to determine if a function should be exported:

| Criteria          | Export                            | Keep Private                        |
| ----------------- | --------------------------------- | ----------------------------------- |
| **Usage**         | Used by external scripts/modules  | Used only within this module        |
| **Stability**     | Stable API, unlikely to change    | Implementation detail, may change   |
| **Purpose**       | Provides direct user/system value | Supports other functions internally |
| **Documentation** | Fully documented with examples    | Minimal internal documentation      |
| **Testing**       | Has comprehensive unit tests      | May have internal tests only        |

### Export Categories

#### Always Export

```powershell
# Primary module functionality
Export-ModuleMember -Function @(
    'Get-ModuleData',           # Main data retrieval
    'Set-ModuleConfiguration',  # Primary configuration
    'Invoke-ModuleOperation',   # Main operations
    'Test-ModuleState'          # Validation/health checks
)
```

#### Consider Exporting

```powershell
# Utility functions that provide value to external users
Export-ModuleMember -Function @(
    'ConvertTo-ModuleFormat',   # Data transformation utilities
    'Get-ModuleVersion',        # Version information
    'Reset-ModuleDefaults'      # Reset/cleanup operations
)
```

#### Never Export

```powershell
# Keep these private - internal use only
# Write-InternalLog          # Logging helpers
# Test-InternalState         # Internal validation
# Format-InternalData        # Internal formatting
# Invoke-InternalCleanup     # Internal maintenance
```

## Module Structure Patterns

### Small Module (< 10 Functions)

For modules with few functions, list exports explicitly:

```powershell
# ProxmoxConfig.psm1 - Simple configuration module

function Get-ProxmoxConfiguration {
    # Public function implementation
}

function Set-ProxmoxConfiguration {
    # Public function implementation
}

function Test-ProxmoxConfiguration {
    # Public function implementation
}

function Write-ConfigLog {
    # Private helper function - not exported
}

function Format-ConfigData {
    # Private helper function - not exported
}

# Explicit exports - clear and maintainable
Export-ModuleMember -Function @(
    'Get-ProxmoxConfiguration',
    'Set-ProxmoxConfiguration',
    'Test-ProxmoxConfiguration'
)
```

### Large Module (> 10 Functions)

For larger modules, organize with clear public/private separation:

```powershell
# ProxmoxMigration.psm1 - Complex migration module

# region Public Functions

function Start-Migration {
    <# Full documentation required #>
}

function Get-MigrationStatus {
    <# Full documentation required #>
}

function Stop-Migration {
    <# Full documentation required #>
}

# endregion

# region Private Functions

function Write-MigrationLog {
    <# Minimal documentation - internal use #>
}

function Test-MigrationPrerequisites {
    <# Minimal documentation - internal use #>
}

function Invoke-NetworkOptimization {
    <# Minimal documentation - internal use #>
}

# endregion

# Explicit exports for maintainability
Export-ModuleMember -Function @(
    'Start-Migration',
    'Get-MigrationStatus',
    'Stop-Migration'
)
```

### Modular Large Module (Dot-Sourced)

For very large modules split across files:

```powershell
# ProxmoxCluster.psm1 - Main module file

# Dot-source public and private functions
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import function $($import.FullName): $($_.Exception.Message)"
        throw
    }
}

# Export all public functions (file names become function names)
if ($Public) {
    Export-ModuleMember -Function $Public.BaseName
}
```

## Variable and Alias Export Guidelines

### Variables - Export Sparingly

Only export variables that provide essential configuration or state information:

```powershell
# Module-level variables
$script:ModuleVersion = "1.2.0"
$script:ModuleConfig = @{}
$script:ModuleState = @{}

# Export only what users need
Export-ModuleMember -Variable @(
    'ModuleVersion'  # Version info useful for external scripts
    # ModuleConfig and ModuleState remain private
)
```

### Aliases - Provide Convenience

Export aliases for frequently used functions with long names:

```powershell
# Create useful aliases
Set-Alias -Name 'gpc' -Value 'Get-ProxmoxConfiguration'
Set-Alias -Name 'spc' -Value 'Set-ProxmoxConfiguration'
Set-Alias -Name 'tpc' -Value 'Test-ProxmoxConfiguration'

# Export aliases
Export-ModuleMember -Alias @(
    'gpc',
    'spc',
    'tpc'
)
```

## Module Manifest Integration

### Manifest Export Configuration

Ensure the module manifest (`.psd1`) matches the module exports:

```powershell
# ProxmoxMigration.psd1
@{
    ModuleVersion = '1.0.0'
    RootModule = 'ProxmoxMigration.psm1'

    # Functions to export - should match Export-ModuleMember in .psm1
    FunctionsToExport = @(
        'Start-Migration',
        'Get-MigrationStatus',
        'Stop-Migration'
    )

    # Variables to export - minimal set
    VariablesToExport = @(
        'ModuleVersion'
    )

    # Aliases to export - convenience shortcuts
    AliasesToExport = @(
        'sm',    # Start-Migration
        'gms',   # Get-MigrationStatus
        'stm'    # Stop-Migration
    )

    # Don't export everything by default
    CmdletsToExport = @()
}
```

## Versioning and Compatibility

### Export Stability Guidelines

Once a function is exported in a released version:

1. **Maintain Compatibility**: Exported functions become part of the public API
2. **Deprecate Gracefully**: Use `[Obsolete]` attribute before removing exports
3. **Version Appropriately**: Breaking changes require major version increment

```powershell
# Deprecating an exported function
[Obsolete("Get-OldFunction is deprecated. Use Get-NewFunction instead.")]
function Get-OldFunction {
    # Redirect to new function
    return Get-NewFunction @args
}

# Still export during deprecation period
Export-ModuleMember -Function @(
    'Get-NewFunction',
    'Get-OldFunction'    # Keep during deprecation
)
```

### Migration Strategies

When restructuring exports:

```powershell
# Phase 1: Add new functions, keep old ones
Export-ModuleMember -Function @(
    'Get-ConfigurationData',      # New function
    'Get-Configuration'           # Old function - still supported
)

# Phase 2: Mark old functions as obsolete
[Obsolete("Use Get-ConfigurationData instead")]
function Get-Configuration { ... }

# Phase 3: Remove old functions in next major version
Export-ModuleMember -Function @(
    'Get-ConfigurationData'       # Only new function
)
```

## Testing Export Contracts

### Validate Exports

Include tests to ensure export consistency:

```powershell
# ModuleExports.Tests.ps1
Describe "Module Exports" {
    BeforeAll {
        Import-Module "$PSScriptRoot\ProxmoxMigration.psm1" -Force
        $module = Get-Module ProxmoxMigration
    }

    Context "Function Exports" {
        It "Should export expected functions" {
            $expectedFunctions = @(
                'Start-Migration',
                'Get-MigrationStatus',
                'Stop-Migration'
            )

            $exportedFunctions = $module.ExportedFunctions.Keys

            foreach ($function in $expectedFunctions) {
                $exportedFunctions | Should -Contain $function
            }
        }

        It "Should not export private functions" {
            $privateFunctions = @(
                'Write-MigrationLog',
                'Test-MigrationPrerequisites'
            )

            $exportedFunctions = $module.ExportedFunctions.Keys

            foreach ($function in $privateFunctions) {
                $exportedFunctions | Should -Not -Contain $function
            }
        }
    }
}
```

### Documentation Validation

Ensure all exported functions have complete documentation:

```powershell
# DocumentationValidation.Tests.ps1
Describe "Export Documentation" {
    Context "Exported Functions" {
        It "All exported functions should have complete help" {
            $exportedFunctions = (Get-Module ProxmoxMigration).ExportedFunctions.Values

            foreach ($function in $exportedFunctions) {
                $help = Get-Help $function.Name

                $help.Synopsis | Should -Not -BeNullOrEmpty
                $help.Description | Should -Not -BeNullOrEmpty
                $help.Examples | Should -Not -BeNullOrEmpty
            }
        }
    }
}
```

## Quality Gates

### Pre-Release Checklist

Before releasing a module version:

- [ ] All exported functions have complete documentation
- [ ] Module manifest matches module exports exactly
- [ ] Export tests pass
- [ ] No private functions accidentally exported
- [ ] Backward compatibility maintained (for non-major versions)
- [ ] Version number updated appropriately

### Automated Validation

Include export validation in CI/CD pipeline:

```powershell
# ValidateExports.ps1 - CI script
$ModulePath = "./scripts/powershell/ProxmoxMigration"
$ManifestPath = "$ModulePath/ProxmoxMigration.psd1"
$ModuleFile = "$ModulePath/ProxmoxMigration.psm1"

# Import module
Import-Module $ModuleFile -Force

# Get actual exports
$module = Get-Module (Split-Path $ModuleFile -LeafBase)
$actualExports = $module.ExportedFunctions.Keys

# Get manifest exports
$manifest = Import-PowerShellDataFile $ManifestPath
$manifestExports = $manifest.FunctionsToExport

# Validate consistency
$exportMismatch = Compare-Object $actualExports $manifestExports
if ($exportMismatch) {
    Write-Error "Export mismatch between module and manifest"
    $exportMismatch | Format-Table
    exit 1
}

Write-Host "✅ Module exports validated successfully"
```

This export standards file ensures clean, maintainable module interfaces while providing clear guidance
for developers on what should and shouldn't be exposed to module consumers.

