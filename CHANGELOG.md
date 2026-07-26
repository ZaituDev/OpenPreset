# Changelog

All notable changes to OpenPreset will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v2.0.0] - 2026-07-26

### Added
- **Packaging Utility (`package.sh`)**: Added release packaging script to automate creating distribution tarballs (`openpreset-v*.tar.gz`) and SHA-256 `checksums.txt`.
- **Configurable API Endpoint**: Introduced `OPENROUTER_BASE_URL` environment variable support to allow custom base URLs for OpenRouter API requests (defaulting to `https://openrouter.ai/api/v1`).

### Changed
- **Project Rebranding**: Complete project rename from Claude Router (`claude-router`) to **OpenPreset** (`ZaituDev/OpenPreset`).
- **Environment Variable Namespace**: Updated environment variable prefix from `CLAUDE_ROUTER_*` to `OPENPRESET_*`:
  - `OPENPRESET_MODE`
  - `OPENPRESET_PROFILE`
  - `OPENPRESET_DEFAULT_MODELS`
  - `OPENPRESET_CACHE_TTL`
- **Core Router Entry Point**: Renamed primary POSIX entry point function from `claude_router()` to `openpreset_router()`.
- **XDG Configuration & Cache Directory**: Updated default paths to `~/.config/openpreset` and `~/.cache/openpreset` with automatic backward-compatibility migration for legacy configuration directories.
- **Launcher Scripts Suite**: Updated launcher scripts (`clr`, `cr`, `hr`, `kr`, `openpreset`, `or`, `pr`) and extra launchers (`braining`, `superpowers`, `template`) to export `OPENPRESET_*` options.
- **Authentication Logic**: Decoupled OpenRouter authentication from legacy Anthropic tokens, standardizing on `OPENROUTER_API_KEY`.
- **Installation Script & Documentation**: Updated `install.sh` and `README.md` to reference the new repository path `ZaituDev/OpenPreset`.

### Fixed
- **fzf Interface Leaks**: Fixed process and file descriptor leakage when spawning interactive model selection prompts using `fzf` in `router/ui.sh`.
- **POSIX Shell Compatibility**: Enhanced script portability across `dash`, `bash`, `ksh`, and `zsh` by eliminating non-standard shell extensions.

---

## [v1.0.0] - 2026-07-25

### Added
- Initial release of the POSIX-compliant OpenRouter preset router.
