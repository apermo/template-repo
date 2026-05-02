# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-05-02

### Changed

- Bump `apermo/apermo-coding-standards` to `^3.0` in `composer.json.dist` (#3)
- Add `phpstan/extension-installer` to `require-dev` to match `config.allow-plugins` (#3)
- Migrate git hooks from `.githooks/` to `husky` + `lint-staged`; hooks now activate automatically via `npm install` (#4)
- Split `ci.yml` into separate `pr-validation.yml` (PR triggers) and `release.yml` (push to `main`) (#5)

## [0.2.0] - 2026-03-15

### Added

- Gemini Code Assist configuration (`.gemini/config.yaml`)
- Code review styleguide with rules for comment quality, code reuse, file operations, build/packaging, testing, documentation, and commits

## [0.1.0] - 2026-03-15

### Added

- Initial project setup

### Fixed

- Workflow callers missing permissions (caused startup_failure)
