<#
.SYNOPSIS
    Automated quality checks for PowerShell, shell scripts, and YAML files

.DESCRIPTION
    Provides comprehensive quality checking capabilities including:
    - PowerShell script analysis with PSScriptAnalyzer
    - Shell script validation with shellcheck
    - YAML file validation and formatting checks
    - Automated fix suggestions and reporting

.EXAMPLE
    Import-Module ./scripts/powershell/Invoke-QualityChecks.psm1
    Invoke-AllQualityCheck

.EXAMPLE
    Test-PowerShellScript -Path "scripts/powershell/" -Recurse -Fix
    Test-ShellScript -Path "scripts/shell/"
#>

# Set consistent error handling
$ErrorActionPreference = "Stop"

function Test-PowerShellScript {
    <#
    .SYNOPSIS
        Runs PSScriptAnalyzer on PowerShell scripts

    .PARAMETER Path
        Path to analyze (file or directory)

    .PARAMETER Recurse
        Recursively analyze subdirectories

    .PARAMETER Fix
        Attempt to auto-fix issues where possible

    .PARAMETER Severity
        Minimum severity level to report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [switch]$Recurse,
        [switch]$Fix,
        
        [ValidateSet("Error", "Warning", "Information")]
        [string]$Severity = "Warning"
    )

    Write-Information "🔍 Analyzing PowerShell scripts..." -InformationAction Continue

    try {
        # Ensure PSScriptAnalyzer is available
        Import-Module PSScriptAnalyzer -ErrorAction Stop

        if (-not (Test-Path $Path)) {
            Write-Warning "⚠️ Path not found: $Path"
            return $false
        }

        # Get PowerShell files
        $files = if (Test-Path $Path -PathType Leaf) {
            @($Path)
        } else {
            $searchPath = if ($Recurse) { 
                Get-ChildItem -Path $Path -Include "*.ps1", "*.psm1", "*.psd1" -Recurse 
            } else { 
                Get-ChildItem -Path $Path -Include "*.ps1", "*.psm1", "*.psd1" 
            }
            $searchPath
        }

        if (-not $files) {
            Write-Information "ℹ️ No PowerShell files found in: $Path" -InformationAction Continue
            return $true
        }

        $totalIssues = 0
        $filesWithIssues = 0

        foreach ($file in $files) {
            Write-Information "📄 Checking: $($file.Name)" -InformationAction Continue
            
            $results = Invoke-ScriptAnalyzer -Path $file.FullName -Severity $Severity

            if ($results) {
                $filesWithIssues++
                $totalIssues += $results.Count
                
                Write-Information "  ❌ $($results.Count) issue(s) found:" -InformationAction Continue
                
                foreach ($result in $results) {
                    # Remove unused color variable since we're using Write-Information
                    Write-Information "    [$($result.Severity)] Line $($result.Line): $($result.Message)" -InformationAction Continue
                    Write-Information "      Rule: $($result.RuleName)" -InformationAction Continue
                    
                    if ($result.SuggestedCorrections) {
                        Write-Information "      Suggestion: $($result.SuggestedCorrections[0].Description)" -InformationAction Continue
                    }
                }
            } else {
                Write-Information "  ✅ No issues found" -InformationAction Continue
            }
        }

        # Summary
        Write-Information "" -InformationAction Continue
        Write-Information "📊 PowerShell Analysis Summary:" -InformationAction Continue
        Write-Information "  Files analyzed: $($files.Count)" -InformationAction Continue
        Write-Information "  Files with issues: $filesWithIssues" -InformationAction Continue
        Write-Information "  Total issues: $totalIssues" -InformationAction Continue

        return $totalIssues -eq 0
    } catch {
        Write-Error "❌ PowerShell analysis failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-ShellScript {
    <#
    .SYNOPSIS
        Runs shellcheck on shell scripts

    .PARAMETER Path
        Path to analyze (file or directory)

    .PARAMETER Recurse
        Recursively analyze subdirectories

    .PARAMETER Severity
        Minimum severity level to report
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [switch]$Recurse,
        
        [ValidateSet("error", "warning", "info", "style")]
        [string]$Severity = "warning"
    )

    Write-Information "🔍 Analyzing shell scripts..." -InformationAction Continue

    try {
        # Check if shellcheck is available
        if (-not (Get-Command shellcheck -ErrorAction SilentlyContinue)) {
            Write-Warning "⚠️ shellcheck not found. Please install it first."
            return $false
        }

        if (-not (Test-Path $Path)) {
            Write-Warning "⚠️ Path not found: $Path"
            return $false
        }

        # Get shell script files
        $files = if (Test-Path $Path -PathType Leaf) {
            @($Path)
        } else {
            $searchPath = if ($Recurse) { 
                Get-ChildItem -Path $Path -Include "*.sh", "*.bash", "*.zsh" -Recurse 
            } else { 
                Get-ChildItem -Path $Path -Include "*.sh", "*.bash", "*.zsh" 
            }
            $searchPath
        }

        if (-not $files) {
            Write-Information "ℹ️ No shell script files found in: $Path" -InformationAction Continue
            return $true
        }

        $allPassed = $true

        foreach ($file in $files) {
            Write-Information "📄 Checking: $($file.Name)" -InformationAction Continue
            
            # Run shellcheck
            $result = & shellcheck --severity=$Severity --format=json $file.FullName 2>&1
            
            if ($LASTEXITCODE -eq 0 -and -not $result) {
                Write-Information "  ✅ No issues found" -InformationAction Continue
            } else {
                $allPassed = $false
                
                if ($result) {
                    try {
                        $issues = $result | ConvertFrom-Json
                        Write-Information "  ❌ $($issues.Count) issue(s) found:" -InformationAction Continue
                        
                        foreach ($issue in $issues) {
                            Write-Information "    [$($issue.level)] Line $($issue.line): $($issue.message)" -InformationAction Continue
                            Write-Information "      Code: SC$($issue.code)" -InformationAction Continue
                        }
                    } catch {
                        # If JSON parsing fails, show raw output
                        Write-Information "  ❌ Issues found:" -InformationAction Continue
                        Write-Information "    $result" -InformationAction Continue
                    }
                } else {
                    Write-Information "  ❌ shellcheck failed with exit code: $LASTEXITCODE" -InformationAction Continue
                }
            }
        }

        Write-Information "" -InformationAction Continue
        Write-Information "📊 Shell Script Analysis Summary:" -InformationAction Continue
        Write-Information "  Files analyzed: $($files.Count)" -InformationAction Continue
        Write-Information "  Result: $(if ($allPassed) { "✅ All files passed" } else { "❌ Issues found" })" -InformationAction Continue

        return $allPassed
    } catch {
        Write-Error "❌ Shell script analysis failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-YAMLFile {
    <#
    .SYNOPSIS
        Validates YAML files for syntax and formatting

    .PARAMETER Path
        Path to analyze (file or directory)

    .PARAMETER Recurse
        Recursively analyze subdirectories
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [switch]$Recurse
    )

    Write-Information "🔍 Validating YAML files..." -InformationAction Continue

    try {
        if (-not (Test-Path $Path)) {
            Write-Warning "⚠️ Path not found: $Path"
            return $false
        }

        # Get YAML files
        $files = if (Test-Path $Path -PathType Leaf) {
            @($Path)
        } else {
            $searchPath = if ($Recurse) { 
                Get-ChildItem -Path $Path -Include "*.yaml", "*.yml" -Recurse 
            } else { 
                Get-ChildItem -Path $Path -Include "*.yaml", "*.yml" 
            }
            $searchPath
        }

        if (-not $files) {
            Write-Information "ℹ️ No YAML files found in: $Path" -InformationAction Continue
            return $true
        }

        $allValid = $true

        foreach ($file in $files) {
            Write-Information "📄 Validating: $($file.Name)" -InformationAction Continue
            
            # Try yq first, then fallback to PowerShell YAML parsing
            if (Get-Command yq -ErrorAction SilentlyContinue) {
                $result = & yq validate $file.FullName 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Information "  ✅ Valid YAML" -InformationAction Continue
                } else {
                    $allValid = $false
                    Write-Information "  ❌ Invalid YAML:" -InformationAction Continue
                    Write-Information "    $result" -InformationAction Continue
                }
            } else {
                # Fallback to basic YAML parsing
                try {
                    Import-Module powershell-yaml -ErrorAction SilentlyContinue
                    if (Get-Module powershell-yaml) {
                        $content = Get-Content $file.FullName -Raw
                        $null = ConvertFrom-Yaml $content
                        Write-Information "  ✅ Valid YAML" -InformationAction Continue
                    } else {
                        # Basic validation - check for common YAML syntax issues
                        $content = Get-Content $file.FullName
                        $hasErrors = $false
                        
                        for ($i = 0; $i -lt $content.Length; $i++) {
                            $line = $content[$i]
                            
                            # Check for tab characters
                            if ($line -match '\t') {
                                Write-Information "  ⚠️ Line $($i + 1): Contains tab characters (should use spaces)" -InformationAction Continue
                                $hasErrors = $true
                            }
                            
                            # Check for common syntax issues
                            if ($line -match ':\s*\[.*[^]]') {
                                Write-Information "  ⚠️ Line $($i + 1): Possible unclosed array" -InformationAction Continue
                                $hasErrors = $true
                            }
                        }
                        
                        if (-not $hasErrors) {
                            Write-Information "  ✅ Basic validation passed" -InformationAction Continue
                        } else {
                            $allValid = $false
                        }
                    }
                } catch {
                    $allValid = $false
                    Write-Information "  ❌ YAML parsing error: $($_.Exception.Message)" -InformationAction Continue
                }
            }
        }

        Write-Information "" -InformationAction Continue
        Write-Information "📊 YAML Validation Summary:" -InformationAction Continue
        Write-Information "  Files analyzed: $($files.Count)" -InformationAction Continue
        Write-Information "  Result: $(if ($allValid) { "✅ All files valid" } else { "❌ Issues found" })" -InformationAction Continue

        return $allValid
    } catch {
        Write-Error "❌ YAML validation failed: $($_.Exception.Message)"
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
    
    # Check if we can use npx (requires npm to be installed)
    if ((Get-Command npm -ErrorAction SilentlyContinue) -and (Get-Command npx -ErrorAction SilentlyContinue)) {
        return @("npx", "--yes", "markdownlint-cli")
    }
    
    # Fall back to global installation
    if (Get-Command markdownlint -ErrorAction SilentlyContinue) {
        return @("markdownlint")
    }
    
    return $null
}

