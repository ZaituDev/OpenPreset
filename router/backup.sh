#!/usr/bin/env sh
# backup.sh — export and import backup files
# No UI (delegates to ui.sh). No networking (delegates to openrouter.sh).

# ── Export ───────────────────────────────────────────────────────────────────

# Export all local state to a single portable JSON file.
# Usage: backup_export [output-path]
# If output-path is omitted, a timestamped file is written to the current dir.
backup_export() {
    _outfile="${1:-./openpreset-backup-$(date +%Y-%m-%d).json}"

    # Collect all user models.
    if [ -f "${USER_MODELS_FILE}" ]; then
        _user_models_json=$(grep -v '^[[:space:]]*#' "${USER_MODELS_FILE}" \
            | grep -v '^[[:space:]]*$' \
            | jq -Rn '[inputs]')
    else
        _user_models_json='[]'
    fi

    # Collect all per-model preset metadata files.
    _all_presets_json='{}'
    if [ -d "${PRESETS_DIR}" ]; then
        for _f in "${PRESETS_DIR}"/*.json; do
            [ -e "${_f}" ] || continue   # no-match guard (nullglob replacement)
            _base=$(basename "${_f}")
            _model_key="${_base%.json}"
            _file_json=$(cat "${_f}")
            _all_presets_json=$(printf '%s' "${_all_presets_json}" \
                | jq --arg key "${_model_key}" \
                     --argjson val "${_file_json}" \
                     '. + {($key): $val}')
        done
    fi

    # Assemble the backup envelope.
    _backup=$(jq -n \
        --arg schema "${BACKUP_SCHEMA_VERSION}" \
        --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --argjson user_models "${_user_models_json}" \
        --argjson presets "${_all_presets_json}" \
        '{
            schema_version: $schema,
            created_at:     $created,
            user_models:    $user_models,
            presets:        $presets
        }')

    printf '%s' "${_backup}" > "${_outfile}" \
        || { die "Could not write backup to ${_outfile}"; unset _outfile _user_models_json _all_presets_json _backup; return 1; }

    info "Backup written to ${_outfile}"
    unset _outfile _user_models_json _all_presets_json _backup _f _base _model_key _file_json
}

# ── Import ───────────────────────────────────────────────────────────────────

# Import a backup file.
# Usage: backup_import <file> <mode>   mode = merge | replace
backup_import() {
    _file="${1:?backup_import requires a file path}"
    _mode="${2:?backup_import requires a mode (merge|replace)}"

    # ── Validate ─────────────────────────────────────────────────────────────

    [ -f "${_file}" ] || { die "File not found: ${_file}"; unset _file _mode; return 1; }

    _backup=$(jq '.' "${_file}" 2>/dev/null) \
        || { die "File is not valid JSON: ${_file}"; unset _file _mode _backup; return 1; }

    _schema=$(printf '%s' "${_backup}" | jq -r '.schema_version // empty')
    if [ "${_schema}" != "${BACKUP_SCHEMA_VERSION}" ]; then
        die "Unsupported backup schema version: ${_schema:-missing}"
        unset _file _mode _backup _schema
        return 1
    fi

    # ── User models ────────────────────────────────────────────────────────

    if [ "${_mode}" = 'replace' ]; then
        # Wipe user models atomically — write empty file via temp to avoid partial state.
        mkdir -p "${CONFIG_DIR}"
        _tmp_models=$(mktemp) \
            || { die "Could not create temp file for replace."; unset _file _mode _backup _schema _tmp_models; return 1; }
        mv "${_tmp_models}" "${USER_MODELS_FILE}"
    fi

    printf '%s' "${_backup}" | jq -r '.user_models[]' > /tmp/.cr-import-models.$$ 2>/dev/null || : > /tmp/.cr-import-models.$$
    while IFS= read -r _m; do
        [ -n "${_m}" ] || continue
        if ! grep -qxF "${_m}" "${USER_MODELS_FILE}" 2>/dev/null; then
            printf '%s\n' "${_m}" >> "${USER_MODELS_FILE}"
        fi
    done < /tmp/.cr-import-models.$$
    rm -f /tmp/.cr-import-models.$$

    # ── Presets ────────────────────────────────────────────────────────────

    mkdir -p "${PRESETS_DIR}"

    printf '%s' "${_backup}" | jq -r '.presets | keys[]' > /tmp/.cr-import-keys.$$ 2>/dev/null || : > /tmp/.cr-import-keys.$$
    while IFS= read -r _key; do
        [ -n "${_key}" ] || continue

        _imported_arr=$(printf '%s' "${_backup}" | jq --arg k "${_key}" '.presets[$k]')
        _dest_file="${PRESETS_DIR}/${_key}.json"

        if [ "${_mode}" = 'replace' ] || [ ! -f "${_dest_file}" ]; then
            printf '%s' "${_imported_arr}" > "${_dest_file}"
        else
            # Merge: keep existing entries, add imported entries by slug.
            _existing=$(cat "${_dest_file}")
            _merged=$(jq -n \
                --argjson existing "${_existing}" \
                --argjson imported "${_imported_arr}" \
                '($existing + $imported) | unique_by(.slug)')
            printf '%s' "${_merged}" > "${_dest_file}"
        fi

        # Recreate OpenRouter presets for each entry in this model.
        printf '%s' "${_imported_arr}" | jq -r '.[].slug' > /tmp/.cr-import-slugs.$$ 2>/dev/null || : > /tmp/.cr-import-slugs.$$
        while IFS= read -r _slug; do
            [ -n "${_slug}" ] || continue
            _providers_json=$(printf '%s' "${_imported_arr}" \
                | jq -c --arg s "${_slug}" '.[] | select(.slug==$s) | .providers')
            _model_id=$(printf '%s' "${_imported_arr}" \
                | jq -r --arg s "${_slug}" '.[] | select(.slug==$s) | .model // empty')
            [ -n "${_model_id}" ] || continue

            _payload=$(preset_payload "${_slug}" "${_model_id}" "${_providers_json}")
            create_or_update_preset "${_slug}" "${_payload}" \
                || warn "Could not recreate preset \"${_slug}\" on OpenRouter."
        done < /tmp/.cr-import-slugs.$$
        rm -f /tmp/.cr-import-slugs.$$
    done < /tmp/.cr-import-keys.$$
    rm -f /tmp/.cr-import-keys.$$

    info "Import complete (mode: ${_mode})."
    unset _file _mode _backup _schema _tmp_models _m _key _imported_arr _dest_file _existing _merged _slug _providers_json _model_id _payload
}
