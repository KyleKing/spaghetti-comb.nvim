# Contributing to spaghetti-comb.nvim

Thank you for considering contributing to spaghetti-comb.nvim!

## Development Setup

### Prerequisites

- [mise](https://mise.jdx.dev/) - Tool version manager
- [hk](https://hk.jdx.dev/) - Git hook manager (installed via mise)
- Lua 5.1
- [stylua](https://github.com/JohnnyMorganz/StyLua) - Lua formatter
- [selene](https://github.com/Kampfkarren/selene) - Lua linter
- Neovim >= 0.10.0
### Initial Setup

```bash
# Clone the repository
git clone https://github.com/kyleking/spaghetti-comb.nvim
cd spaghetti-comb.nvim

# Install mise tools
mise install

# Install git hooks
hk install

# Verify setup
mise run ci
```

## Development Workflow

### Making Changes

1. Create a feature branch from `main`
2. Make your changes
3. Run `mise run format` to format code
4. Run `mise run ci` to verify all checks pass
5. Commit your changes (commitizen will guide you)
6. Push and create a pull request

### Code Style

- Follow the [Lua Style Guide](https://github.com/luarocks/lua-style-guide)
- Use 4 spaces for indentation
- Maximum line length: 120 characters
- Run `mise run format` before committing

### Testing

```bash
# Run all tests
mise run test

# Run specific test file
mise run test-file -- -f lua/spaghetti-comb/tests/setup_spec.lua
# Run with coverage
mise run test
```

### Linting and Type Checking

```bash
# Check formatting
mise run lint

# Fix formatting issues
mise run format

# Run type checker
mise run typecheck

# Run all checks
mise run ci
```

## Pull Request Process

1. Update documentation if needed
2. Add tests for new functionality
3. Ensure all CI checks pass
4. Request review from maintainers
5. Address review feedback

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `style:` Code style changes (formatting)
- `refactor:` Code refactoring
- `test:` Test changes
- `chore:` Build/tooling changes

Commitizen will guide you through the commit message format.
## Code Review Guidelines

- Be respectful and constructive
- Focus on the code, not the person
- Explain reasoning behind suggestions
- Accept that there are multiple valid approaches

## Getting Help

- Check existing issues and discussions
- Ask questions in pull request comments
- Reach out to maintainers at dev.act.kyle@gmail.com

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
