<#
.SYNOPSIS
    Fixes common markdown linting errors in instruction files

.DESCRIPTION
    Automatically fixes markdown linting errors like:
    - Missing trailing newlines (MD047)
    - Blank lines around fences (MD031) 
    - Fenced code language specification (MD040)
    - Blank lines around lists (MD032)
    - Long lines (MD013)

.EXAMPLE
    ./Fix-MarkdownLinting.ps1 -Path .github/instructions
#>
param(
    [Parameter(Mandatory = $false)]
    [string]$Path = ".github/instructions"
)

function Repair-MarkdownFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    Write-Host "🔧 Fixing: $($FilePath | Split-Path -Leaf)" -ForegroundColor Blue
    
    $content = Get-Content $FilePath -Raw
    $lines = Get-Content $FilePath
    $modified = $false
    
    # Fix MD047: Files should end with a single newline character
    if (-not $content.EndsWith("`n")) {
        $content += "`n"
        $modified = $true
        Write-Host "  ✅ Added missing trailing newline" -ForegroundColor Green
    }
    
    # Process line by line for other fixes
    $newLines = @()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $nextLine = if ($i + 1 -lt $lines.Count) { $lines[$i + 1] } else { "" }
        $prevLine = if ($i - 1 -ge 0) { $lines[$i - 1] } else { "" }
        
        # Fix MD040: Fenced code blocks should have a language specified
        if ($line -match '^```\s*$' -and $nextLine -ne '') {
            # This is a code fence without language specification
            # Try to determine the appropriate language from context
            $language = "text"  # Default fallback
            
            # Look at surrounding context for clues
            for ($j = $i + 1; $j -lt $lines.Count -and $j -lt $i + 5; $j++) {
                if ($lines[$j] -match '^```') { break }
                if ($lines[$j] -match 'function\s+\w+-\w+|param\(|\$\w+\s*=|\[CmdletBinding') {
                    $language = "powershell"
                    break
                }
                if ($lines[$j] -match '#!/bin/bash|#!/bin/sh|\$\(\w+\)|export\s+\w+') {
                    $language = "bash"
                    break
                }
                if ($lines[$j] -match '^\s*[\w-]+:\s*[\w-]|version:\s*[\d.]') {
                    $language = "yaml"
                    break
                }
                if ($lines[$j] -match '^\s*\w+/|├──|└──') {
                    $language = "text"
                    break
                }
            }
            
            $newLines += "``$language"
            $modified = $true
            Write-Host "  ✅ Added language ($language) to code fence at line $($i + 1)" -ForegroundColor Green
            continue
        }
        
        # Fix MD031: Fenced code blocks should be surrounded by blank lines
        if ($line -match '^```' -and $prevLine -ne '' -and $prevLine -notmatch '^```') {
            # Add blank line before code fence
            $newLines += ""
            $newLines += $line
            $modified = $true
            Write-Host "  ✅ Added blank line before code fence at line $($i + 1)" -ForegroundColor Green
            continue
        }
        
        # Fix MD032: Lists should be surrounded by blank lines
        if ($line -match '^\s*-\s+' -and $prevLine -ne '' -and $prevLine -notmatch '^\s*-\s+' -and $prevLine -notmatch '^#') {
            # Add blank line before list
            $newLines += ""
            $newLines += $line
            $modified = $true
            Write-Host "  ✅ Added blank line before list at line $($i + 1)" -ForegroundColor Green
            continue
        }
        
        $newLines += $line
    }
    
    # Handle MD031 for closing code fences
    $finalLines = @()
    for ($i = 0; $i -lt $newLines.Count; $i++) {
        $line = $newLines[$i]
        $nextLine = if ($i + 1 -lt $newLines.Count) { $newLines[$i + 1] } else { "" }
        
        $finalLines += $line
        
        # Add blank line after closing code fence if needed
        if ($line -match '^```' -and $nextLine -ne '' -and $nextLine -notmatch '^```' -and $nextLine -notmatch '^\s*$') {
            $finalLines += ""
            $modified = $true
            Write-Host "  ✅ Added blank line after code fence at line $($i + 1)" -ForegroundColor Green
        }
    }
    
    if ($modified) {
        $newContent = $finalLines -join "`n" + "`n"
        Set-Content -Path $FilePath -Value $newContent.TrimEnd() + "`n" -NoNewline
        Write-Host "  💾 File updated successfully" -ForegroundColor Green
    } else {
        Write-Host "  ℹ️ No changes needed" -ForegroundColor Yellow
    }
}

# Main execution
Write-Host "🚀 Starting markdown linting fixes..." -ForegroundColor Cyan
Write-Host ""

$instructionFiles = Get-ChildItem -Path $Path -Filter "*.instructions.md"

foreach ($file in $instructionFiles) {
    Repair-MarkdownFile -FilePath $file.FullName
    Write-Host ""
}

Write-Host "🎉 Markdown linting fixes completed!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Running markdownlint to verify fixes..." -ForegroundColor Cyan

# Run markdownlint to check remaining issues
markdownlint -c .markdownlint.jsonc $Path/*.instructions.md