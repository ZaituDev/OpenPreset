#!/usr/bin/env sh
# router_engine.sh — main orchestrator
# The only file that braining and superpowers source.
# Defines one public function: openpreset_router
# All business logic lives here; modules handle one concern each.
#
# Portable POSIX sh — no zsh required. Runs under bash, dash, ksh, and any
# other POSIX-compliant shell. Sourced by a launcher, so it must never call
# `exit` (only `return`), or it would kill the caller's shell.

# ── Bootstrap ────────────────────────────────────────────────────────────────
# Resolve this file's own directory portably (works for `source`/`.` under
# bash, dash, and ksh alike — unlike zsh's ${(%):-%x}, POSIX sh has no
# built-in "path of the currently-sourcing file", so callers are expected to
# export _ROUTER_DIR themselves right before sourcing this file. See the
# launchers (launchers/cr, extras/launchers/*) for the resolution pattern.

if [ -z "${_ROUTER_DIR:-}" ]; then
    printf '%s\n' "✘ _ROUTER_DIR is not set — source this file only via a launcher." >&2
    return 1 2>/dev/null || exit 1
fi

# shellcheck source=config.sh
. "${_ROUTER_DIR}/config.sh"
# shellcheck source=utils.sh
. "${_ROUTER_DIR}/utils.sh"
# shellcheck source=cache.sh
. "${_ROUTER_DIR}/cache.sh"
# shellcheck source=openrouter.sh
. "${_ROUTER_DIR}/openrouter.sh"
# shellcheck source=preset.sh
. "${_ROUTER_DIR}/preset.sh"
# shellcheck source=backup.sh
. "${_ROUTER_DIR}/backup.sh"
# shellcheck source=provider_intel.sh
. "${_ROUTER_DIR}/provider_intel.sh"
# shellcheck source=ui.sh
. "${_ROUTER_DIR}/ui.sh"

# ══════════════════════════════════════════════════════════════════════════
# Public entry point
# ══════════════════════════════════════════════════════════════════════════

openpreset_router() {
    _router_validate_environment || return 1
    show_banner

    _step=1
    while true; do
        case "${_step}" in
            1)
                _rc_s1=0
                _router_select_model || _rc_s1=$?
                if [ "${_rc_s1}" -ne 0 ]; then
                    return 1
                fi
                _step=2
                ;;
            2)
                _rc_s2=0
                _router_select_routing_mode || _rc_s2=$?
                if [ "${_rc_s2}" -ne 0 ]; then
                    if [ "${_rc_s2}" -eq 2 ] || [ "${OPENPRESET_MODEL}" != '__pick__' ]; then
                        return 1
                    fi
                    _step=1
                    continue
                fi
                _step=3
                ;;
            3)
                case "${_ROUTER_MODE}" in
                    direct)
                        _router_run_direct
                        return 0
                        ;;
                    preset)
                        _rc_s3=0
                        _router_run_preset || _rc_s3=$?
                        if [ "${_rc_s3}" -eq 0 ]; then
                            return 0
                        fi
                        if [ "${_rc_s3}" -eq 2 ]; then
                            return 1
                        fi
                        if [ -n "${OPENPRESET_MODE:-}" ] && [ "${OPENPRESET_MODE}" != '__pick__' ]; then
                            _step=1
                        else
                            _step=2
                        fi
                        continue
                        ;;
                esac
                ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════════════════
# Internals — prefixed _router_, not part of the public API
# ══════════════════════════════════════════════════════════════════════════

# ── Step 1 — Validate environment (no network) ──────────────────────────────

_router_validate_environment() {
    _missing=""
    command -v curl > /dev/null 2>&1 || _missing="${_missing}curl "
    command -v jq   > /dev/null 2>&1 || _missing="${_missing}jq "

    if [ -n "${_missing}" ]; then
        die "Missing required dependencies: ${_missing}
  Install them with your package manager, e.g.:
    brew install ${_missing}
    apt-get install ${_missing}"
        unset _missing
        return 1
    fi
    unset _missing

    [ -n "${OPENROUTER_API_KEY}" ] \
        || { die "OPENROUTER_API_KEY is not set."; return 1; }
    [ -n "${OPENPRESET_MODEL}" ] \
        || { die "OPENPRESET_MODEL is not set."; return 1; }
}

