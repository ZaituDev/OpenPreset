#!/usr/bin/env sh
# ui.sh — every prompt and display element
# No networking. No preset building. No cache logic.
#
# fzf is used when available. When absent, all menus fall back to the
# original numbered-list implementation so the router remains fully functional
# on Chromebook/Crostini, plain SSH sessions, and minimal environments.
#
# BUGFIX (vs. the original zsh version): every display helper here now takes
# its "am I using fzf" decision from a single call to _ui_has_fzf() and
# renders ONE UI — never both. Previously, provider-intelligence output was
# printed unconditionally before the picker ran, so the plain numbered
# reference table (meant only for the no-fzf fallback) also appeared above
# the interactive fzf picker, effectively leaking the fallback UI even when
# fzf was installed and being used. See show_provider_intelligence() and
# prompt_provider_order() below — the plain/legacy tables now only print on
# the non-fzf path.

# ── fzf detection ────────────────────────────────────────────────────────────

_ui_has_fzf() {
    command -v fzf > /dev/null 2>&1
}

_UI_FZF_WARNED=0
_ui_warn_no_fzf() {
    [ "${_UI_FZF_WARNED}" -eq 1 ] && return
    _UI_FZF_WARNED=1
    warn "fzf not found — using numbered menus. Install fzf for the enhanced UI."
}

# ── Banner ───────────────────────────────────────────────────────────────────

show_banner() {
    _assets_dir="${_ROUTER_DIR}/../assets"
    if [ ! -d "${_assets_dir}" ]; then
        _assets_dir="${HOME}/.local/share/openpreset/assets"
    fi
    if [ ! -d "${_assets_dir}" ]; then
        _assets_dir="/usr/local/share/openpreset/assets"
    fi

    _version_file="${CONFIG_DIR}/last_seen_version"
    _current_ver="${OPENPRESET_VERSION:-2.1.0}"
    _last_ver=""
    [ -f "${_version_file}" ] && _last_ver=$(cat "${_version_file}" 2>/dev/null || true)

    if [ "${_last_ver}" != "${_current_ver}" ] && [ -f "${_assets_dir}/lbanner.sh" ]; then
        sh "${_assets_dir}/lbanner.sh"
        mkdir -p "${CONFIG_DIR}" 2>/dev/null || true
        printf '%s' "${_current_ver}" > "${_version_file}" 2>/dev/null || true
    elif [ -f "${_assets_dir}/sbanner.sh" ]; then
        sh "${_assets_dir}/sbanner.sh"
    fi
    unset _assets_dir _version_file _current_ver _last_ver
}

# ── Header ───────────────────────────────────────────────────────────────────

print_header() {
    _model="${1:-unknown}"
    printf '\n'
    printf '╔══════════════════════════════════════════════╗\n'
    printf '║  🔀  OpenPreset Router                       ║\n'
    printf '║  Model: %-36s║\n' "${_model}"
    printf '╚══════════════════════════════════════════════╝\n'
    printf '\n'
    unset _model
}

# ── Model picker ─────────────────────────────────────────────────────────────

_ui_fzf_model_selection() {
    _fzf_input=""
    for _m in "$@"; do
        _fzf_input="${_fzf_input}${_m}
"
    done
    _fzf_input="${_fzf_input}+ Add custom model…
x Manage saved models…"

    _fzf_out=$(
        printf '%s' "${_fzf_input}" \
        | fzf \
            --prompt '  Model › ' \
            --height '~80%' \
            --layout reverse \
            --border rounded \
            --no-preview \
            --header '  ↑↓ navigate · Enter select · / search · Esc back · Ctrl+C cancel' \
            --expect=ctrl-c \
            2>/dev/tty
    )
    _rc=$?

    if [ "${_rc}" -ne 0 ]; then
        unset _fzf_input _fzf_out _rc _m
        return 1
    fi

    _key=$(printf '%s' "${_fzf_out}" | head -n 1)
    _result=$(printf '%s' "${_fzf_out}" | tail -n +2)

    case "${_key}" in
        ctrl-c*|ctrl-C*)
            printf '%s\n' '__cancel__'
            unset _fzf_input _fzf_out _rc _key _result _m
            return 0
            ;;
    esac

    case "${_result}" in
        '+ Add custom model…') printf '%s\n' '__custom__' ;;
        'x Manage saved models…') printf '%s\n' '__manage__' ;;
        *) printf '%s\n' "${_result}" ;;
    esac
    unset _fzf_input _fzf_out _rc _key _result _m
}

show_model_list() {
    _i=1
    printf '\n' >&2
    printf '  Available models\n' >&2
    printf '  ────────────────────────────────────────────\n' >&2
    for _m in "$@"; do
        printf '  %-3d %s\n' "${_i}" "${_m}" >&2
        _i=$(( _i + 1 ))
    done
    printf '  ────────────────────────────────────────────\n' >&2
    printf '  + Enter custom model…\n' >&2
    printf '  x Manage saved models…\n' >&2
    printf '\n' >&2
    unset _i _m
}

