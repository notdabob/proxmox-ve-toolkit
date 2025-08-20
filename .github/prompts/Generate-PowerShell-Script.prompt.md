---
mode: agent
---

Define the task to achieve, including specific requirements, constraints, and success criteria.

Task: Generate a Python module for parsing YAML configuration files.

Requirements:

- The module must provide functions to load, validate, and save YAML files.
- Use type hints for all functions.
- Include Google-style docstrings.
- Handle errors gracefully and log descriptive messages.
- Ensure compatibility with Python 3.8+.

Constraints:

- Use only standard library and PyYAML.
- No external dependencies beyond PyYAML.
- Code must pass Black formatting and MyPy type checks.

Success Criteria:

- The module is placed in `src/config_parser.py`.
- Includes at least one unit test in `tests/test_config_parser.py`.
- All tests pass with pytest.
