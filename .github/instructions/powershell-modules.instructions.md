---
applyTo: ["scripts/**/*.psm1", "scripts/**/*.psd1"]
---

# PowerShell Modules Instructions

## Overview

This file provides specific guidance for PowerShell module files (`.psm1`) and manifest files (`.psd1`).
Modules are reusable collections of functions, cmdlets, variables, and aliases that can be imported
into PowerShell sessions.

## Module Design Principles

### Single Responsibility Principle

Each module should have one clear purpose:

- ✅ `Install-QualityTools.psm1` - Handles quality tool installation
- ✅ `Invoke-QualityChecks.psm1` - Performs quality checking operations
- ✅ `Invoke-Python.psm1` - Cross-platform Python execution
- ❌ `Utilities.psm1` - Too generic, unclear purpose

### Module Naming Conventions

Follow PowerShell approved verb-noun patterns:

```
[ApprovedVerb]-[SingularNoun].psm1
```

**Approved Verbs by Category:**

- **Common**: Get, Set, New, Remove, Clear, Add, Copy, Move, Invoke, Test
- **Communications**: Connect, Disconnect, Read, Write, Receive, Send
- **Data**: Backup, Checkpoint, Compare, Compress, Convert, Export, Import
- **Lifecycle**: Approve, Complete, Install, Publish, Restart, Resume, Start, Stop
- **Diagnostic**: Debug, Measure, Ping, Repair, Resolve, Test, Trace
- **Security**: Block, Grant, Protect, Revoke, Unblock, Unprotect

**Examples:**

- `Get-ProxmoxConfig.psm1`
- `Install-ProxmoxTools.psm1`
- `Invoke-SystemMaintenance.psm1`
- `Test-NetworkConnectivity.psm1`

## Module Structure (.psm1)

### Standard Module Template

