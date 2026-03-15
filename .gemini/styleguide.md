# Template Repository - Code Review Style Guide

## Project Context

This is a generic GitHub template repository for bootstrapping PHP projects (plugins, themes, libraries). A `setup.sh` script lets developers configure the project name, namespace, and description. PHP 8.1+ minimum, strict types everywhere.

## PHP

- Use tabs for indentation (not spaces).
- All files must declare `declare(strict_types=1)`.
- PSR-4 autoloading under `src/`.
- Use post-increment (`$i++`) over pre-increment (`++$i`).
- Coding standards are enforced via PHPCS.
- Static analysis via PHPStan.

## Testing

- Unit tests use PHPUnit.
- If tests exist for a changed area, flag missing or insufficient test coverage for new/modified code.

## Documentation

- If a change affects user-facing behavior, flag missing updates to README, CHANGELOG, or inline docblocks.

## Commits

- This project uses Conventional Commits with a 50-char subject / 72-char body limit.
- Each commit should address a single concern.
