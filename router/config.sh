#!/usr/bin/env sh
# config.sh — constants only, nothing executable
# POSIX sh. No bashisms, no zsh-isms. Sourced by router_engine.sh.

# ── openpreset Version & Repo Info ───────────────────────────────────────

OPENPRESET_VERSION="${OPENPRESET_VERSION:-2.1.0}"
OPENPRESET_REPO="${OPENPRESET_REPO:-zaidsubhani135/claude-router}"

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
CACHE_TTL="${OPENPRESET_CACHE_TTL:-900}"

# ── User data ───────────────────────────────────────────────────────────────

USER_MODELS_FILE="${CONFIG_DIR}/user-models.txt"
PRESETS_DIR="${CONFIG_DIR}/presets"

# ── OpenRouter ──────────────────────────────────────────────────────────────

PRESET_PREFIX="openpreset"
OPENROUTER_BASE_URL="${OPENROUTER_BASE_URL:-https://openrouter.ai/api/v1}"
OPENROUTER_API="${OPENROUTER_BASE_URL}"

# ── Default models ──────────────────────────────────────────────────────────
# Newline-joined string (not an array — POSIX sh has no arrays). A launcher
# may set OPENPRESET_DEFAULT_MODELS itself; only fall back here if unset.

if [ -z "${OPENPRESET_DEFAULT_MODELS+x}" ]; then
    OPENPRESET_DEFAULT_MODELS="openrouter/free"
fi

# ── Optional overrides (must default to empty, not unset) ──────────────────
# router_engine.sh checks these with [ -n "$VAR" ] to decide whether to skip
# an interactive prompt. Default to "" so the check is always meaningful even
# under `set -u`.

: "${OPENPRESET_MODE:=}"
: "${OPENPRESET_PROFILE:=}"

# ── Backup ──────────────────────────────────────────────────────────────────

BACKUP_SCHEMA_VERSION="1"