```powershell
<#
.SYNOPSIS
    Brief description of the module's purpose

.DESCRIPTION
    Detailed description of the module's functionality, what problems it solves,
    and how it should be used. Include information about dependencies and
    prerequisites.

.NOTES
    File Name      : ModuleName.psm1
    Author         : [Author Name]
    Prerequisite   : PowerShell 7.0+
    Copyright      : [Copyright Info]

.LINK
    https://github.com/your-repo/docs/ModuleName

.EXAMPLE
    Import-Module ./scripts/powershell/ModuleName.psm1
    Use-ModuleFunction -Parameter "value"

.EXAMPLE
    Import-Module ./scripts/powershell/ModuleName.psm1 -Force
    Get-ModuleData | Export-Csv "output.csv"
#>

# Module-level error handling
$ErrorActionPreference = "Stop"

# Module-level variables (use sparingly)
$script:ModuleName = "ModuleName"
$script:ModuleVersion = "1.0.0"

# Private helper functions (not exported)
function Write-ModuleLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Info"    { "Cyan" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        "Success" { "Green" }
    }

    Write-Host "[$timestamp] [$script:ModuleName] [$Level] $Message" -ForegroundColor $color
}

function Test-ModulePrerequisites {
    [CmdletBinding()]
    param()

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "This module requires PowerShell 7.0 or later"
    }

    # Check for required modules
    $requiredModules = @()  # Add required modules here
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            throw "Required module not found: $module"
        }
    }

    # Check for required external commands
    $requiredCommands = @()  # Add required commands here
    foreach ($command in $requiredCommands) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "Required command not found: $command"
        }
    }
}

# Public functions (exported)

function Get-SampleData {
    <#
    .SYNOPSIS
        Gets sample data from the module

    .DESCRIPTION
        This function demonstrates the standard pattern for module functions.
        It includes comprehensive parameter validation, error handling, and
        proper output formatting.

    .PARAMETER InputPath
        Path to the input file or directory

    .PARAMETER FilterCriteria
        Optional filter to apply to the data

    .PARAMETER OutputFormat
        Format for the output data

    .EXAMPLE
        Get-SampleData -InputPath "C:\Data"
        Gets all data from the specified path

    .EXAMPLE
        Get-SampleData -InputPath "C:\Data" -FilterCriteria "*.txt" -OutputFormat "JSON"
        Gets filtered data in JSON format

    .OUTPUTS
        System.Object[]
        Array of processed data objects

    .NOTES
        This function requires read access to the specified path
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({ Test-Path $_ })]
        [string]$InputPath,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$FilterCriteria = "*",

        [Parameter(Mandatory = $false)]
        [ValidateSet("JSON", "XML", "CSV", "Object")]
        [string]$OutputFormat = "Object"
    )

    begin {
        Write-ModuleLog "Starting data retrieval from: $InputPath" "Info"
        $results = @()
    }

    process {
        try {
            # Validation
            if (-not (Test-Path $InputPath)) {
                throw "Input path does not exist: $InputPath"
            }

            # Main processing logic
            $items = Get-ChildItem -Path $InputPath -Filter $FilterCriteria

            foreach ($item in $items) {
                $processedItem = @{
                    Name = $item.Name
                    Path = $item.FullName
                    Size = if ($item.PSIsContainer) { $null } else { $item.Length }
                    LastModified = $item.LastWriteTime
                    Type = if ($item.PSIsContainer) { "Directory" } else { "File" }
                }

                $results += [PSCustomObject]$processedItem
            }

            Write-ModuleLog "Processed $($results.Count) items" "Success"
        }
        catch {
            Write-ModuleLog "Error processing data: $($_.Exception.Message)" "Error"
            throw
        }
    }

    end {
        # Format output based on requested format
        switch ($OutputFormat) {
            "JSON" { return $results | ConvertTo-Json -Depth 10 }
            "XML"  { return $results | ConvertTo-Xml -As String }
            "CSV"  { return $results | ConvertTo-Csv -NoTypeInformation }
            default { return $results }
        }
    }
}

function Set-SampleConfiguration {
    <#
    .SYNOPSIS
        Sets configuration for the module

    .DESCRIPTION
        Configures module settings and validates the configuration.
        Supports both file-based and parameter-based configuration.

    .PARAMETER ConfigPath
        Path to configuration file

    .PARAMETER Settings
        Hashtable of configuration settings

    .PARAMETER Validate
        Validate configuration before applying

    .EXAMPLE
        Set-SampleConfiguration -ConfigPath "config.yaml"
        Loads configuration from file

    .EXAMPLE
        $config = @{ Setting1 = "Value1"; Setting2 = "Value2" }
        Set-SampleConfiguration -Settings $config -Validate
        Sets configuration from hashtable with validation
    #>
    [CmdletBinding(DefaultParameterSetName = "FromFile")]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = "FromFile")]
        [ValidateScript({ Test-Path $_ })]
        [string]$ConfigPath,

        [Parameter(Mandatory = $true, ParameterSetName = "FromHashtable")]
        [ValidateNotNull()]
        [hashtable]$Settings,

        [Parameter(Mandatory = $false)]
        [switch]$Validate
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq "FromFile") {
            Write-ModuleLog "Loading configuration from: $ConfigPath" "Info"

            # Load configuration based on file type
            $extension = [System.IO.Path]::GetExtension($ConfigPath).ToLower()
            switch ($extension) {
                ".json" {
                    $Settings = Get-Content $ConfigPath | ConvertFrom-Json -AsHashtable
                }
                ".yaml" -or ".yml" {
                    # Requires PowerShell-Yaml module or yq command
                    if (Get-Module -ListAvailable -Name powershell-yaml) {
                        $Settings = Get-Content $ConfigPath | ConvertFrom-Yaml
                    } elseif (Get-Command yq -ErrorAction SilentlyContinue) {
                        $yamlContent = & yq eval -o=json $ConfigPath
                        $Settings = $yamlContent | ConvertFrom-Json -AsHashtable
                    } else {
                        throw "YAML support requires powershell-yaml module or yq command"
                    }
                }
                default {
                    throw "Unsupported configuration file format: $extension"
                }
            }
        }

        if ($Validate) {
            Test-ConfigurationSettings -Settings $Settings
        }

        # Apply configuration
        $script:ModuleConfiguration = $Settings
        Write-ModuleLog "Configuration applied successfully" "Success"
    }
    catch {
        Write-ModuleLog "Configuration error: $($_.Exception.Message)" "Error"
        throw
    }
}

function Test-ConfigurationSettings {
    <#
    .SYNOPSIS
        Validates configuration settings

    .DESCRIPTION
        Private function to validate configuration settings

    .PARAMETER Settings
        Settings hashtable to validate
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Settings
    )

    $errors = @()

    # Define required settings
    $requiredSettings = @("RequiredSetting1", "RequiredSetting2")

    foreach ($setting in $requiredSettings) {
        if (-not $Settings.ContainsKey($setting)) {
            $errors += "Missing required setting: $setting"
        }
    }

    # Validate setting values
    if ($Settings.ContainsKey("NumberSetting")) {
        if (-not ($Settings.NumberSetting -is [int] -and $Settings.NumberSetting -gt 0)) {
            $errors += "NumberSetting must be a positive integer"
        }
    }

    if ($errors.Count -gt 0) {
        throw "Configuration validation failed:`n  - $($errors -join "`n  - ")"
    }
}

# Initialize module
try {
    Test-ModulePrerequisites
    Write-ModuleLog "Module $script:ModuleName v$script:ModuleVersion loaded successfully" "Success"
}
catch {
    Write-ModuleLog "Module initialization failed: $($_.Exception.Message)" "Error"
    throw
}

