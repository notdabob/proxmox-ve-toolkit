# Project Context for Gemini CLI

This document provides essential context for the Gemini CLI agent to effectively assist with development tasks within this project.

## Project Overview

This is a boilerplate project designed for AI-assisted software development, primarily focusing on Python and PowerShell. It provides a structured environment with pre-configured tools and conventions to streamline the use of AI code assistants like Gemini, Claude, and GitHub Copilot. The project aims to facilitate rapid prototyping, code generation, and quality assurance through automation and adherence to defined standards.

**Key Technologies:**
- **Languages:** Python (3.8.1 to 3.x), PowerShell (7.0+)
- **Package Management:** Poetry (Python), npm (for `package.json` scripts, though primarily Python-focused)
- **Testing:** Pytest (Python)
- **Code Quality:** Black (Python formatter), MyPy (Python type checker), pre-commit hooks
- **AI Integration:** Configured for Gemini, Claude, and GitHub Copilot API keys and settings.

**Architecture:**
The project follows a modular structure:
- `src/`: Python source code.
- `tests/`: Pytest test suite.
- `scripts/`: Cross-platform installation and utility scripts (Python and PowerShell).
- `configs/`: YAML configuration files for AI tools and development stack.
- `.github/`: GitHub workflows, issue templates, and AI-specific instructions.
- `.claude/`: Claude-specific configurations and commands.

## Building and Running

### Installation
The project can be set up using platform-specific installation scripts or manually.

**One-Click Installation (Recommended):**
- **macOS/Linux (bash/sh):** `sh scripts/install.sh`
- **macOS/Linux (zsh):** `zsh scripts/install.zsh`
- **Any platform with PowerShell:** `pwsh scripts/install.ps1`

These scripts handle Python/Poetry installation, dependency management, and pre-commit hook setup.

**Manual Setup:**
```bash
# Initialize project and dependencies
python init.py

# Activate virtual environment (example for Unix/macOS)
source .venv/bin/activate

# Install dependencies and set up development environment
poetry install
pre-commit install
```

### Running Tests
```bash
# Run all tests
pytest

# Run tests with coverage report
pytest --cov=src --cov-report=term-missing

# Run unit tests only
pytest -m unit
```

### Code Quality Checks
```bash
# Format Python code
black .

# Run Python type checking
mypy src/

# Run all pre-commit hooks
pre-commit run --all-files
```

## Development Conventions

### Python Code
- **Type Hinting:** All functions and methods require type hints.
- **Docstrings:** Use Google or NumPy style docstrings for documentation.
- **Formatting:** Black formatter is enforced via pre-commit hooks.
- **Import Order:** Standard library, then third-party, then local imports.

### Testing
- New functionality requires corresponding tests.
- Code coverage should be maintained above a configured threshold (defined in `pytest.ini`).
- Tests use markers like `@pytest.mark.unit`, `@pytest.mark.integration`, `@pytest.mark.slow`.
- Test file structure mirrors the source code structure.

### Cross-Platform Compatibility
- PowerShell 7.0+ is used for all PowerShell scripts.
- Python code should use `pathlib.Path` for robust file operations.

### AI Integration
- API keys for AI services (Claude, Gemini) are managed via a `.env` file (copy `.env.example`).
- AI tool configurations are defined in YAML files within the `configs/` directory.
- Specific instructions for GitHub Copilot are located in `.github/copilot-instructions.md`.

## Key Configuration Files

- `.env.example`: Template for environment variables (API keys).
- `pyproject.toml`: Poetry project metadata and Python dependencies.
- `pytest.ini`: Pytest configuration, including coverage settings.
- `configs/ai-tools.yaml`: Configuration for AI services.
- `configs/code-stack.yaml`: Defines the development stack settings.
- `.github/workflows/`: Contains GitHub Actions workflows for CI, code review, and automated triage.
- `.github/instructions/`: Markdown files detailing coding standards and instructions for various languages/tools (e.g., PowerShell, Python).
- `scripts/powershell/proxmox/ProxmoxMigration/`: Contains PowerShell scripts and modules for Proxmox VE cluster migration, serving as a practical example of the project's PowerShell standards.
