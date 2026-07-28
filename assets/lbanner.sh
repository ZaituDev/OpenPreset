#!/usr/bin/env sh

# Colors & Formatting
MINT="\033[38;2;110;231;183m"
PERIWINKLE="\033[38;2;129;140;248m"
GRAY="\033[38;2;100;116;139m"
BOLD="\033[1m"
DIM="\033[2m"
RST="\033[0m"

# Border Elements
TOP_BORDER="┌────────────────────────────────────────────────────────┐"
BOT_BORDER="└────────────────────────────────────────────────────────┘"
SIDE="${GRAY}│${RST}"

# Print Header
printf "%b\n" "${GRAY}${TOP_BORDER}${RST}"
printf "${SIDE}  ${MINT} ██████╗ ${PERIWINKLE}██████╗ ${RST}                                     ${SIDE}\n"
printf "${SIDE}  ${MINT}██╔═══██╗${PERIWINKLE}██╔══██╗${RST}                                     ${SIDE}\n"
printf "${SIDE}  ${MINT}██║   ██║${PERIWINKLE}██████╔╝${RST}   ${BOLD}OpenPreset${RST}                        ${SIDE}\n"
printf "${SIDE}  ${MINT}██║   ██║${PERIWINKLE}██╔═══╝ ${RST}   ${DIM}LLM & Preset Manager${RST}              ${SIDE}\n"
printf "${SIDE}  ${MINT}╚██████╔╝${PERIWINKLE}██║     ${RST}                                     ${SIDE}\n"
printf "${SIDE}  ${MINT} ╚═════╝ ${PERIWINKLE}╚═╝     ${RST}                                     ${SIDE}\n"
printf "%b\n" "${GRAY}${BOT_BORDER}${RST}"

