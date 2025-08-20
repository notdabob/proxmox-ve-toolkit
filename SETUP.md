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

### 2. Install Quality Check Tools

```powershell
# Install PowerShell Script Analyzer (cross-platform)
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser

# Install shellcheck for shell script validation (macOS/Linux)
# macOS:
brew install shellcheck

# Ubuntu/Debian:
sudo apt-get install shellcheck

# Or use package manager of choice
```

## Development Workflow

### Code Quality

```powershell
# PowerShell script analysis
Invoke-ScriptAnalyzer -Path scripts/ -Recurse

# Check specific PowerShell file
Invoke-ScriptAnalyzer -Path scripts/MyScript.ps1

# PowerShell formatting (if using PowerShell extension in VS Code)
# Format-Document command in VS Code
```

```bash
# Shell script validation (bash/zsh scripts)
shellcheck scripts/install.sh
shellcheck scripts/**/*.sh

# YAML configuration validation
# Using yq (install via: brew install yq)
yq validate configs/*.yaml

# Or using Python yaml module (if available)
python -c "import yaml; yaml.safe_load(open('configs/ai-tools.yaml'))"
```

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
ai-codeassist-boilerplate/
├── .claude/                    # Claude-specific configuration and commands
├── .github/                    # GitHub workflows and Copilot instructions
│   ├── copilot-instructions.md # Main GitHub Copilot instructions
│   └── instructions/           # Specific instruction files
├── configs/                    # YAML configuration files
│   ├── ai-tools.yaml          # AI service configurations
│   ├── code-stack.yaml        # Development stack settings
│   └── *.yaml                 # Other configuration files
├── scripts/                    # Cross-platform utility scripts
│   ├── Run-Python.psm1        # PowerShell Python runner
│   └── Get-ProviderModels.psm1 # AI model fetching utility
├── .env                        # Environment variables (create from .env.example)
├── .env.example               # Environment variable template
└── README.md                  # Main project documentation
```

## PowerShell Module Usage

This project includes PowerShell modules for cross-platform automation:

```powershell
# Import and use Python runner
Import-Module ./scripts/Run-Python.psm1
Run-Python "your_script.py"

# Fetch AI provider models
Import-Module ./scripts/Get-ProviderModels.psm1
Get-ProviderModels -Provider "claude" -OutputPath "./configs/claude_models.json"
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
4. **Start developing**: Begin working with the toolkit
5. **Use AI tools**: Leverage the configured AI assistants for development

## Additional Resources

- [Main README](README.md) - Project overview and quick start
- [Claude Guidelines](CLAUDE.md) - Claude-specific development guidance
- [AI Coding Standards](AGENTS.md) - Universal AI coding agent guidelines
- [GitHub Copilot Instructions](.github/copilot-instructions.md) - Copilot configuration

For questions or issues, refer to the documentation in the respective configuration files or the project's issue tracker.