# ── Step 2 — Model selection ────────────────────────────────────────────────
#
# POSIX sh has no arrays, so model lists are carried as newline-separated
# strings and iterated with `while IFS= read -r`.

_router_select_model() {
    if [ "${OPENPRESET_MODEL}" != '__pick__' ]; then
        _ROUTER_MODEL="${OPENPRESET_MODEL}"
        return 0
    fi

    _default_models="${OPENPRESET_DEFAULT_MODELS}"
    _user_models=$(_router_load_user_models)
    _all_models=$(_router_merge_model_lists "${_default_models}" "${_user_models}")

    while true; do
        _selection=$(_router_run_model_picker "${_all_models}")
        _rc_rmp=$?
        if [ "${_rc_rmp}" -ne 0 ]; then
            unset _default_models _user_models _all_models _selection
            return "${_rc_rmp}"
        fi

        case "${_selection}" in
            __cancel__)
                unset _default_models _user_models _all_models _selection
                return 2
                ;;
            __custom__)
                if _router_handle_custom_model "${_all_models}"; then
                    unset _default_models _user_models _all_models _selection
                    return 0
                fi
                continue
                ;;
            __manage__)
                _rc_hmm=0
                _router_handle_manage_menu || _rc_hmm=$?
                if [ "${_rc_hmm}" -eq 2 ]; then
                    unset _default_models _user_models _all_models _selection
                    return 2
                fi
                _user_models=$(_router_load_user_models)
                _all_models=$(_router_merge_model_lists "${_default_models}" "${_user_models}")
                continue
                ;;
            *)
                _ROUTER_MODEL="${_selection}"
                unset _default_models _user_models _all_models _selection
                return 0
                ;;
        esac
    done
}

# Merge default models with user models, de-duplicated, defaults first.
# Usage: _router_merge_model_lists <newline-list> <newline-list>
_router_merge_model_lists() {
    _mml_defaults="${1}"
    _mml_users="${2}"
    {
        printf '%s\n' "${_mml_defaults}"
        printf '%s\n' "${_mml_users}"
    } | awk 'NF && !seen[$0]++'
    unset _mml_defaults _mml_users
}

# Run the model picker UI against a newline-separated model list.
# Prints the selection (model id, __custom__, or __manage__).
_router_run_model_picker() {
    _list="${1}"
    _rmp_ifs_backup="${IFS}"
    IFS='
'
    # shellcheck disable=SC2086
    set -- ${_list}
    IFS="${_rmp_ifs_backup}"
    prompt_model_selection "$@"
    unset _list _rmp_ifs_backup
}

_router_handle_custom_model() {
    _existing_models="${1}"

    while true; do
        _candidate=$(prompt_custom_model)
        [ -n "${_candidate}" ] || { unset _existing_models _candidate; return 1; }

        info "Validating \"${_candidate}\"…"
        if ! validate_model "${_candidate}"; then
            show_error "Model \"${_candidate}\" not found on OpenRouter."
            continue
        fi

        if prompt_save_model "${_candidate}"; then
            _router_append_user_model "${_candidate}"
        fi

        _ROUTER_MODEL="${_candidate}"
        unset _existing_models _candidate
        return 0
    done
}

_router_handle_manage_menu() {
    while true; do
        _saved=$(_router_load_user_models)
        _hmm_ifs_backup="${IFS}"
        IFS='
'
        # shellcheck disable=SC2086
        set -- ${_saved}
        IFS="${_hmm_ifs_backup}"

        _choice=$(show_manage_menu "$@")
        _rc_smm=$?
        if [ "${_rc_smm}" -ne 0 ]; then
            unset _saved _hmm_ifs_backup _choice
            return "${_rc_smm}"
        fi
        if [ "${_choice}" = '__cancel__' ]; then
            unset _saved _hmm_ifs_backup _choice
            return 2
        fi
        if [ "${_choice}" = '__back__' ]; then
            unset _saved _hmm_ifs_backup _choice
            return 0
        fi
        _router_delete_user_model "${_choice}"
        info "Removed \"${_choice}\"."
    done
}

