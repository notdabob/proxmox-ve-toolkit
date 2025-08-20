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
    Invoke-AllQualityChecks

.EXAMPLE
    Test-PowerShellScripts -Path "scripts/" -Fix
    Test-ShellScripts -Path "scripts/shell/"
#>

# Set consistent error handling
$ErrorActionPreference = "Stop"

function Test-PowerShellScripts {
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

    Write-Host "🔍 Analyzing PowerShell scripts..." -ForegroundColor Blue

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
            Write-Host "ℹ️ No PowerShell files found in: $Path" -ForegroundColor Yellow
            return $true
        }

        $totalIssues = 0
        $filesWithIssues = 0

        foreach ($file in $files) {
            Write-Host "📄 Checking: $($file.Name)" -ForegroundColor Gray
            
            $results = Invoke-ScriptAnalyzer -Path $file.FullName -Severity $Severity

            if ($results) {
                $filesWithIssues++
                $totalIssues += $results.Count
                
                Write-Host "  ❌ $($results.Count) issue(s) found:" -ForegroundColor Red
                
                foreach ($result in $results) {
                    $severityColor = switch ($result.Severity) {
                        "Error" { "Red" }
                        "Warning" { "Yellow" }
                        "Information" { "Cyan" }
                        default { "White" }
                    }
                    
                    Write-Host "    [$($result.Severity)] Line $($result.Line): $($result.Message)" -ForegroundColor $severityColor
                    Write-Host "      Rule: $($result.RuleName)" -ForegroundColor Gray
                    
                    if ($result.SuggestedCorrections) {
                        Write-Host "      Suggestion: $($result.SuggestedCorrections[0].Description)" -ForegroundColor Green
                    }
                }
            } else {
                Write-Host "  ✅ No issues found" -ForegroundColor Green
            }
        }

        # Summary
        Write-Host ""
        Write-Host "📊 PowerShell Analysis Summary:" -ForegroundColor Cyan
        Write-Host "  Files analyzed: $($files.Count)"
        Write-Host "  Files with issues: $filesWithIssues"
        Write-Host "  Total issues: $totalIssues"

        return $totalIssues -eq 0
    } catch {
        Write-Error "❌ PowerShell analysis failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-ShellScripts {
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

    Write-Host "🔍 Analyzing shell scripts..." -ForegroundColor Blue

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
            Write-Host "ℹ️ No shell script files found in: $Path" -ForegroundColor Yellow
            return $true
        }

        $allPassed = $true

        foreach ($file in $files) {
            Write-Host "📄 Checking: $($file.Name)" -ForegroundColor Gray
            
            # Run shellcheck
            $result = & shellcheck --severity=$Severity --format=json $file.FullName 2>&1
            
            if ($LASTEXITCODE -eq 0 -and -not $result) {
                Write-Host "  ✅ No issues found" -ForegroundColor Green
            } else {
                $allPassed = $false
                
                if ($result) {
                    try {
                        $issues = $result | ConvertFrom-Json
                        Write-Host "  ❌ $($issues.Count) issue(s) found:" -ForegroundColor Red
                        
                        foreach ($issue in $issues) {
                            $severityColor = switch ($issue.level) {
                                "error" { "Red" }
                                "warning" { "Yellow" }
                                "info" { "Cyan" }
                                "style" { "Magenta" }
                                default { "White" }
                            }
                            
                            Write-Host "    [$($issue.level)] Line $($issue.line): $($issue.message)" -ForegroundColor $severityColor
                            Write-Host "      Code: SC$($issue.code)" -ForegroundColor Gray
                        }
                    } catch {
                        # If JSON parsing fails, show raw output
                        Write-Host "  ❌ Issues found:" -ForegroundColor Red
                        Write-Host "    $result" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  ❌ shellcheck failed with exit code: $LASTEXITCODE" -ForegroundColor Red
                }
            }
        }

        Write-Host ""
        Write-Host "📊 Shell Script Analysis Summary:" -ForegroundColor Cyan
        Write-Host "  Files analyzed: $($files.Count)"
        Write-Host "  Result: $(if ($allPassed) { "✅ All files passed" } else { "❌ Issues found" })"

        return $allPassed
    } catch {
        Write-Error "❌ Shell script analysis failed: $($_.Exception.Message)"
        return $false
    }
}