# Prints a model string | "__custom__" | "__manage__"
prompt_model_selection() {
    if _ui_has_fzf; then
        _ui_fzf_model_selection "$@"
        return $?
    fi

    _ui_warn_no_fzf

    _total="$#"
    # Positional params become the "array" we index into below.
    while true; do
        show_model_list "$@"
        printf '  Select (1–%d, +, m): ' "${_total}" >&2
        read -r _input

        case "${_input}" in
            '+') printf '%s\n' '__custom__'; unset _total _input; return 0 ;;
            'm') printf '%s\n' '__manage__'; unset _total _input; return 0 ;;
        esac

        if is_int "${_input}" && [ "${_input}" -ge 1 ] && [ "${_input}" -le "${_total}" ]; then
            eval "_pick=\${$_input}"
            printf '%s\n' "${_pick}"
            unset _total _input _pick
            return 0
        fi

        warn "Enter a number 1–${_total}, '+' for custom, or 'm' to manage."
    done
}

# ── Custom model entry ───────────────────────────────────────────────────────

prompt_custom_model() {
    printf '\n' >&2
    printf '  Enter OpenRouter model: ' >&2
    read -r _input
    printf '%s\n' "${_input}"
    unset _input
}

prompt_save_model() {
    _model="${1}"
    printf '  Save "%s" for future sessions? (y/N) ' "${_model}" >&2
    read -r _input
    _lc=$(to_lower "${_input}")
    _rc=1
    [ "${_lc}" = 'y' ] && _rc=0
    unset _model _input _lc
    return "${_rc}"
}

# ── Saved model manager ──────────────────────────────────────────────────────

_ui_fzf_manage_menu() {
    if [ "$#" -eq 0 ]; then
        printf '\n' >&2
        printf '  No saved models. Press any key to go back.\n' >&2
        # Portable single-keypress read (no zsh `read -k1`).
        _old_stty=$(stty -g 2>/dev/null) || _old_stty=""
        stty -icanon -echo 2>/dev/null
        dd bs=1 count=1 2>/dev/null >/dev/null
        [ -n "${_old_stty}" ] && stty "${_old_stty}" 2>/dev/null
        printf '%s\n' '__back__'
        unset _old_stty
        return 0
    fi

    _fzf_input=""
    for _m in "$@"; do
        _fzf_input="${_fzf_input}${_m}
"
    done
    _fzf_input="${_fzf_input}← Back"

    _fzf_out=$(
        printf '%s' "${_fzf_input}" \
        | fzf \
            --prompt '  Delete saved model › ' \
            --height '~60%' \
            --layout reverse \
            --border rounded \
            --no-preview \
            --header '  Select a model to DELETE it · Esc back · Ctrl+C cancel' \
            --expect=ctrl-c \
            2>/dev/tty
    )
    _rc=$?

    if [ "${_rc}" -ne 0 ]; then
        printf '%s\n' '__back__'
        unset _fzf_input _fzf_out _rc _m
        return 0
    fi

    _key=$(printf '%s' "${_fzf_out}" | head -n 1)
    _result=$(printf '%s' "${_fzf_out}" | tail -n +2)

    case "${_key}" in
        ctrl-c*|ctrl-C*)
            printf '%s\n' '__cancel__'
            unset _fzf_input _fzf_out _rc _key _result _m
            return 0
            ;;
    esac

    if [ "${_result}" = '← Back' ] || [ -z "${_result}" ]; then
        printf '%s\n' '__back__'
        unset _fzf_input _fzf_out _rc _key _result _m
        return 0
    fi

    printf '%s\n' "${_result}"
    unset _fzf_input _fzf_out _rc _key _result _m
}

# Prints a model string to delete | "__back__"
show_manage_menu() {
    if _ui_has_fzf; then
        _ui_fzf_manage_menu "$@"
        return $?
    fi

    _ui_warn_no_fzf

    _total="$#"

    while true; do
        printf '\n' >&2
        printf '  Saved models\n' >&2
        printf '  ────────────────────────────────────────────\n' >&2
        if [ "${_total}" -eq 0 ]; then
            printf '  (none)\n' >&2
        else
            _i=1
            for _m in "$@"; do
                printf '  %-3d %s\n' "${_i}" "${_m}" >&2
                _i=$(( _i + 1 ))
            done
        fi
        printf '\n' >&2
        if [ "${_total}" -gt 0 ]; then
            printf '  d<n>  Delete  (e.g. d2)\n' >&2
        fi
        printf '  b     Back\n' >&2
        printf '\n' >&2
        printf '  > ' >&2
        read -r _input

        case "${_input}" in
            b) printf '%s\n' '__back__'; unset _total _i _m _input; return 0 ;;
            d[0-9]*)
                if [ "${_total}" -eq 0 ]; then
                    warn "No saved models to delete."
                    continue
                fi
                _idx="${_input#d}"
                if is_int "${_idx}" && [ "${_idx}" -ge 1 ] && [ "${_idx}" -le "${_total}" ]; then
                    eval "_pick=\${$_idx}"
                    printf '%s\n' "${_pick}"
                    unset _total _i _m _input _idx _pick
                    return 0
                fi
                warn "Invalid index. Use d1–d${_total}."
                ;;
            *) warn "Unknown command. Use d<n> or b." ;;
        esac
    done
}