function Test-MarkdownFile {
    <#
    .SYNOPSIS
        Validates Markdown files for style and formatting

    .PARAMETER Path
        Path to analyze (file or directory)

    .PARAMETER Recurse
        Recursively analyze subdirectories
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [switch]$Recurse
    )

    Write-Information "📝 Validating Markdown files..." -InformationAction Continue

    try {
        if (-not (Test-Path $Path)) {
            Write-Warning "⚠️ Path not found: $Path"
            return $false
        }

        # Check if markdownlint is available
        $markdownlintCmd = Get-MarkdownLintCommand
        if (-not $markdownlintCmd) {
            Write-Warning "⚠️ markdownlint not available. Possible solutions:"
            Write-Warning "   1. Run Install-AllQualityTool to install via npx"
            Write-Warning "   2. Install Node.js if npm/npx are missing"
            Write-Warning "   3. Install markdownlint globally: npm install -g markdownlint-cli"
            return $false
        }

        # Get Markdown files
        $files = if (Test-Path $Path -PathType Leaf) {
            @($Path)
        } else {
            $searchPath = if ($Recurse) { 
                Get-ChildItem -Path $Path -Include "*.md", "*.markdown", "*.instructions.md" -Recurse 
            } else { 
                Get-ChildItem -Path $Path -Include "*.md", "*.markdown", "*.instructions.md" 
            }
            $searchPath
        }

        if (-not $files) {
            Write-Information "ℹ️ No Markdown files found in: $Path" -InformationAction Continue
            return $true
        }

        $allPassed = $true

        foreach ($file in $files) {
            Write-Information "📄 Linting: $($file.Name)" -InformationAction Continue
            
            # Run markdownlint with appropriate command
            try {
                $result = if ($markdownlintCmd -is [array]) {
                    # Handle npx case: @("npx", "--yes", "markdownlint-cli")
                    & $markdownlintCmd[0] $markdownlintCmd[1] $markdownlintCmd[2] $file.FullName 2>&1
                } else {
                    # Handle local or global case: single command
                    & $markdownlintCmd $file.FullName 2>&1
                }
            } catch {
                Write-Warning "Failed to run markdownlint on $($file.Name): $($_.Exception.Message)"
                continue
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Information "  ✅ No issues found" -InformationAction Continue
            } else {
                $allPassed = $false
                Write-Information "  ❌ Issues found:" -InformationAction Continue
                
                # Parse and display markdownlint output
                $issues = $result -split "`n" | Where-Object { $_ -and $_ -notmatch "^$" }
                foreach ($issue in $issues) {
                    if ($issue -match "^(.+):(\d+):\d*\s*(.+)$") {
                        $lineNumber = $Matches[2]
                        $message = $Matches[3]
                        Write-Information "    Line $lineNumber`: $message" -InformationAction Continue
                    } else {
                        Write-Information "    $issue" -InformationAction Continue
                    }
                }
            }
        }

        Write-Information "" -InformationAction Continue
        Write-Information "📊 Markdown Linting Summary:" -InformationAction Continue
        Write-Information "  Files analyzed: $($files.Count)" -InformationAction Continue
        Write-Information "  Result: $(if ($allPassed) { "✅ All files passed" } else { "❌ Issues found" })"

        return $allPassed
    } catch {
        Write-Error "❌ Markdown validation failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-AllQualityCheck {
    <#
    .SYNOPSIS
        Runs all quality checks on the project

    .PARAMETER Path
        Root path to analyze (defaults to current directory)

    .PARAMETER ExitOnFailure
        Exit with error code if any checks fail
    #>
    [CmdletBinding()]
    param(
        [string]$Path = ".",
        [switch]$ExitOnFailure
    )

    Write-Information "🚀 Running all quality checks..." -InformationAction Continue
    Write-Information "" -InformationAction Continue

    $results = @{}

    # PowerShell Scripts
    if (Test-Path (Join-Path $Path "scripts") -PathType Container) {
        $results.PowerShell = Test-PowerShellScript -Path (Join-Path $Path "scripts") -Recurse
    } else {
        Write-Information "ℹ️ No scripts directory found, skipping PowerShell analysis" -InformationAction Continue
        $results.PowerShell = $true
    }

    Write-Information "" -InformationAction Continue

    # Shell Scripts
    $shellScriptPaths = @("scripts/shell", "scripts", ".")
    $shellScriptPath = $null
    foreach ($testPath in $shellScriptPaths) {
        $fullPath = Join-Path $Path $testPath
        if (Test-Path $fullPath -PathType Container) {
            $shellFiles = Get-ChildItem -Path $fullPath -Include "*.sh", "*.bash", "*.zsh" -Recurse -ErrorAction SilentlyContinue
            if ($shellFiles) {
                $shellScriptPath = $fullPath
                break
            }
        }
    }

    if ($shellScriptPath) {
        $results.ShellScripts = Test-ShellScript -Path $shellScriptPath -Recurse
    } else {
        Write-Information "ℹ️ No shell scripts found, skipping shell script analysis" -InformationAction Continue
        $results.ShellScripts = $true
    }

    Write-Information "" -InformationAction Continue

    # YAML Files
    if (Test-Path (Join-Path $Path "configs") -PathType Container) {
        $results.YAML = Test-YAMLFile -Path (Join-Path $Path "configs") -Recurse
    } else {
        Write-Information "ℹ️ No configs directory found, skipping YAML validation" -InformationAction Continue
        $results.YAML = $true
    }

    Write-Information "" -InformationAction Continue

    # Markdown Files
    $markdownPaths = @(".github/instructions", "docs", ".")
    $markdownPath = $null
    foreach ($testPath in $markdownPaths) {
        $fullPath = Join-Path $Path $testPath
        if (Test-Path $fullPath -PathType Container) {
            $markdownFiles = Get-ChildItem -Path $fullPath -Include "*.md", "*.markdown", "*.instructions.md" -Recurse -ErrorAction SilentlyContinue
            if ($markdownFiles) {
                $markdownPath = $fullPath
                break
            }
        }
    }

    if ($markdownPath) {
        $results.Markdown = Test-MarkdownFile -Path $markdownPath -Recurse
    } else {
        Write-Information "ℹ️ No markdown files found, skipping markdown linting" -InformationAction Continue
        $results.Markdown = $true
    }

    # Summary
    Write-Information "" -InformationAction Continue
    Write-Information "📊 Quality Check Summary:" -InformationAction Continue
    Write-Information "========================" -InformationAction Continue

    $allPassed = $true
    foreach ($check in $results.GetEnumerator()) {
        $status = if ($check.Value) { "✅ PASSED" } else { "❌ FAILED"; $allPassed = $false }
        $color = if ($check.Value) { "Green" } else { "Red" }
        Write-Information "  $($check.Key): $status" -InformationAction Continue -ForegroundColor $color
    }

    Write-Information "" -InformationAction Continue
    if ($allPassed) {
        Write-Information "🎉 All quality checks passed!" -InformationAction Continue
    } else {
        Write-Information "⚠️ Some quality checks failed. Please review the issues above." -InformationAction Continue
        
        if ($ExitOnFailure) {
            exit 1
        }
    }

    return $allPassed
}