# Export public functions
Export-ModuleMember -Function @(
    'Get-SampleData',
    'Set-SampleConfiguration'
)

# Optionally export variables (use sparingly)
# Export-ModuleMember -Variable @('ModuleVariable')

# Optionally export aliases
# Set-Alias -Name 'gsd' -Value 'Get-SampleData'
# Export-ModuleMember -Alias @('gsd')
```

### Function Documentation Standards

To ensure clarity without creating unnecessary overhead, documentation requirements are based on function visibility (public vs. private).

#### Public (Exported) Functions

All functions exported from a module using `Export-ModuleMember` **MUST** have a complete comment-based help block. This is critical for users and other scripts that will consume the module.

- **All sections are mandatory:** `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.OUTPUTS`, `.NOTES`, and `.LINK`.
- The `Get-SampleData` function in the template above is a good example of a well-documented public function.

#### Private (Internal) Functions

Functions that are not exported are considered internal helpers for the module. They require a less strict, but still informative, comment block.

- **Mandatory sections:** `.SYNOPSIS` and `.PARAMETER` (if the function takes parameters).
- **Recommended sections:** `.DESCRIPTION` and `.EXAMPLE` are highly recommended for complex helper functions.
- The `Test-ConfigurationSettings` function in the template above shows an example of a minimal block for a private function.

## Module Manifest (.psd1)

### Creating Module Manifests

Every module should have a corresponding manifest file that describes the module:

```powershell
#
# Module manifest for ModuleName
#
# Generated by: [Author Name]
# Generated on: [Date]
#

@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ModuleName.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module
    GUID = 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'  # Generate with New-Guid

    # Author of this module
    Author = '[Author Name]'

    # Company or vendor of this module
    CompanyName = '[Company/Organization]'

    # Copyright statement for this module
    Copyright = '(c) [Year] [Author/Company]. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Detailed description of what this module does and its purpose within the Proxmox VE toolkit.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module
    # CLRVersion = ''

    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry
    FunctionsToExport = @(
        'Get-SampleData',
        'Set-SampleConfiguration'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry
    AliasesToExport = @()

    # DSC resources to export from this module
    # DscResourcesToExport = @()

    # List of all modules packaged with this module
    # ModuleList = @()

    # List of all files packaged with this module
    FileList = @('ModuleName.psm1')

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Proxmox', 'VE', 'Toolkit', 'Automation', 'CrossPlatform')

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/your-repo/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/your-repo'

            # A URL to an icon representing this module.
            # IconUri = ''

            # ReleaseNotes of this module
            ReleaseNotes = 'Initial release of ModuleName module for Proxmox VE toolkit'

            # Prerelease string of this module
            # Prerelease = ''

            # Flag to indicate whether the module requires explicit user acceptance for install/update/save
            # RequireLicenseAcceptance = $false

            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }

    # HelpInfo URI of this module
    # HelpInfoURI = ''

    # Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
    # DefaultCommandPrefix = ''
}
```

## Module Organization Patterns

### When to Split Functions into Multiple Files

**Single Module File (.psm1)** - Use when:

- Module has < 10 functions
- All functions serve the same core purpose
- Total file size < 1000 lines
- Functions are tightly coupled

**Multiple Files with Dot-Sourcing** - Use when:

- Module has > 10 functions
- Functions can be logically grouped
- Individual function files > 100 lines
- Functions are loosely coupled

Example structure for large modules:

```
scripts/powershell/
├── MyLargeModule.psm1          # Main module file
├── MyLargeModule.psd1          # Module manifest
├── Private/                    # Private helper functions
│   ├── Helper-Functions.ps1
│   └── Validation-Functions.ps1
└── Public/                     # Public exported functions
    ├── Get-Functions.ps1
    ├── Set-Functions.ps1
    └── Test-Functions.ps1
```

Main module file with dot-sourcing:

```powershell
<# Module header documentation #>

$ErrorActionPreference = "Stop"

# Get public and private function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $Public.BaseName
```

### Module Dependencies

When modules depend on other modules:

```powershell
# In the dependent module
$RequiredModules = @(
    @{ ModuleName = 'Install-QualityTools'; ModuleVersion = '1.0.0' },
    @{ ModuleName = 'Invoke-QualityChecks'; RequiredVersion = '1.2.0' }
)

foreach ($module in $RequiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module.ModuleName)) {
        throw "Required module not found: $($module.ModuleName)"
    }

    try {
        Import-Module @module -Force -ErrorAction Stop
    }
    catch {
        throw "Failed to import required module $($module.ModuleName): $($_.Exception.Message)"
    }
}
```

## Advanced Module Patterns

### Module with Configuration

```powershell
# Module-level configuration
$script:ModuleConfig = @{
    DefaultTimeout = 30
    MaxRetries = 3
    LogLevel = "Info"
}