# ── Routing mode ─────────────────────────────────────────────────────────────

_ui_fzf_routing_mode() {
    _fzf_out=$(
        printf '%s\n%s\n' \
            '1• Direct  — export model directly, no routing' \
            '2• Preset  — provider ordering + OpenRouter preset' \
        | fzf \
            --prompt '  Launch mode › ' \
            --height '~40%' \
            --layout reverse \
            --border rounded \
            --no-preview \
            --header '  Enter to select · Esc back · Ctrl+C cancel' \
            --expect=ctrl-c \
            2>/dev/tty
    )
    _rc=$?

    if [ "${_rc}" -ne 0 ]; then
        unset _fzf_out _rc
        return 1
    fi

    _key=$(printf '%s' "${_fzf_out}" | head -n 1)
    _result=$(printf '%s' "${_fzf_out}" | tail -n +2)

    case "${_key}" in
        ctrl-c*|ctrl-C*)
            printf '%s\n' '__cancel__'
            unset _fzf_out _rc _key _result
            return 0
            ;;
    esac

    case "${_result}" in
        '1•'*) printf '%s\n' 'direct' ;;
        '2•'*) printf '%s\n' 'preset' ;;
        *)     unset _fzf_out _rc _key _result; return 1 ;;
    esac
    unset _fzf_out _rc _key _result
}

# Prints "direct" or "preset"
prompt_routing_mode() {
    if _ui_has_fzf; then
        _ui_fzf_routing_mode
        return $?
    fi

    _ui_warn_no_fzf

    printf '\n' >&2
    printf '  Launch mode\n' >&2
    printf '  ────────────────────────────────────────────\n' >&2
    printf '  1  Direct   (export model directly, no routing)\n' >&2
    printf '  2  Preset   (provider ordering + OpenRouter preset)\n' >&2
    printf '\n' >&2

    while true; do
        printf '  Select (1/2): ' >&2
        read -r _input
        case "${_input}" in
            1) printf '%s\n' 'direct'; unset _input; return 0 ;;
            2) printf '%s\n' 'preset'; unset _input; return 0 ;;
            *) warn "Enter 1 for Direct or 2 for Preset." ;;
        esac
    done
}

# ── Provider intelligence table display ──────────────────────────────────────
#
# BUGFIX (second pass): this table is now shown ONLY on the no-fzf path.
# When fzf is available, every row in the fzf picker already carries the
# same cost/uptime/latency/throughput fields inline (see
# provider_intel_fzf_line in provider_intel.sh) — printing this boxed table
# first, then opening fzf with identical data one line format later, means
# the same 18-20 rows appear twice in a row on screen. That double-print is
# the actual leak: not the numbered index list (fixed in the first pass),
# but this table itself. The full detailed view remains available; it just
# no longer prints unconditionally ahead of a picker that already shows it.

show_provider_intelligence() {
    _intel_arr="${1:-[]}"

    if _ui_has_fzf; then
        unset _intel_arr
        return 0
    fi

    _count=$(printf '%s' "${_intel_arr}" | jq 'length' 2>/dev/null || printf '%s' 0)
    [ "${_count}" -eq 0 ] && { unset _intel_arr _count; return 0; }

    printf '\n' >&2
    printf '  ── Provider Intelligence (cached metadata) ──────────────────\n' >&2
    provider_intel_table "${_intel_arr}" >&2
    unset _intel_arr _count
}

# ── Provider table (plain numbered display — NO-FZF FALLBACK ONLY) ──────────
# This numbered "#  Provider" list exists solely as the index reference for
# the no-fzf text-input fallback in prompt_provider_order(). It must never be
# printed on the fzf path — fzf's own picker already shows and searches the
# provider names interactively, so the numbered list would be redundant,
# unusable (fzf selection isn't done by typing numbers), and confusing
# leftover UI. Call this only from the non-fzf branch.

show_provider_table() {
    _i=1
    printf '  #   Provider\n' >&2
    printf '  ─   ────────\n' >&2
    for _p in "$@"; do
        printf '  %-3d %s\n' "${_i}" "${_p}" >&2
        _i=$(( _i + 1 ))
    done
    printf '\n' >&2
    unset _i _p
}

