#!/usr/bin/env sh

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    M="\033[38;2;110;231;183;1m"
    P="\033[38;2;129;140;248;1m"
    G="\033[38;2;100;116;139m"
    D="\033[2m"
    R="\033[0m"
else
    M="" P="" G="" D="" R=""
fi

pad='            '
box='─────────────────────────────────────────────────────────'

printf "%b┌%s┐%b\n" "${G}" "${box}" "${R}"
printf "%b│%b%s%bOpen%bPreset%b %b— LLM & Preset Manager%b%s%b│%b\n" "${G}" "${R}" "${pad}" "${M}" "${P}" "${R}" "${D}" "${R}" "${pad}" "${G}" "${R}"
printf "%b└%s┘%b\n" "${G}" "${box}" "${R}"