function Get-ModuleConfiguration {
    <#
    .SYNOPSIS
        Gets current module configuration
    #>
    return $script:ModuleConfig.Clone()
}

function Set-ModuleConfiguration {
    <#
    .SYNOPSIS
        Sets module configuration
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$DefaultTimeout,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Error", "Warning", "Info", "Debug")]
        [string]$LogLevel
    )

    if ($PSBoundParameters.ContainsKey('DefaultTimeout')) {
        $script:ModuleConfig.DefaultTimeout = $DefaultTimeout
    }

    if ($PSBoundParameters.ContainsKey('MaxRetries')) {
        $script:ModuleConfig.MaxRetries = $MaxRetries
    }

    if ($PSBoundParameters.ContainsKey('LogLevel')) {
        $script:ModuleConfig.LogLevel = $LogLevel
    }
}
```

### Module with State Management

```powershell
# Module state variables
$script:ModuleState = @{
    IsInitialized = $false
    LastOperation = $null
    OperationCount = 0
    StartTime = Get-Date
}

function Get-ModuleState {
    <#
    .SYNOPSIS
        Gets current module state
    #>
    return $script:ModuleState.Clone()
}

function Reset-ModuleState {
    <#
    .SYNOPSIS
        Resets module state
    #>
    $script:ModuleState.IsInitialized = $false
    $script:ModuleState.LastOperation = $null
    $script:ModuleState.OperationCount = 0
    $script:ModuleState.StartTime = Get-Date
}
```

## Testing Module Functions

### Unit Testing with Pester

Create test files alongside modules:

```
scripts/powershell/
├── MyModule.psm1
├── MyModule.psd1
└── Tests/
    └── MyModule.Tests.ps1
```

Example test file:

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../MyModule.psm1" -Force
}

Describe "MyModule" {
    Context "Get-SampleData" {
        It "Should return data when given valid path" {
            $result = Get-SampleData -InputPath $TestDrive
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should throw when given invalid path" {
            { Get-SampleData -InputPath "C:\NonExistent" } | Should -Throw
        }
    }

    Context "Set-SampleConfiguration" {
        It "Should accept valid configuration" {
            $config = @{ RequiredSetting1 = "Value1"; RequiredSetting2 = "Value2" }
            { Set-SampleConfiguration -Settings $config -Validate } | Should -Not -Throw
        }

        It "Should reject invalid configuration" {
            $config = @{ InvalidSetting = "Value" }
            { Set-SampleConfiguration -Settings $config -Validate } | Should -Throw
        }
    }
}
```

## Performance and Best Practices

### Memory Management

```powershell
# Use [System.GC]::Collect() sparingly and only when needed
function Clear-LargeDataStructures {
    param([object[]]$LargeArray)

    # Process data
    $result = $LargeArray | Process-Items

    # Clear large array if no longer needed
    $LargeArray = $null
    [System.GC]::Collect()

    return $result
}

# Use streaming where possible
function Get-LargeDataSet {
    param([string]$DataSource)

    # Instead of loading everything into memory
    # BAD: $allData = Get-AllData $DataSource

    # Stream the data
    Get-Data $DataSource | ForEach-Object {
        Process-DataItem $_
    }
}
```

### Error Boundaries

```powershell
function Invoke-SafeOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Operation,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3
    )

    $attempt = 0
    do {
        $attempt++
        try {
            return & $Operation
        }
        catch {
            Write-Warning "Attempt $attempt failed: $($_.Exception.Message)"

            if ($attempt -ge $MaxRetries) {
                throw "Operation failed after $MaxRetries attempts: $($_.Exception.Message)"
            }

            Start-Sleep -Seconds ([Math]::Pow(2, $attempt))  # Exponential backoff
        }
    } while ($attempt -lt $MaxRetries)
}
```

## Module Documentation

### Generate Module Documentation

```powershell
# Auto-generate module help
function Update-ModuleHelp {
    param([string]$ModulePath)

    Import-Module $ModulePath -Force
    $moduleName = (Get-Module | Where-Object { $_.Path -eq $ModulePath }).Name

    # Generate help files
    New-ExternalHelp -Path $ModulePath -OutputPath "$ModulePath\Help" -ModuleName $moduleName
}

# Get module information
function Get-ModuleInfo {
    param([string]$ModulePath)

    $manifest = Test-ModuleManifest $ModulePath
    return @{
        Name = $manifest.Name
        Version = $manifest.Version
        Functions = $manifest.ExportedFunctions.Keys
        Dependencies = $manifest.RequiredModules
        Author = $manifest.Author
        Description = $manifest.Description
    }
}
```