# ── Provider ordering (fzf multi-select with live sort) ──────────────────────
#
# Sort is implemented by writing pre-sorted temp files and using fzf --bind
# to reload from the appropriate file. This approach:
#   - Works on all fzf versions (reload action available since fzf 0.21, 2020)
#   - Requires no shell quoting inside --bind arguments
#   - Is fully non-destructive: sorted files are temp, original array unchanged

_ui_fzf_provider_order() {
    _intel_arr="${_ROUTER_PROVIDER_INTEL:-[]}"

    # Write one temp file per sort order + one for raw intel JSON + one for help guide.
    _tmp_name=$(mktemp)  || { warn "Cannot create temp file."; return 1; }
    _tmp_cost=$(mktemp)  || { rm -f "${_tmp_name}"; warn "Cannot create temp file."; return 1; }
    _tmp_lat=$(mktemp)   || { rm -f "${_tmp_name}" "${_tmp_cost}"; warn "Cannot create temp file."; return 1; }
    _tmp_up=$(mktemp)    || { rm -f "${_tmp_name}" "${_tmp_cost}" "${_tmp_lat}"; warn "Cannot create temp file."; return 1; }
    _tmp_tp=$(mktemp)    || { rm -f "${_tmp_name}" "${_tmp_cost}" "${_tmp_lat}" "${_tmp_up}"; warn "Cannot create temp file."; return 1; }
    _tmp_intel=$(mktemp) || { rm -f "${_tmp_name}" "${_tmp_cost}" "${_tmp_lat}" "${_tmp_up}" "${_tmp_tp}"; warn "Cannot create temp file."; return 1; }
    _tmp_help=$(mktemp)  || { rm -f "${_tmp_name}" "${_tmp_cost}" "${_tmp_lat}" "${_tmp_up}" "${_tmp_tp}" "${_tmp_intel}"; warn "Cannot create temp file."; return 1; }

    printf '%s' "${_intel_arr}" > "${_tmp_intel}"

    cat << 'EOF' > "${_tmp_help}"
  SELECTION & NAVIGATION
  · TAB          Select provider (select in order of priority)
  · Enter        Confirm priority selection
  · Esc          Go back to previous menu
  · Ctrl+C       Cancel & exit

  SORTING SHORTCUTS
  · s            Sort by Cost (cheapest first)
  · l            Sort by Latency (fastest TTFT first)
  · u            Sort by Uptime (highest uptime % first)
  · t            Sort by Throughput (tokens/sec highest)
  · n            Sort by Name (alphabetical A-Z)

  PREVIEW CARDS & HELP
  · v            Toggle provider metrics info card
  · ?            Toggle this help guide
EOF

    # Populate all sort files. Falls back to provider name only when no intel.
    _has_intel=0
    _count=$(printf '%s' "${_intel_arr}" | jq 'length' 2>/dev/null || printf '%s' 0)
    [ "${_count}" -gt 0 ] && _has_intel=1

    if [ "${_has_intel}" -eq 1 ]; then
        provider_intel_write_sorted "${_tmp_name}" "${_intel_arr}" "name"
        provider_intel_write_sorted "${_tmp_cost}" "${_intel_arr}" "cost"
        provider_intel_write_sorted "${_tmp_lat}"  "${_intel_arr}" "latency"
        provider_intel_write_sorted "${_tmp_up}"   "${_intel_arr}" "uptime"
        provider_intel_write_sorted "${_tmp_tp}"   "${_intel_arr}" "throughput"
    else
        # No intel — write bare provider names to all files (same content).
        : > "${_tmp_name}"
        for _p in "$@"; do
            printf '%s\n' "${_p}" >> "${_tmp_name}"
        done
        cp "${_tmp_name}" "${_tmp_cost}"
        cp "${_tmp_name}" "${_tmp_lat}"
        cp "${_tmp_name}" "${_tmp_up}"
        cp "${_tmp_name}" "${_tmp_tp}"
    fi

    _fzf_out=$(
        fzf \
            --prompt '  Providers › ' \
            --multi \
            --height '~100%' \
            --layout reverse \
            --border rounded \
            --preview ". \"${_ROUTER_DIR}/provider_intel.sh\"; provider_intel_verbose {1} \"\$(cat ${_tmp_intel})\"" \
            --preview-window 'right:55%:hidden' \
            --header "  Model: ${_ROUTER_MODEL:-unknown}  ·  TAB select  ·  s/l/u/t/n sort  ·  v info  ·  ? help" \
            --expect=ctrl-c \
            --bind "s:reload(cat ${_tmp_cost})" \
            --bind "l:reload(cat ${_tmp_lat})" \
            --bind "u:reload(cat ${_tmp_up})" \
            --bind "t:reload(cat ${_tmp_tp})" \
            --bind "n:reload(cat ${_tmp_name})" \
            --bind "v:change-preview(. \"${_ROUTER_DIR}/provider_intel.sh\"; provider_intel_verbose {1} \"\$(cat ${_tmp_intel})\")+toggle-preview" \
            --bind "?:change-preview(cat ${_tmp_help})+toggle-preview" \
            --bind "ctrl-/:change-preview(cat ${_tmp_help})+toggle-preview" \
            < "${_tmp_name}" \
            2>/dev/tty
    )
    _rc=$?
    rm -f "${_tmp_name}" "${_tmp_cost}" "${_tmp_lat}" "${_tmp_up}" "${_tmp_tp}" "${_tmp_intel}" "${_tmp_help}"

    if [ "${_rc}" -ne 0 ]; then
        unset _intel_arr _tmp_name _tmp_cost _tmp_lat _tmp_up _tmp_tp _tmp_intel _tmp_help _has_intel _count _p _fzf_out _rc
        return 1
    fi

    _key=$(printf '%s' "${_fzf_out}" | head -n 1)
    _selected_lines=$(printf '%s' "${_fzf_out}" | tail -n +2)

    case "${_key}" in
        ctrl-c*|ctrl-C*)
            unset _intel_arr _tmp_name _tmp_cost _tmp_lat _tmp_up _tmp_tp _tmp_intel _has_intel _count _p _fzf_out _rc _key _selected_lines
            return 2
            ;;
    esac
    if [ -z "${_selected_lines}" ]; then
        warn "No providers selected."
        unset _intel_arr _tmp_name _tmp_cost _tmp_lat _tmp_up _tmp_tp _tmp_intel _has_intel _count _p _selected_lines _rc
        return 1
    fi

    # Extract provider name: first whitespace-delimited token on each line.
    # provider_intel_fzf_line guarantees the name is the first token with no
    # embedded spaces (OpenRouter provider names never contain spaces).
    printf '%s\n' "${_selected_lines}" | while IFS= read -r _line; do
        [ -z "${_line}" ] && continue
        _pname="${_line%%[[:space:]]*}"
        [ -n "${_pname}" ] && printf '%s\n' "${_pname}"
    done

    unset _intel_arr _tmp_name _tmp_cost _tmp_lat _tmp_up _tmp_tp _tmp_intel _has_intel _count _p _selected_lines _rc
}

