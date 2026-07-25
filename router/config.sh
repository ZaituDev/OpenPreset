#!/usr/bin/env sh
# config.sh — constants only, nothing executable
# POSIX sh. No bashisms, no zsh-isms. Sourced by router_engine.sh.

# ── openpreset Version & Repo Info ───────────────────────────────────────

OPENPRESET_VERSION="1.0.0"
OPENPRESET_REPO="zaidsubhani135/claude-router"

# ── XDG-compliant paths ────────────────────────────────────────────────────

_legacy_config="${XDG_CONFIG_HOME:-${HOME}/.config}/claude-router"
if [ -d "${_legacy_config}" ] && [ ! -d "${XDG_CONFIG_HOME:-${HOME}/.config}/openpreset" ]; then
    CONFIG_DIR="${_legacy_config}"
else
    CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/openpreset"
fi
unset _legacy_config

CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/openpreset"

# ── Cache files ─────────────────────────────────────────────────────────────

CACHE_FILE="${CACHE_DIR}/models.json"
CACHE_TIMESTAMP="${CACHE_DIR}/models.timestamp"
CACHE_TTL="${CLAUDE_ROUTER_CACHE_TTL:-900}"

# ── User data ───────────────────────────────────────────────────────────────

USER_MODELS_FILE="${CONFIG_DIR}/user-models.txt"
PRESETS_DIR="${CONFIG_DIR}/presets"

# ── OpenRouter ──────────────────────────────────────────────────────────────

PRESET_PREFIX="claude"
OPENROUTER_API="https://openrouter.ai/api/v1"

# ── Default models ──────────────────────────────────────────────────────────
# Newline-joined string (not an array — POSIX sh has no arrays). A launcher
# may set CLAUDE_ROUTER_DEFAULT_MODELS itself; only fall back here if unset.

if [ -z "${CLAUDE_ROUTER_DEFAULT_MODELS+x}" ]; then
    CLAUDE_ROUTER_DEFAULT_MODELS="openrouter/free"
fi

# ── Optional overrides (must default to empty, not unset) ──────────────────
# router_engine.sh checks these with [ -n "$VAR" ] to decide whether to skip
# an interactive prompt. Default to "" so the check is always meaningful even
# under `set -u`.

: "${CLAUDE_ROUTER_MODE:=}"
: "${CLAUDE_ROUTER_PROFILE:=}"

# ── Backup ──────────────────────────────────────────────────────────────────

BACKUP_SCHEMA_VERSION="1"

