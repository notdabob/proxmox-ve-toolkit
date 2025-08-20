---
applyTo: ["scripts/**/*.ps1", "scripts/**/*.psm1", "scripts/**/*.psd1"]
---

# PowerShell Documentation Standards

## Overview

This file establishes **unified documentation requirements** across all PowerShell file types to ensure
consistency and maintainability. These standards supplement the specialized instruction files.

## Comment Block Requirements by Context

### Public/Exported Functions (MANDATORY - All Sections)

All functions exported from modules or used as main entry points in scripts MUST include complete documentation:

```powershell
<#
.SYNOPSIS
    [ONE LINE] Brief, action-oriented description of what the function does.

.DESCRIPTION
    [2-4 LINES] Detailed explanation including:
    - What the function accomplishes
    - When to use it
    - Any important behavioral notes or side effects

.PARAMETER ParameterName
    [Type] [Required/Optional] - Clear description of parameter purpose.
    Valid values: Value1, Value2, Value3 (if constrained)
    Default: DefaultValue (if applicable)
    Example: "DatabasePath" or @("Server1", "Server2")

.EXAMPLE
    PS C:\> FunctionName -Parameter "value"
    Brief description of what this example demonstrates.

.EXAMPLE
    PS C:\> FunctionName -Parameter "value" -AnotherParam
    Description of a different usage scenario.

.OUTPUTS
    [System.Type]
    Description of what the function returns. Use "None" if no return value.

.NOTES
    File Name      : FileName.ps1/.psm1
    Author         : [Author Name]
    Prerequisite   : PowerShell 7.0+, [Additional Dependencies]
    Copyright      : [Copyright Info]
    [Additional notes, limitations, or important information]

.LINK
    https://github.com/your-repo/docs/path/to/relevant/documentation
#>
```

### Private/Internal Functions (MINIMUM Required)

Functions used internally within modules require minimal but informative documentation:

```powershell
<#
.SYNOPSIS
    [ONE LINE] Brief description of internal function purpose.

.PARAMETER ParameterName
    [Type] [Required/Optional] - Description of each parameter.

.NOTES
    Internal helper function - not exported.
    [Any important implementation notes]
#>
```

### Script-Level Documentation (MANDATORY)

Every `.ps1` script file must have a complete header following the public function standard above.

## Parameter Documentation Format

### Standard Parameter Block Template

```powershell
.PARAMETER ParameterName
    [System.String] [Required] - Primary input parameter for the operation.
    Valid values: "Option1", "Option2", "Option3"
    Example: "C:\Path\To\File.txt"

.PARAMETER OptionalParam
    [System.Int32] [Optional] - Timeout value in seconds.
    Default: 30
    Range: 1-3600
    Example: 60

.PARAMETER SwitchParam
    [System.Management.Automation.SwitchParameter] [Optional] - Enable verbose output.
    When present, enables detailed logging and progress information.
```

### Parameter Documentation Rules

1. **Type Declaration**: Always include `[System.Type]` in square brackets
2. **Required/Optional**: Explicitly state parameter requirement level
3. **Valid Values**: List constraints, ranges, or valid options
4. **Default Values**: State defaults for optional parameters
5. **Examples**: Provide realistic example values
6. **Behavior Notes**: Explain any special parameter behavior

## Cross-Reference Standards

### Module-to-Module Dependencies

When functions depend on other modules:

```powershell
.NOTES
    Dependencies: Install-QualityTools.psm1, Write-Log.psm1
    Prerequisite: Run Install-AllQualityTool before using this function
    Related: Get-ModuleConfiguration, Set-ModuleConfiguration
```

### Error Handling Documentation

Document expected errors and their handling:

```powershell
.NOTES
    Error Handling:
    - FileNotFoundException: When specified path doesn't exist
    - UnauthorizedAccessException: When insufficient permissions
    - Custom exceptions: Re-thrown with context

    All errors are logged via Write-LogMessage before re-throwing.
```

## Quality Validation

### Documentation Quality Checks

All PowerShell files must pass these documentation validation criteria:

1. **Completeness**: All required sections present
2. **Consistency**: Parameter types and descriptions match actual implementation
3. **Accuracy**: Examples must be runnable and produce expected results
4. **Links**: All .LINK URLs must be valid and relevant

### Automated Validation

Include documentation checks in quality validation:

```powershell
# Check for required documentation sections
function Test-FunctionDocumentation {
    param([string]$FunctionText)

    $requiredSections = @('.SYNOPSIS', '.DESCRIPTION', '.EXAMPLE', '.OUTPUTS')
    $missingSections = @()

    foreach ($section in $requiredSections) {
        if ($FunctionText -notmatch $section) {
            $missingSections += $section
        }
    }

    return $missingSections.Count -eq 0
}
```

## Integration with Existing Files

### How This Supplements Other Instructions

- **powershell-scripts.instructions.md**: References this file for comment block details
- **powershell-modules.instructions.md**: Uses these standards for function documentation
- **powershell-architecture.instructions.md**: Applies these standards across architectural decisions

### Enforcement Priority

1. **New Code**: Must follow these standards completely
2. **Existing Code**: Update documentation when modifying functions
3. **Quality Gates**: Documentation completeness checked in CI/CD pipeline
4. **Reviews**: All pull requests validate documentation standards

## Examples by File Type

### Script Example (.ps1)

See `powershell-scripts.instructions.md` for complete script templates using these documentation standards.

### Module Example (.psm1)

See `powershell-modules.instructions.md` for complete module templates using these documentation standards.

### Integration with Quality Tools

PSScriptAnalyzer rules that support documentation requirements:

- `PSProvideCommentHelp`: Ensures functions have help documentation
- `PSReviewUnusedParameter`: Validates documented parameters are used
- `PSUseShouldProcessForStateChangingFunctions`: Ensures ShouldProcess is documented

## Migration Guide for Existing Code

### Quick Assessment

Run this command to find functions missing required documentation:

```powershell
# Find functions missing complete documentation
Get-ChildItem -Path "scripts/" -Filter "*.psm1" -Recurse |
    ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        if ($content -match 'function\s+(\w+-\w+)' -and
            $content -notmatch '\.SYNOPSIS|\.DESCRIPTION|\.EXAMPLE') {
            Write-Output "$($_.Name): $($Matches[1]) - Missing documentation"
        }
    }
```

### Gradual Implementation

1. **Phase 1**: Add minimal documentation to all exported functions
2. **Phase 2**: Complete full documentation for public APIs
3. **Phase 3**: Add comprehensive documentation to internal functions
4. **Phase 4**: Integrate documentation validation into CI/CD pipeline
