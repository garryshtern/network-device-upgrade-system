# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Python-based network device upgrade system. The project is in early stages with minimal setup - only a basic `pyproject.toml` configuration file exists currently.

## Project Structure

- **Root directory**: Contains core configuration (`pyproject.toml`)
- **`.claude/`**: Claude Code configuration with custom commands
- **`.venv/`**: Python virtual environment
- **`.idea/`**: IntelliJ/PyCharm IDE configuration

## Development Commands

This project uses `uv` for dependency management. Key commands:

```bash
# Install dependencies and sync environment
uv sync

# Install project in development mode
uv pip install -e .

# Run Python modules
uv run python -m <module_name>

# Add new dependencies
uv add <package_name>

# Activate virtual environment (if needed)
source .venv/bin/activate
```

## Code Standards and Contribution Guidelines

Based on the existing Claude commands, follow these standards:

- **PEP 8 coding standards**: Maintain consistent Python style
- **Type hints**: Use type hints for all new functions and methods
- **Testing**: Write unit tests for new features with 100% test coverage goal
- **Documentation**: Update documentation as needed and document new features
- **Commit practices**: Use meaningful commit messages and commit frequently
- **Dependency management**: Keep dependencies up to date
- **Code organization**: Adhere to existing code style and patterns, avoid large monolithic changes

## Claude Code Custom Commands

Two custom commands are configured:

1. **`/code-commit`**: Performs careful code review and commit with push
2. **`/code-review`**: Comprehensive code review with standards checking

Note: The `/code-review` command currently references TypeScript/React example files that are not applicable to this Python project. These references should be updated once Python modules are established.

## Architecture Notes

This appears to be a fresh Python project setup. The architecture will likely involve:
- Network device management and upgrade orchestration
- Python-based automation and scripting
- Configuration management for different device types

As the codebase develops, update this file with specific architectural patterns, main modules, and established development workflows.