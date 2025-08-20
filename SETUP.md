# Development Environment Setup

## Quick Start

### One-Click Installation (Recommended)

Use the platform-appropriate installation script:

```bash
# macOS/Linux (bash)
sh scripts/install.sh
Test-ShellScript -Path scripts/shell/     # Check shell scripts only

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

### 2. Install Quality Check Tools (Automated)

The installation script automatically installs all quality tools using our cross-platform PowerShell modules:

```powershell
# Using our automated installation module (recommended)
Import-Module ./scripts/powershell/Install-QualityTool.psm1
Install-AllQualityTool -Force

# This automatically installs:
# - PSScriptAnalyzer: PowerShell script analysis (cross-platform)
# - shellcheck: Shell script validation (via system package manager)
# - yq: YAML validation and processing (downloaded binary)
# - markdownlint-cli: Markdown linting (via npx, no global install needed)
```

**Platform-specific installation methods:**

- **macOS**: Homebrew for shellcheck, direct download for yq
- **Linux**: apt/yum/dnf for shellcheck, direct download for yq
- **Windows**: Scoop/Chocolatey fallback, PowerShell Gallery for PSScriptAnalyzer
- **All platforms**: npx for markdownlint (no sudo required)

## Development Workflow

### Code Quality (Automated)

Our project uses automated PowerShell modules for comprehensive quality checks:

```powershell
# Run all quality checks using our automated module (recommended)
Import-Module ./scripts/powershell/Invoke-QualityChecks.psm1
Invoke-AllQualityCheck -Path . -ExitOnFailure

# Run specific file type checks
Test-PowerShellScript -Path "scripts/" -Recurse
Test-ShellScript -Path "scripts/shell/" -Recurse
Test-YAMLFile -Path "configs/" -Recurse
Test-MarkdownFile -Path "." -Recurse

# Quick verification that all tools are working
Import-Module ./scripts/powershell/Install-QualityTool.psm1
Test-QualityToolsInstallation
```

**Key Features:**

- **Dependency Checking**: Automatically validates npm/npx availability before running markdownlint
- **Cross-Platform**: Works on Windows, macOS, and Linux
- **Comprehensive**: Covers PowerShell, Shell, YAML, and Markdown files
- **CI Integration**: Same modules used in GitHub Actions workflow

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

Quality checks run automatically on every push and pull request using our automated PowerShell modules:

**Workflow Features:**

- **Automated Tool Installation**: Uses `Install-QualityTool.psm1` to install all necessary tools
- **Comprehensive Analysis**: Runs `Invoke-QualityChecks.psm1` for complete code validation
- **Dependency Validation**: Ensures npm/npx availability before running markdownlint
- **Cross-Platform**: Executes on Ubuntu with PowerShell 7.0+

**Quality Checks Performed:**

- **PowerShell Analysis**: PSScriptAnalyzer checks all `.ps1`, `.psm1`, and `.psd1` files
- **Shell Script Validation**: shellcheck validates all `.sh`, `.bash`, and `.zsh` files
- **YAML Validation**: yq validates all `.yaml` and `.yml` configuration files
- **Markdown Linting**: markdownlint-cli via npx checks all `.md` files

The CI workflow in `.github/workflows/quality-checks.yml` will:

1. Install PowerShell on Ubuntu runner
2. Set up Node.js for npm/npx tools
3. Use our automated modules to install all quality tools
4. Run comprehensive analysis using the same modules developers use locally
5. Report detailed results and block merges if critical issues are found

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
│   │   ├── Install-QualityTool.psm1   # Quality tools installer
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
Import-Module ./scripts/powershell/Install-QualityTool.psm1
Install-AllQualityTool                    # Install all quality check tools
Test-QualityToolsInstallation             # Verify tools are working
Show-ToolVersion                          # Display installed tool versions

# Quality Checks
Import-Module ./scripts/powershell/Invoke-QualityChecks.psm1
Invoke-AllQualityCheck                    # Run all quality checks
Test-PowerShellScript -Path scripts/       # Check PowerShell scripts only
Test-ShellScript -Path scripts/shell/     # Check shell scripts only
Test-YAMLFile -Path configs/              # Validate YAML files only

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
4. **Test quality checks**: Run `Invoke-AllQualityCheck` to verify everything works
5. **Start developing**: Begin working with the Proxmox VE toolkit
6. **Use AI tools**: Leverage the configured AI assistants for development

## Additional Resources

- [Main README](README.md) - Project overview and quick start
- [Claude Guidelines](CLAUDE.md) - Claude-specific development guidance
- [AI Coding Standards](AGENTS.md) - Universal AI coding agent guidelines
- [GitHub Copilot Instructions](.github/copilot-instructions.md) - Copilot configuration

For questions or issues, refer to the documentation in the respective configuration files or the project's issue tracker.