# Prints ordered provider names (newline-separated) to stdout.
#
# BUGFIX: the no-fzf reference table (show_provider_table) is now printed
# HERE, inside the non-fzf branch only — never unconditionally by the
# caller. This is the fix for the "fallback UI leaking into the fzf UI" bug:
# previously router_engine printed the numbered table before calling this
# function no matter which path would run, so it appeared even when fzf was
# about to take over with its own picker.
prompt_provider_order() {
    if _ui_has_fzf; then
        _ui_fzf_provider_order "$@"
        return $?
    fi

    _ui_warn_no_fzf
    show_provider_table "$@"

    # Stash providers in a temp file (indexed by line number) so parsing the
    # user's typed indices below never has to touch/clobber "$@".
    _pi_providers_file=$(mktemp) || { warn "Cannot create temp file."; return 1; }
    for _p in "$@"; do
        printf '%s\n' "${_p}" >> "${_pi_providers_file}"
    done
    _total="$#"

    while true; do
        printf '  Enter provider priority (e.g. 2 1 3): ' >&2
        read -r _input

        if [ -z "${_input}" ]; then
            warn "Enter at least one provider index."
            continue
        fi

        _valid=1
        for _t in ${_input}; do
            if ! is_int "${_t}" || [ "${_t}" -lt 1 ] || [ "${_t}" -gt "${_total}" ]; then
                warn "\"${_t}\" is not a valid index (1–${_total})."
                _valid=0
                break
            fi
        done
        [ "${_valid}" -eq 1 ] || continue

        # Duplicate check.
        _seen=" "
        for _t in ${_input}; do
            case "${_seen}" in
                *" ${_t} "*)
                    warn "Index \"${_t}\" appears more than once."
                    _valid=0
                    break
                    ;;
            esac
            _seen="${_seen}${_t} "
        done
        [ "${_valid}" -eq 1 ] || continue

        for _t in ${_input}; do
            sed -n "${_t}p" "${_pi_providers_file}"
        done
        rm -f "${_pi_providers_file}"
        unset _pi_providers_file _total _input _valid _t _seen _p
        return 0
    done
}

# ── Preset menu (fzf unified, two-step) ──────────────────────────────────────
#
# Two-step design avoids --bind become (fzf >=0.36 only) and all inline
# shell quoting inside fzf arguments:
#   Step 1 — pick an item; tag prefix encodes type (ACTION: or PRESET:)
#   Step 2 — for presets, a second small fzf picks the action verb