function Test-YAMLFiles {
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

    Write-Host "🔍 Validating YAML files..." -ForegroundColor Blue

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
            Write-Host "ℹ️ No YAML files found in: $Path" -ForegroundColor Yellow
            return $true
        }

        $allValid = $true

        foreach ($file in $files) {
            Write-Host "📄 Validating: $($file.Name)" -ForegroundColor Gray
            
            # Try yq first, then fallback to PowerShell YAML parsing
            if (Get-Command yq -ErrorAction SilentlyContinue) {
                $result = & yq validate $file.FullName 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✅ Valid YAML" -ForegroundColor Green
                } else {
                    $allValid = $false
                    Write-Host "  ❌ Invalid YAML:" -ForegroundColor Red
                    Write-Host "    $result" -ForegroundColor Yellow
                }
            } else {
                # Fallback to basic YAML parsing
                try {
                    Import-Module powershell-yaml -ErrorAction SilentlyContinue
                    if (Get-Module powershell-yaml) {
                        $content = Get-Content $file.FullName -Raw
                        $null = ConvertFrom-Yaml $content
                        Write-Host "  ✅ Valid YAML" -ForegroundColor Green
                    } else {
                        # Basic validation - check for common YAML syntax issues
                        $content = Get-Content $file.FullName
                        $hasErrors = $false
                        
                        for ($i = 0; $i -lt $content.Length; $i++) {
                            $line = $content[$i]
                            
                            # Check for tab characters
                            if ($line -match '\t') {
                                Write-Host "  ⚠️ Line $($i + 1): Contains tab characters (should use spaces)" -ForegroundColor Yellow
                                $hasErrors = $true
                            }
                            
                            # Check for common syntax issues
                            if ($line -match ':\s*\[.*[^]]$') {
                                Write-Host "  ⚠️ Line $($i + 1): Possible unclosed array" -ForegroundColor Yellow
                                $hasErrors = $true
                            }
                        }
                        
                        if (-not $hasErrors) {
                            Write-Host "  ✅ Basic validation passed" -ForegroundColor Green
                        } else {
                            $allValid = $false
                        }
                    }
                } catch {
                    $allValid = $false
                    Write-Host "  ❌ YAML parsing error: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }

        Write-Host ""
        Write-Host "📊 YAML Validation Summary:" -ForegroundColor Cyan
        Write-Host "  Files analyzed: $($files.Count)"
        Write-Host "  Result: $(if ($allValid) { "✅ All files valid" } else { "❌ Issues found" })"

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
        return $localMarkdownlint
    }
    
    # Check if we can use npx
    if (Get-Command npx -ErrorAction SilentlyContinue) {
        try {
            $testOutput = npx --yes markdownlint-cli --version 2>$null
            if ($testOutput) {
                return "npx", "--yes", "markdownlint-cli"
            }
        } catch {
            # npx test failed
        }
    }
    
    # Fall back to global installation
    if (Get-Command markdownlint -ErrorAction SilentlyContinue) {
        return "markdownlint"
    }
    
    return $null
}