# ── Step 3 — Routing mode ───────────────────────────────────────────────────

_router_select_routing_mode() {
    if [ -n "${OPENPRESET_MODE}" ]; then
        case "${OPENPRESET_MODE}" in
            direct|preset) _ROUTER_MODE="${OPENPRESET_MODE}"; return 0 ;;
            *) die "Unknown OPENPRESET_MODE: ${OPENPRESET_MODE}"; return 1 ;;
        esac
    fi
    _prm_res=$(prompt_routing_mode)
    _rc_prm=$?
    if [ "${_rc_prm}" -ne 0 ]; then
        return "${_rc_prm}"
    fi
    if [ "${_prm_res}" = '__cancel__' ]; then
        return 2
    fi
    _ROUTER_MODE="${_prm_res}"
    unset _prm_res
    return 0
}

# ── Direct mode ──────────────────────────────────────────────────────────────

_router_run_direct() {
    export OPENROUTER_MODEL="${_ROUTER_MODEL}"
    show_success "${_ROUTER_MODEL}"
}

# ── Preset mode ──────────────────────────────────────────────────────────────

_router_run_preset() {
    while true; do
        _presets_json=$(preset_load_all "${_ROUTER_MODEL}")
        _action=$(show_preset_menu "${_ROUTER_MODEL}" "${_presets_json}")
        _rc_spm=$?
        if [ "${_rc_spm}" -ne 0 ]; then
            unset _presets_json _action
            return "${_rc_spm}"
        fi
        if [ "${_action}" = '__cancel__' ]; then
            unset _presets_json _action
            return 2
        fi
        _verb="${_action%%:*}"
        _ref="${_action#*:}"

        case "${_verb}" in
            launch)      _router_preset_launch "${_ref}"  && { unset _presets_json _action _verb _ref; return 0; } ;;
            __create__)
                _rc_pc=0
                _router_preset_create || _rc_pc=$?
                if [ "${_rc_pc}" -eq 2 ]; then
                    unset _presets_json _action _verb _ref
                    return 2
                fi
                ;;
            edit)
                _rc_pe=0
                _router_preset_edit "${_ref}" || _rc_pe=$?
                if [ "${_rc_pe}" -eq 2 ]; then
                    unset _presets_json _action _verb _ref
                    return 2
                fi
                ;;
            rename)      _router_preset_rename "${_ref}"  || true ;;
            delete)      _router_preset_delete "${_ref}"  || true ;;
            __import__)  _router_preset_import           || true ;;
            __export__)  _router_preset_export           || true ;;
            __back__)    unset _presets_json _action _verb _ref; return 1 ;;
            *)
                printf '%s\n' "BUG: unexpected preset action [${_verb}]" >&2
                unset _presets_json _action _verb _ref
                return 1
                ;;
        esac
    done
}

# ── Endpoint cache ───────────────────────────────────────────────────────────

