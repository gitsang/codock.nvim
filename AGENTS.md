# AGENTS.md

## Project Overview

This is a Neovim plugin written in Lua that opens a terminal with AI CLI tools (crush, opencode, claude, gemini-cli, etc.) in a vertical split.

## Commands

- No specific build commands identified
- No linting commands identified
- No testing framework identified

## Code Style Guidelines

- Language: Lua
- Follow general Lua best practices:
  - Use snake_case for variables and functions
  - Use PascalCase for classes/modules
  - Indent with 2 spaces
  - Limit lines to 100 characters
  - Use descriptive variable names
  - Comment public APIs

## Error Handling

- Use Lua's error() function for runtime errors
- Return nil, error_message for recoverable errors
- Use assert() for debugging/precondition checks

## Imports

- Use require() for module imports
- Group standard library imports separately from local imports

## Testing

- No established testing framework found
- When adding tests, consider using plenary.nvim test framework

## Plugin Structure

- Plugin code is in lua/codock/init.lua
- Main functionality is in the setup() function
- Creates Codock user commands (Codock, CodockFilePos, CodockActions, CodockWidth)
- Supports multiple AI CLI tools via codock_cmd option