_ui_fzf_preset_menu() {
    _model="${1:?_ui_fzf_preset_menu requires a model}"
    _presets_json="${2:?_ui_fzf_preset_menu requires presets JSON}"

    _total=$(printf '%s' "${_presets_json}" | jq 'length')

    # Build input: tagged lines so first token carries type:payload.
    _fzf_input="ACTION:__create__  + Create new preset"

    if [ "${_total}" -gt 0 ]; then
        _fzf_input="${_fzf_input}
SEP:------  ────────────────────────────────────────"
        _i=0
        while [ "${_i}" -lt "${_total}" ]; do
            _name=$(printf '%s' "${_presets_json}" | jq -r ".[${_i}].name")
            _slug=$(printf '%s' "${_presets_json}" | jq -r ".[${_i}].slug")
            _summary=$(printf '%s' "${_presets_json}" | jq -r \
                --argjson idx "${_i}" \
                '.[$idx].providers | map(.provider) | join(" → ")')
            _fzf_input="${_fzf_input}
PRESET:${_slug}  ⚡ ${_name}  [${_summary}]"
            _i=$(( _i + 1 ))
        done
    fi

    # Step 1: pick item. --with-nth hides the tag prefix from display.
    _fzf_out=$(
        printf '%s' "${_fzf_input}" \
        | fzf \
            --prompt "  Presets › " \
            --height '~100%' \
            --layout reverse \
            --border rounded \
            --no-preview \
            --with-nth '2..' \
            --delimiter ' ' \
            --header '  Enter select · Ctrl+i import · Ctrl+x export · Esc back · Ctrl+C cancel' \
            --expect=ctrl-i,ctrl-x,ctrl-c \
            2>/dev/tty
    )
    _rc=$?

    if [ "${_rc}" -ne 0 ]; then
        printf '%s\n' '__back__'
        unset _model _presets_json _total _fzf_input _i _name _slug _summary _fzf_out _rc
        return 0
    fi

    _key=$(printf '%s' "${_fzf_out}" | head -n 1)
    _raw_pick=$(printf '%s' "${_fzf_out}" | tail -n +2)

    case "${_key}" in
        ctrl-c*|ctrl-C*)
            printf '%s\n' '__cancel__'
            unset _model _presets_json _total _fzf_input _i _name _slug _summary _fzf_out _rc _key _raw_pick
            return 0
            ;;
        ctrl-i*|ctrl-I*)
            printf '%s\n' '__import__'
            unset _model _presets_json _total _fzf_input _i _name _slug _summary _fzf_out _rc _key _raw_pick
            return 0
            ;;
        ctrl-x*|ctrl-X*)
            printf '%s\n' '__export__'
            unset _model _presets_json _total _fzf_input _i _name _slug _summary _fzf_out _rc _key _raw_pick
            return 0
            ;;
    esac

    if [ -z "${_raw_pick}" ]; then
        printf '%s\n' '__back__'
        unset _model _presets_json _total _fzf_input _i _name _slug _summary _fzf_out _rc _key _raw_pick
        return 0
    fi

    # Decode the tag prefix (first space-delimited token of the raw line).
    _first_token="${_raw_pick%%[[:space:]]*}"
    _tag="${_first_token%%:*}"
    _payload="${_first_token#*:}"

    case "${_tag}" in
        ACTION)
            printf '%s\n' "${_payload}"
            unset _model _presets_json _total _fzf_input _i _name _slug _summary _fzf_out _rc _key _raw_pick _first_token _tag _payload
            return 0
            ;;
        PRESET)
            # Step 2: pick action for this preset.
            _slug="${_payload}"
            _action_out=$(
                printf '%s\n%s\n%s\n%s\n' \
                    "launch  Launch this preset" \
                    "edit    Edit provider order" \
                    "rename  Rename" \
                    "delete  Delete" \
                | fzf \
                    --prompt "  Action › " \
                    --height '~50%' \
                    --layout reverse \
                    --border rounded \
                    --no-preview \
                    --with-nth '2..' \
                    --delimiter ' ' \
                    --header '  Enter select · Esc back · Ctrl+C cancel' \
                    --expect=ctrl-c \
                    2>/dev/tty
            )
            _rc2=$?
            if [ "${_rc2}" -ne 0 ]; then
                printf '%s\n' '__back__'
                unset _model _presets_json _total _fzf_input _i _name _slug _summary _raw_pick _first_token _tag _payload _action_out _rc2
                return 0
            fi

            _key2=$(printf '%s' "${_action_out}" | head -n 1)
            _action_line=$(printf '%s' "${_action_out}" | tail -n +2)

            case "${_key2}" in
                ctrl-c*|ctrl-C*)
                    printf '%s\n' '__cancel__'
                    unset _model _presets_json _total _fzf_input _i _name _slug _summary _raw_pick _first_token _tag _payload _action_out _rc2 _key2 _action_line
                    return 0
                    ;;
            esac

            _verb="${_action_line%%[[:space:]]*}"
            if [ -z "${_verb}" ]; then
                printf '%s\n' '__back__'
                unset _model _presets_json _total _fzf_input _i _name _slug _summary _raw_pick _first_token _tag _payload _action_out _rc2 _key2 _action_line _verb
                return 0
            fi
            printf '%s:%s\n' "${_verb}" "${_slug}"
            unset _model _presets_json _total _fzf_input _i _name _slug _summary _raw_pick _first_token _tag _payload _action_out _rc2 _key2 _action_line _verb
            return 0
            ;;
        *)
            printf '%s\n' '__back__'
            unset _model _presets_json _total _fzf_input _i _name _slug _summary _raw_pick _first_token _tag _payload
            return 0
            ;;
    esac
}

