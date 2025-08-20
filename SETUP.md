# Development Environment Setup

## Quick Start

### One-Click Installation (Recommended)

Use the platform-appropriate installation script:

```bash
# macOS/Linux (bash)
sh scripts/install.sh

# macOS/Linux (zsh)
zsh scripts/install.zsh

# Any platform with PowerShell
pwsh scripts/install.ps1
```

## Manual Setup

If you prefer manual setup or need to customize the process:

### 1. Configure Environment

Copy the example environment file and update with your API keys:

```bash
cp .env.example .env
```

Edit `.env` and add your:

- `CLAUDE_API_KEY` - Get from [Anthropic Console](https://console.anthropic.com/)
- `GEMINI_API_KEY` - Get from [Google AI Studio](https://makersuite.google.com/app/apikey)

### 2. Install Quality Check Tools (Automatic)

The installation script will automatically install:

```powershell
# PowerShell Script Analyzer (cross-platform)
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser

# shellcheck for shell script validation
# Installed automatically based on your platform:
# - macOS: via Homebrew
# - Linux: via apt/yum/dnf
# - Windows: via Scoop or Chocolatey

# yq for YAML validation
# Installed automatically based on your platform
```

Or install manually using our PowerShell module:

```powershell
Import-Module ./scripts/powershell/Install-QualityTools.psm1
Install-AllQualityTools
```

## Development Workflow

### Code Quality

```powershell
# Run all quality checks using our automated module
Import-Module ./scripts/powershell/Invoke-QualityChecks.psm1
Invoke-AllQualityChecks

# Run specific checks
Test-PowerShellScripts -Path "scripts/" -Recurse
Test-ShellScripts -Path "scripts/shell/" -Recurse
Test-YAMLFiles -Path "configs/" -Recurse

# Apply automatic fixes where possible
Invoke-QuickFixes
```

### Manual Quality Checks

If you prefer to run tools individually:

```powershell
# PowerShell script analysis
Invoke-ScriptAnalyzer -Path scripts/ -Recurse

# Check specific PowerShell file
Invoke-ScriptAnalyzer -Path scripts/MyScript.ps1
```

```bash
# Shell script validation (bash/zsh scripts)
shellcheck scripts/install.sh
shellcheck scripts/**/*.sh

# YAML configuration validation
yq validate configs/*.yaml
```

### GitHub Actions (Automated CI)

Quality checks run automatically on every push and pull request via GitHub Actions:

- **PowerShell Analysis**: PSScriptAnalyzer checks all `.ps1`, `.psm1`, and `.psd1` files
- **Shell Script Validation**: shellcheck validates all `.sh`, `.bash`, and `.zsh` files
- **YAML Validation**: yq validates all `.yaml` and `.yml` configuration files

The CI workflow is defined in `.github/workflows/quality-checks.yml` and will:

1. Install all necessary quality tools
2. Run comprehensive analysis on your code
3. Report any issues that need to be fixed
4. Block merges if critical issues are found

### Using AI Assistants

This boilerplate is configured for optimal use with:

- **Claude**: Anthropic's AI assistant
- **Gemini**: Google's AI model
- **GitHub Copilot**: With custom instructions in `.github/copilot-instructions.md`

The configuration files in `configs/` define:

- AI tool settings and API endpoints
- Development stack and dependencies
- IDE integrations
- Cross-platform compatibility settings

## Project Structure

```
proxmox-ve-toolkit/
├── .github/                       # GitHub workflows and Copilot instructions
│   ├── copilot-instructions.md    # Main GitHub Copilot instructions
│   ├── instructions/              # File-type specific instruction files
│   └── workflows/                 # CI/CD workflows (quality checks)
├── configs/                       # YAML configuration files
│   ├── ai-tools.yaml             # AI service configurations
│   ├── code-stack.yaml           # Development stack settings
│   └── *.yaml                    # Other configuration files
├── scripts/                       # Cross-platform utility scripts
│   ├── powershell/                # PowerShell modules and scripts
│   │   ├── Install-QualityTools.psm1  # Quality tools installer
│   │   ├── Invoke-QualityChecks.psm1  # Automated quality checks
│   │   ├── Invoke-Python.psm1         # Python runner utility
│   │   └── install.ps1                # Main installation script
│   └── shell/                     # Shell scripts
│       └── install.sh             # Shell bootstrapper script
├── .env                          # Environment variables (create from .env.example)
├── .env.example                  # Environment variable template
└── README.md                     # Main project documentation
```

## PowerShell Module Usage

This project includes PowerShell modules for automation and quality assurance:

```powershell
# Quality Tools Management
Import-Module ./scripts/powershell/Install-QualityTools.psm1
Install-AllQualityTools                    # Install all quality check tools
Test-QualityToolsInstallation             # Verify tools are working
Show-ToolVersions                          # Display installed tool versions

# Quality Checks
Import-Module ./scripts/powershell/Invoke-QualityChecks.psm1
Invoke-AllQualityChecks                    # Run all quality checks
Test-PowerShellScripts -Path scripts/      # Check PowerShell scripts only
Test-ShellScripts -Path scripts/shell/     # Check shell scripts only
Test-YAMLFiles -Path configs/              # Validate YAML files only

# Python Integration (if needed)
Import-Module ./scripts/powershell/Invoke-Python.psm1
Invoke-Python "script.py"                 # Run Python scripts cross-platform
```

## Troubleshooting

### Permission Errors

On macOS/Linux, ensure scripts are executable:

```bash
chmod +x scripts/install.sh
chmod +x scripts/**/*.sh
```

### API Key Issues

1. Ensure your `.env` file contains valid API keys
2. Never commit `.env` to version control (it's in `.gitignore`)
3. Use `.env.example` as a template for required variables

### PowerShell Execution Policy (Windows)

If PowerShell scripts fail to run on Windows:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Next Steps

1. **Review configurations**: Check files in `configs/` directory
2. **Read AI instructions**: Review `.github/copilot-instructions.md` and related files
3. **Understand the structure**: Familiarize yourself with the project layout
4. **Test quality checks**: Run `Invoke-AllQualityChecks` to verify everything works
5. **Start developing**: Begin working with the Proxmox VE toolkit
6. **Use AI tools**: Leverage the configured AI assistants for development

## Additional Resources

- [Main README](README.md) - Project overview and quick start
- [Claude Guidelines](CLAUDE.md) - Claude-specific development guidance
- [AI Coding Standards](AGENTS.md) - Universal AI coding agent guidelines
- [GitHub Copilot Instructions](.github/copilot-instructions.md) - Copilot configuration

For questions or issues, refer to the documentation in the respective configuration files or the project's issue tracker.