function Test-MarkdownFiles {
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

    Write-Host "📝 Validating Markdown files..." -ForegroundColor Blue

    try {
        if (-not (Test-Path $Path)) {
            Write-Warning "⚠️ Path not found: $Path"
            return $false
        }

        # Check if markdownlint is available
        $markdownlintCmd = Get-MarkdownLintCommand
        if (-not $markdownlintCmd) {
            Write-Warning "⚠️ markdownlint not found. Run Install-AllQualityTools to install it."
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
            Write-Host "ℹ️ No Markdown files found in: $Path" -ForegroundColor Yellow
            return $true
        }

        $allPassed = $true

        foreach ($file in $files) {
            Write-Host "📄 Linting: $($file.Name)" -ForegroundColor Gray
            
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
                Write-Host "  ✅ No issues found" -ForegroundColor Green
            } else {
                $allPassed = $false
                Write-Host "  ❌ Issues found:" -ForegroundColor Red
                
                # Parse and display markdownlint output
                $issues = $result -split "`n" | Where-Object { $_ -and $_ -notmatch "^$" }
                foreach ($issue in $issues) {
                    if ($issue -match "^(.+):(\d+):\d*\s*(.+)$") {
                        $lineNumber = $Matches[2]
                        $message = $Matches[3]
                        Write-Host "    Line $lineNumber`: $message" -ForegroundColor Yellow
                    } else {
                        Write-Host "    $issue" -ForegroundColor Yellow
                    }
                }
            }
        }

        Write-Host ""
        Write-Host "📊 Markdown Linting Summary:" -ForegroundColor Cyan
        Write-Host "  Files analyzed: $($files.Count)"
        Write-Host "  Result: $(if ($allPassed) { "✅ All files passed" } else { "❌ Issues found" })"

        return $allPassed
    } catch {
        Write-Error "❌ Markdown validation failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-AllQualityChecks {
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

    Write-Host "🚀 Running all quality checks..." -ForegroundColor Cyan
    Write-Host ""

    $results = @{}

    # PowerShell Scripts
    if (Test-Path (Join-Path $Path "scripts") -PathType Container) {
        $results.PowerShell = Test-PowerShellScripts -Path (Join-Path $Path "scripts") -Recurse
    } else {
        Write-Host "ℹ️ No scripts directory found, skipping PowerShell analysis" -ForegroundColor Yellow
        $results.PowerShell = $true
    }

    Write-Host ""

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
        $results.ShellScripts = Test-ShellScripts -Path $shellScriptPath -Recurse
    } else {
        Write-Host "ℹ️ No shell scripts found, skipping shell script analysis" -ForegroundColor Yellow
        $results.ShellScripts = $true
    }

    Write-Host ""

    # YAML Files
    if (Test-Path (Join-Path $Path "configs") -PathType Container) {
        $results.YAML = Test-YAMLFiles -Path (Join-Path $Path "configs") -Recurse
    } else {
        Write-Host "ℹ️ No configs directory found, skipping YAML validation" -ForegroundColor Yellow
        $results.YAML = $true
    }

    Write-Host ""

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
        $results.Markdown = Test-MarkdownFiles -Path $markdownPath -Recurse
    } else {
        Write-Host "ℹ️ No markdown files found, skipping markdown linting" -ForegroundColor Yellow
        $results.Markdown = $true
    }

    # Summary
    Write-Host ""
    Write-Host "📊 Quality Check Summary:" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan

    $allPassed = $true
    foreach ($check in $results.GetEnumerator()) {
        $status = if ($check.Value) { "✅ PASSED" } else { "❌ FAILED"; $allPassed = $false }
        $color = if ($check.Value) { "Green" } else { "Red" }
        Write-Host "  $($check.Key): $status" -ForegroundColor $color
    }

    Write-Host ""
    if ($allPassed) {
        Write-Host "🎉 All quality checks passed!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Some quality checks failed. Please review the issues above." -ForegroundColor Yellow
        
        if ($ExitOnFailure) {
            exit 1
        }
    }

    return $allPassed
}

function Invoke-QuickFixes {
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

    Write-Host "🔧 Applying quick fixes..." -ForegroundColor Cyan

    # PowerShell formatting (basic fixes)
    Write-Host "📝 Applying PowerShell fixes..." -ForegroundColor Blue
    
    $psFiles = Get-ChildItem -Path $Path -Include "*.ps1", "*.psm1" -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $psFiles) {
        try {
            $content = Get-Content $file.FullName -Raw
            
            # Remove trailing whitespace
            $content = $content -replace '[ \t]+(\r?\n)', '$1'
            
            # Ensure file ends with newline
            if (-not $content.EndsWith("`n")) {
                $content += "`n"
            }
            
            Set-Content -Path $file.FullName -Value $content -NoNewline
            Write-Host "  ✅ Fixed: $($file.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠️ Could not fix: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    Write-Host "🎉 Quick fixes applied!" -ForegroundColor Green
}

# Export functions
Export-ModuleMember -Function @(
    'Get-MarkdownLintCommand',
    'Test-PowerShellScripts',
    'Test-ShellScripts', 
    'Test-YAMLFiles',
    'Test-MarkdownFiles',
    'Invoke-AllQualityChecks',
    'Invoke-QuickFixes'
)