# Displays a preset list and prompts for an action.
# Prints: "launch:<slug>" | "edit:<slug>" | "rename:<slug>" | "delete:<slug>"
#       | "__create__" | "__import__" | "__export__" | "__back__"
show_preset_menu() {
    _model="${1:?show_preset_menu requires a model}"
    _presets_json="${2:?show_preset_menu requires a presets JSON array}"

    if _ui_has_fzf; then
        _ui_fzf_preset_menu "${_model}" "${_presets_json}"
        return $?
    fi

    _ui_warn_no_fzf

    # ── Numbered-list fallback (original implementation, unchanged) ─────────
    _total=$(printf '%s' "${_presets_json}" | jq 'length')

    while true; do
        printf '\n' >&2
        printf '  Presets for\n\n  %s\n\n' "${_model}" >&2
        printf '  ────────────────────────────────────────────\n' >&2

        if [ "${_total}" -eq 0 ]; then
            printf '  (no presets yet)\n' >&2
        else
            _i=0
            while [ "${_i}" -lt "${_total}" ]; do
                _name=$(printf '%s' "${_presets_json}" | jq -r ".[${_i}].name")
                _summary=$(printf '%s' "${_presets_json}" \
                    | jq -r --argjson idx "${_i}" \
                        '.[$idx].providers | map(.provider) | join(" → ")')
                printf '  %-3d ⚡ %s\n' "$(( _i + 1 ))" "${_name}" >&2
                printf '      %s\n' "${_summary}" >&2
                _i=$(( _i + 1 ))
            done
        fi

        printf '\n' >&2
        printf '  ────────────────────────────────────────────\n' >&2
        printf '  +       Create new preset\n' >&2
        printf '  i       Import backup\n' >&2
        printf '  x       Export backup\n' >&2
        printf '  ────────────────────────────────────────────\n' >&2
        if [ "${_total}" -gt 0 ]; then
            printf '  <n>     Launch preset  (e.g. 1)\n' >&2
            printf '  e<n>    Edit preset    (e.g. e2)\n' >&2
            printf '  r<n>    Rename preset  (e.g. r1)\n' >&2
            printf '  d<n>    Delete preset  (e.g. d3)\n' >&2
        fi
        printf '  b       Back to model selection\n' >&2
        printf '\n' >&2
        printf '  > ' >&2
        read -r _input

        case "${_input}" in
            '+') printf '%s\n' '__create__'; return 0 ;;
            i)   printf '%s\n' '__import__'; return 0 ;;
            x)   printf '%s\n' '__export__'; return 0 ;;
            b)   printf '%s\n' '__back__';   return 0 ;;

            [0-9]*)
                if [ "${_total}" -eq 0 ]; then warn "No presets yet. Create one with '+'."; continue; fi
                if is_int "${_input}" && [ "${_input}" -ge 1 ] && [ "${_input}" -le "${_total}" ]; then
                    _slug=$(printf '%s' "${_presets_json}" | jq -r ".[$(( _input - 1 ))].slug")
                    printf 'launch:%s\n' "${_slug}"; return 0
                fi
                warn "Invalid number. Choose 1–${_total}."
                ;;

            e[0-9]*)
                if [ "${_total}" -eq 0 ]; then warn "No presets yet."; continue; fi
                _idx="${_input#e}"
                if is_int "${_idx}" && [ "${_idx}" -ge 1 ] && [ "${_idx}" -le "${_total}" ]; then
                    _slug=$(printf '%s' "${_presets_json}" | jq -r ".[$(( _idx - 1 ))].slug")
                    printf 'edit:%s\n' "${_slug}"; return 0
                fi
                warn "Invalid index. Use e1–e${_total}."
                ;;

            r[0-9]*)
                if [ "${_total}" -eq 0 ]; then warn "No presets yet."; continue; fi
                _idx="${_input#r}"
                if is_int "${_idx}" && [ "${_idx}" -ge 1 ] && [ "${_idx}" -le "${_total}" ]; then
                    _slug=$(printf '%s' "${_presets_json}" | jq -r ".[$(( _idx - 1 ))].slug")
                    printf 'rename:%s\n' "${_slug}"; return 0
                fi
                warn "Invalid index. Use r1–r${_total}."
                ;;

            d[0-9]*)
                if [ "${_total}" -eq 0 ]; then warn "No presets yet."; continue; fi
                _idx="${_input#d}"
                if is_int "${_idx}" && [ "${_idx}" -ge 1 ] && [ "${_idx}" -le "${_total}" ]; then
                    _slug=$(printf '%s' "${_presets_json}" | jq -r ".[$(( _idx - 1 ))].slug")
                    printf 'delete:%s\n' "${_slug}"; return 0
                fi
                warn "Invalid index. Use d1–d${_total}."
                ;;

            *) warn "Unknown command. See options above." ;;
        esac
    done
}