_router_ensure_providers() {
    _endpoint_cache_dir="${CACHE_DIR}/endpoints"
    _safe=$(printf '%s' "${_ROUTER_MODEL}" | tr '/' '-')
    _ecache="${_endpoint_cache_dir}/${_safe}.json"
    _ets="${_ecache}.timestamp"

    if [ -f "${_ecache}" ] && [ -f "${_ets}" ] \
        && [ $(( $(timestamp) - $(cat "${_ets}") )) -lt "${CACHE_TTL}" ]; then
        info "Using cached endpoint data for ${_ROUTER_MODEL}."
        _json=$(cat "${_ecache}")
    else
        if ! cache_valid; then
            verify_api_key || return 1
            refresh_cache  || return 1
        fi
        info "Fetching endpoints for ${_ROUTER_MODEL}…"
        _json=$(download_endpoints "${_ROUTER_MODEL}") \
            || { die "Could not fetch endpoints for ${_ROUTER_MODEL}."; return 1; }
        mkdir -p "${_endpoint_cache_dir}"
        printf '%s' "${_json}" > "${_ecache}"
        timestamp > "${_ets}"
    fi

    _providers_raw=$(
      printf '%s' "${_json}" |
      jq -r '
        .data?.endpoints? // []
        | map(.provider_name // empty)
        | unique
        | .[]
      '
    )

    _ROUTER_PROVIDERS=""
    while IFS= read -r _p; do
        [ -n "${_p}" ] || continue
        if [ -z "${_ROUTER_PROVIDERS}" ]; then
            _ROUTER_PROVIDERS="${_p}"
        else
            _ROUTER_PROVIDERS="${_ROUTER_PROVIDERS}
${_p}"
        fi
    done <<EOF
${_providers_raw}
EOF

    [ -n "${_ROUTER_PROVIDERS}" ] \
        || { die "No providers found for ${_ROUTER_MODEL}."; return 1; }
}

# ── Provider ordering ────────────────────────────────────────────────────────
#
# BUGFIX: _router_choose_provider_order used to call show_provider_intelligence()
# and show_provider_table() unconditionally, then prompt_provider_order() —
# so both the boxed cost/latency reference table AND the plain numbered
# "#  Provider" index list printed even when fzf was about to open its own
# picker right after, which already shows the same per-provider metrics
# inline on every row. That meant the same provider list appeared twice in a
# row, back to back, in two different formats — the actual leak. Both
# show_provider_intelligence() and show_provider_table() now self-gate on
# fzf availability (see ui.sh): each prints only on the code path that
# actually needs it, so exactly one view of the provider list is ever shown
# before the picker runs.

_router_choose_provider_order() {
    _router_ensure_providers || return 1

    _ROUTER_PROVIDER_INTEL=$(provider_intel_all "${_ROUTER_MODEL}")
    export _ROUTER_PROVIDER_INTEL

    if [ -n "${OPENPRESET_PROFILE}" ]; then
        case "${OPENPRESET_PROFILE}" in
            balanced)
                _ROUTER_ORDERED_PROVIDERS="${_ROUTER_PROVIDERS}"
                return 0
                ;;
            *)
                die "Unknown OPENPRESET_PROFILE: ${OPENPRESET_PROFILE}"
                return 1
                ;;
        esac
    fi

    # show_provider_intelligence self-gates: it only prints when fzf is
    # unavailable (see ui.sh). When fzf is present, this call is a no-op and
    # the fzf picker's own per-row metrics are the only view shown.
    show_provider_intelligence "${_ROUTER_PROVIDER_INTEL:-[]}"

    _cpo_ifs_backup="${IFS}"
    IFS='
'
    # shellcheck disable=SC2086
    set -- ${_ROUTER_PROVIDERS}
    IFS="${_cpo_ifs_backup}"

    _ordered_rc=0
    _ordered=$(prompt_provider_order "$@") || _ordered_rc=$?
    if [ "${_ordered_rc}" -ne 0 ]; then
        unset _cpo_ifs_backup _ordered
        return "${_ordered_rc}"
    fi
    _ROUTER_ORDERED_PROVIDERS="${_ordered}"
    unset _cpo_ifs_backup _ordered
}

# ── Preset actions ───────────────────────────────────────────────────────────

_router_preset_launch() {
    _slug="${1:?_router_preset_launch requires a slug}"
    export OPENROUTER_MODEL="@preset/${_slug}"
    show_success "@preset/${_slug}"
    unset _slug
}

