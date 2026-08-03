#!/usr/bin/env bash
#
# Activate the OSS CAD Suite for the current shell.
#
# Usage:
#   source scripts/activate_oss_cad.sh
#
# This file must be sourced rather than executed because it updates the
# environment of the calling shell.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: this script must be sourced:"
    echo "  source ${BASH_SOURCE[0]}"
    exit 1
fi

OSS_CAD_ROOT="${OSS_CAD_ROOT:-$HOME/tools/oss-cad-suite}"
OSS_CAD_ENV="${OSS_CAD_ROOT}/environment"

if [[ ! -f "${OSS_CAD_ENV}" ]]; then
    echo "Error: OSS CAD Suite environment file not found:"
    echo "  ${OSS_CAD_ENV}"
    return 1
fi

# Avoid sourcing the suite repeatedly when it is already active.
if ! command -v sby >/dev/null 2>&1 ||
   [[ "$(command -v sby)" != "${OSS_CAD_ROOT}/bin/sby" ]]; then
    # shellcheck disable=SC1090
    source "${OSS_CAD_ENV}"
fi

required_tools=(
    yosys
    sby
    yosys-smtbmc
    boolector
    verilator
)

for tool in "${required_tools[@]}"; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
        echo "Error: required tool '${tool}' is unavailable after activation."
        return 1
    fi
done

echo "OSS CAD Suite active: ${OSS_CAD_ROOT}"
echo "SymbiYosys: $(command -v sby)"