# ── Preset name / rename / delete prompts ────────────────────────────────────

prompt_preset_name() {
    _default="${1:-}"
    if [ -n "${_default}" ]; then
        printf '  Preset name [%s]: ' "${_default}" >&2
    else
        printf '  Preset name: ' >&2
    fi
    read -r _input
    if [ -z "${_input}" ] && [ -n "${_default}" ]; then
        printf '%s\n' "${_default}"
    else
        printf '%s\n' "${_input}"
    fi
    unset _default _input
}

prompt_rename_preset() {
    _current="${1:?prompt_rename_preset requires current name}"

    printf '\n' >&2
    printf '  Rename preset\n' >&2
    printf '  Current: %s\n' "${_current}" >&2
    printf '  New name: ' >&2
    read -r _new_name

    if [ -z "${_new_name}" ]; then
        printf '%s\n' '__cancel__'
        unset _current _new_name
        return 0
    fi

    printf '  Rename to "%s"? (y/N) ' "${_new_name}" >&2
    read -r _input
    _lc=$(to_lower "${_input}")
    if [ "${_lc}" = 'y' ]; then
        printf 'confirmed:%s\n' "${_new_name}"
    else
        printf '%s\n' '__cancel__'
    fi
    unset _current _new_name _input _lc
}

prompt_delete_preset() {
    _name="${1:?prompt_delete_preset requires name}"
    _model="${2:?prompt_delete_preset requires model}"
    printf '\n' >&2
    printf '  Delete preset "%s" for %s? (y/N) ' "${_name}" "${_model}" >&2
    read -r _input
    _lc=$(to_lower "${_input}")
    _rc=1
    [ "${_lc}" = 'y' ] && _rc=0
    unset _name _model _input _lc
    return "${_rc}"
}

# ── Backup prompts ───────────────────────────────────────────────────────────

prompt_import_file() {
    printf '\n' >&2
    printf '  Import backup file: ' >&2
    read -r _input
    printf '%s\n' "${_input}"
    unset _input
}

prompt_import_mode() {
    if _ui_has_fzf; then
        _fzf_out=$(
            printf '%s\n%s\n' \
                'merge   — keep existing, add imported' \
                'replace — overwrite all existing data' \
            | fzf \
                --prompt '  Import mode › ' \
                --height '~20%' \
                --layout reverse \
                --border rounded \
                --no-preview \
                --header '  Enter select · Esc back · Ctrl+C cancel' \
                --expect=ctrl-c \
                2>/dev/tty
        )
        _rc=$?
        if [ "${_rc}" -ne 0 ]; then
            unset _fzf_out _rc
            return 1
        fi

        _key=$(printf '%s' "${_fzf_out}" | head -n 1)
        _result=$(printf '%s' "${_fzf_out}" | tail -n +2)

        case "${_key}" in
            ctrl-c*|ctrl-C*)
                printf '%s\n' '__cancel__'
                unset _fzf_out _rc _key _result
                return 0
                ;;
        esac

        case "${_result}" in
            merge*)   printf '%s\n' 'merge';   unset _fzf_out _rc _key _result; return 0 ;;
            replace*) printf '%s\n' 'replace'; unset _fzf_out _rc _key _result; return 0 ;;
        esac
    fi

    _ui_warn_no_fzf
    printf '\n' >&2
    printf '  Import mode\n' >&2
    printf '  1  Merge   (keep existing, add imported)\n' >&2
    printf '  2  Replace (overwrite all existing data)\n' >&2
    printf '\n' >&2
    while true; do
        printf '  Select (1/2): ' >&2
        read -r _input
        case "${_input}" in
            1) printf '%s\n' 'merge';   unset _input; return 0 ;;
            2) printf '%s\n' 'replace'; unset _input; return 0 ;;
            *) warn "Enter 1 or 2." ;;
        esac
    done
}

# ── Feedback ──────────────────────────────────────────────────────────────────

show_success() {
    _value="${1:-}"
    printf '\n'
    printf '  ✓  OPENROUTER_MODEL=%s\n' "${_value}"
    printf '\n'
    unset _value
}

show_error() {
    _message="${1:-An unexpected error occurred.}"
    printf '\n'
    printf '  ✘  %s\n' "${_message}" >&2
    printf '\n'
    unset _message
}