_router_preset_create() {
    _rc_cpo=0
    _router_choose_provider_order || _rc_cpo=$?
    if [ "${_rc_cpo}" -ne 0 ]; then
        return "${_rc_cpo}"
    fi

    _presets_json=$(preset_load_all "${_ROUTER_MODEL}")
    _count=$(printf '%s' "${_presets_json}" | jq 'length')
    _default_name="Preset $(( _count + 1 ))"

    _name=$(prompt_preset_name "${_default_name}")
    [ -n "${_name}" ] || _name="${_default_name}"

    _slug=$(preset_slug "${_ROUTER_MODEL}" "${_name}")
    _providers_json=$(_router_providers_array_from_ordered)
    _payload=$(preset_payload "${_slug}" "${_ROUTER_MODEL}" "${_providers_json}")

    create_or_update_preset "${_slug}" "${_payload}" \
        || { die "Could not create preset on OpenRouter."; unset _presets_json _count _default_name _name _slug _providers_json _payload; return 1; }

    preset_upsert "${_ROUTER_MODEL}" "${_slug}" "${_name}" "${_providers_json}"
    info "Preset \"${_name}\" created."
    unset _presets_json _count _default_name _name _slug _providers_json _payload
}

# Build a providers JSON array from _ROUTER_ORDERED_PROVIDERS (newline list).
_router_providers_array_from_ordered() {
    _rpafo_ifs_backup="${IFS}"
    IFS='
'
    # shellcheck disable=SC2086
    set -- ${_ROUTER_ORDERED_PROVIDERS}
    IFS="${_rpafo_ifs_backup}"
    providers_array_from_names "$@"
    unset _rpafo_ifs_backup
}

_router_preset_edit() {
    _slug="${1:?_router_preset_edit requires a slug}"

    _presets_json=$(preset_load_all "${_ROUTER_MODEL}")
    _name=$(printf '%s' "${_presets_json}" \
        | jq -r --arg s "${_slug}" '.[] | select(.slug==$s) | .name')

    [ -n "${_name}" ] || { die "Preset \"${_slug}\" not found."; unset _slug _presets_json _name; return 1; }

    info "Editing \"${_name}\" — choose new provider order."
    _rc_cpo=0
    _router_choose_provider_order || _rc_cpo=$?
    if [ "${_rc_cpo}" -ne 0 ]; then
        unset _slug _presets_json _name
        return "${_rc_cpo}"
    fi

    _providers_json=$(_router_providers_array_from_ordered)
    _payload=$(preset_payload "${_slug}" "${_ROUTER_MODEL}" "${_providers_json}")

    create_or_update_preset "${_slug}" "${_payload}" \
        || { die "Could not update preset on OpenRouter."; unset _slug _presets_json _name _providers_json _payload; return 1; }

    preset_upsert "${_ROUTER_MODEL}" "${_slug}" "${_name}" "${_providers_json}"
    info "Preset \"${_name}\" updated."
    unset _slug _presets_json _name _providers_json _payload
}

_router_preset_rename() {
    _old_slug="${1:?_router_preset_rename requires a slug}"

    _presets_json=$(preset_load_all "${_ROUTER_MODEL}")
    _old_name=$(printf '%s' "${_presets_json}" \
        | jq -r --arg s "${_old_slug}" '.[] | select(.slug==$s) | .name')

    [ -n "${_old_name}" ] || { die "Preset \"${_old_slug}\" not found."; unset _old_slug _presets_json _old_name; return 1; }

    _result=$(prompt_rename_preset "${_old_name}")
    if [ "${_result}" = '__cancel__' ]; then
        unset _old_slug _presets_json _old_name _result
        return 0
    fi

    _new_name="${_result#confirmed:}"
    _new_slug=$(preset_slug "${_ROUTER_MODEL}" "${_new_name}")

    if [ "${_new_slug}" != "${_old_slug}" ]; then
        delete_preset "${_old_slug}" 2>/dev/null || true
    fi

    _providers_json=$(printf '%s' "${_presets_json}" \
        | jq -c --arg s "${_old_slug}" '.[] | select(.slug==$s) | .providers')
    _payload=$(preset_payload "${_new_slug}" "${_ROUTER_MODEL}" "${_providers_json}")

    create_or_update_preset "${_new_slug}" "${_payload}" \
        || { die "Could not update preset on OpenRouter."; unset _old_slug _presets_json _old_name _result _new_name _new_slug _providers_json _payload; return 1; }

    preset_rename_local "${_ROUTER_MODEL}" "${_old_slug}" "${_new_name}" "${_new_slug}"
    info "Preset renamed to \"${_new_name}\"."
    unset _old_slug _presets_json _old_name _result _new_name _new_slug _providers_json _payload
}

