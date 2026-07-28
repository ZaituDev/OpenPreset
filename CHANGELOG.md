# Changelog

All notable changes to OpenPreset will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v2.2.0] - 2026-07-27

### Added
- **Portable POSIX Banners**: Converted `assets/lbanner.sh` and `assets/sbanner.sh` to POSIX-compliant `printf %b` ANSI escape sequences.
- **Smart Banner Display (`show_banner`)**: Shows `lbanner` (ASCII art box) once on first run following installation/update, and `sbanner` (compact box) on subsequent launcher starts.
- **FZF Interactive Help Card**: Added `?` (and `Ctrl+/`) shortcut in `fzf` provider ordering to toggle a clean preview help card covering shortcuts, navigation, and sorting.

### Changed
- **Streamlined Installer Output**: Cleaned up `install.sh` by removing verbose step-by-step logs, emoji banners, and launcher path lists for a minimal completion output.
- **Cleaner FZF Provider Ordering UI**: Removed pre-fzf static text header lines and redundant `print_header` boxes, replacing them with a concise `fzf` header (`Model: <id> · TAB select · s/l/u/t/n sort · v info · ? help`).

---

## [v2.1.0] - 2026-07-26

### Added
- **Subcommand `openpreset export [path]`**: Export user models and presets to a portable JSON backup file. Defaults to `~/openpreset-backup-YYYY-MM-DD.json` if path is omitted or `~`.
- **Subcommand `openpreset import [path] [--mode <merge|replace>]`**: Import user models and presets from a backup file. Defaults to `~/openpreset-backup-YYYY-MM-DD.json` (or latest backup in `~`) if path is omitted or `~`.
- **Subcommand `openpreset uninstall [-r] [-y]`**: Self-uninstall command with `[y/N]` confirmation prompt (skippable via `-y`). Removes tool launchers and shared components. Accepts `-r` / `--remove-data` flag to also delete user data (`~/.config/openpreset`) and cache (`~/.cache/openpreset`).
- **Subcommand `openpreset reset [-y]`**: Reset user data with `[y/N]` confirmation prompt (skippable via `-y`) to delete user configuration and cache.
- **Subcommand `openpreset refresh`**: Clear cached model lists and provider endpoint data in `~/.cache/openpreset`.
- **Model-Scoped Preset Import/Export**: Updated Preset Menu shortcuts (Ctrl+I for import, Ctrl+X for export) to operate strictly on the presets belonging to the currently selected model (`_ROUTER_MODEL`).
- **Model Backup API (`backup_export_model` & `backup_import_model`)**: Added model-scoped backup export and import functions in `router/backup.sh`.

### Removed
- **Subcommand `openpreset launch <agent>`**: Removed legacy agent launcher subcommand in favor of direct agent launchers (`cr`, `kr`, `hr`, `or`, `pr`, `clr`).

### Fixed
- **Directory Creation Guard in `backup_import`**: Ensured target configuration directory (`CONFIG_DIR`) is created before writing `USER_MODELS_FILE` during import operations.

---

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