function Invoke-QuickFix {
    <#
    .SYNOPSIS
        Applies automatic fixes where possible

    .PARAMETER Path
        Root path to fix (defaults to current directory)
    #>
    [CmdletBinding()]
    param(
        [string]$Path = "."
    )

    Write-Information "🔧 Applying quick fixes..." -InformationAction Continue

    # PowerShell formatting (basic fixes)
    Write-Information "📝 Applying PowerShell fixes..." -InformationAction Continue
    
    $psFiles = Get-ChildItem -Path $Path -Include "*.ps1", "*.psm1" -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $psFiles) {
        try {
            $content = Get-Content $file.FullName -Raw
            
            # Remove trailing whitespace
            $content = $content -replace "[ 	]+(\r?\n)", "$1"
            
            # Ensure file ends with newline
            if (-not $content.EndsWith("`n")) {
                $content += "`n"
            }
            
            Set-Content -Path $file.FullName -Value $content -NoNewline
            Write-Information "  ✅ Fixed: $($file.Name)" -InformationAction Continue
        } catch {
            Write-Information "  ⚠️ Could not fix: $($file.Name) - $($_.Exception.Message)" -InformationAction Continue
        }
    }

    Write-Information "🎉 Quick fixes applied!" -InformationAction Continue
}

# Export functions
Export-ModuleMember -Function @(
    'Test-PowerShellScript',
    'Test-ShellScript',
    'Test-YAMLFile',
    'Test-MarkdownFile',
    'Invoke-AllQualityCheck',
    'Invoke-QuickFix'
)