_router_preset_delete() {
    _slug="${1:?_router_preset_delete requires a slug}"

    _presets_json=$(preset_load_all "${_ROUTER_MODEL}")
    _name=$(printf '%s' "${_presets_json}" \
        | jq -r --arg s "${_slug}" '.[] | select(.slug==$s) | .name')

    [ -n "${_name}" ] || { die "Preset \"${_slug}\" not found."; unset _slug _presets_json _name; return 1; }

    prompt_delete_preset "${_name}" "${_ROUTER_MODEL}" || { unset _slug _presets_json _name; return 0; }

    delete_preset "${_slug}" 2>/dev/null \
        || warn "Could not delete preset on OpenRouter (may already be gone)."
    preset_remove "${_ROUTER_MODEL}" "${_slug}"
    info "Preset \"${_name}\" deleted."
    unset _slug _presets_json _name
}

# ── Backup actions ───────────────────────────────────────────────────────────

_router_preset_export() {
    _safe_model=$(printf '%s' "${_ROUTER_MODEL}" | tr '/' '-')
    _default_path="./openpreset-${_safe_model}-backup-$(date +%Y-%m-%d).json"
    printf '  Output file [%s]: ' "${_default_path}" >&2
    read -r _path
    [ -n "${_path}" ] || _path="${_default_path}"
    backup_export_model "${_ROUTER_MODEL}" "${_path}"
    unset _safe_model _default_path _path
}

_router_preset_import() {
    _path=$(prompt_import_file)
    [ -n "${_path}" ] || { unset _path; return 0; }

    _mode=$(prompt_import_mode) || { unset _path _mode; return 1; }

    printf '  Import "%s" (%s) for model %s? (y/N) ' "${_path}" "${_mode}" "${_ROUTER_MODEL}" >&2
    read -r _confirm
    _lc=$(to_lower "${_confirm}")
    if [ "${_lc}" != 'y' ]; then
        unset _path _mode _confirm _lc
        return 0
    fi

    backup_import_model "${_ROUTER_MODEL}" "${_path}" "${_mode}"
    unset _path _mode _confirm _lc
}

# ══════════════════════════════════════════════════════════════════════════
# User model file helpers
# ══════════════════════════════════════════════════════════════════════════

_router_load_user_models() {
    [ -f "${USER_MODELS_FILE}" ] || return 0
    grep -v '^[[:space:]]*#' "${USER_MODELS_FILE}" | grep -v '^[[:space:]]*$'
}

_router_append_user_model() {
    _model="${1:?_router_append_user_model requires a model}"
    mkdir -p "${CONFIG_DIR}"
    if [ -f "${USER_MODELS_FILE}" ] \
        && grep -qxF "${_model}" "${USER_MODELS_FILE}" 2>/dev/null; then
        info "\"${_model}\" is already saved."
        unset _model
        return 0
    fi
    printf '%s\n' "${_model}" >> "${USER_MODELS_FILE}"
    info "Saved \"${_model}\"."
    unset _model
}

_router_delete_user_model() {
    _model="${1:?_router_delete_user_model requires a model}"
    [ -f "${USER_MODELS_FILE}" ] || { unset _model; return 0; }
    _tmp=$(mktemp) || { warn "Could not create temp file."; unset _model; return 1; }
    grep -vxF "${_model}" "${USER_MODELS_FILE}" > "${_tmp}" \
        && mv "${_tmp}" "${USER_MODELS_FILE}"
    unset _model _tmp
}
