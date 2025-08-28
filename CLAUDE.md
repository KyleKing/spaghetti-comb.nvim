# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Testing

- `make test` - Run all tests using mini.test framework documented in `mini-test.md`

### Code Quality

- `make lint` - Format code using stylua
- `make luals` - Run lua-language-server type checking

### Documentation

- `make docs` - Generate plugin documentation using mini.doc

### Setup

- `make setup` - Initialize plugin from template (interactive script)
- `make deps` - Install mini.nvim dependency for tests and documentation

## Architecture Overview

This is a Neovim plugin for visually exploring a new code base

### Current Implementation Status

- There is no implementation yet

### Plugin Architecture Pattern

The codebase follows a standard Neovim plugin architecture:

1. Global plugin object exposes public API
1. Modular structure separating domains

The plugin will provide an intuitive way to understand a new codebase by showing related code on request.
