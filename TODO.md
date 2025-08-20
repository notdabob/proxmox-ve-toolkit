# TODO List for Proxmox VE Toolkit

## 🛠️ Development Tasks

- [ ] Implement missing features in PowerShell modules (`scripts/`)
- [ ] Add schema validation for all YAML configs in `configs/`
- [ ] Improve cross-platform compatibility (test on Windows, macOS, Linux)
- [ ] Refactor Python code to ensure full type hint coverage
- [ ] Add more comprehensive unit and integration tests in `tests/`
- [ ] Update documentation in `README.md` and `SETUP.md`
- [ ] Ensure all scripts use `pathlib` for file operations

## 🧪 Testing & Quality

- [ ] Set up pre-commit hooks for code style enforcement

## ⚙️ Configuration & Integration

- [ ] Review and update `configs/ai-tools.yaml` for new AI services
- [ ] Document configuration options in `docs/` or Markdown files
- [ ] Validate environment variable usage (`.env.example`)

## 📚 Research & Documentation

- [ ] Research best practices for PowerShell 7+ cross-platform scripting
  - [PowerShell Docs](https://learn.microsoft.com/en-us/powershell/)
  - [GitHub Copilot Docs](https://docs.github.com/en/copilot)
  - [Claude API Docs](https://docs.anthropic.com/claude/reference)
- [ ] Research adding `*.instructions.md` files in `.github/instructions/` and ensure correct usage for file types
  - [Copilot Custom Instructions](https://code.visualstudio.com/docs/copilot/copilot-customization#_custom-instructions)
- [ ] Research GitHub Copilot reusable `*.prompt.md` & `*.instructions.md` files
  - [Copilot Prompt Files (Experimental)](https://code.visualstudio.com/docs/copilot/copilot-customization#_prompt-files-experimental)
- [ ] Research GitHub Copilot chatmodes files in `.github/chatmodes` named `*.chatmode.md`
  - [Copilot Custom Chat Modes](https://aka.ms/vscode-ghcp-custom-chat-modes)

## 📝 Notes

- Add more links or tasks as needed!
