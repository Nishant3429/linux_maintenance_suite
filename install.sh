#!/usr/bin/env bash
# install.sh - Prepare the suite
set -o errexit
set -o pipefail
set -o nounset

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "${ROOT_DIR}/scripts/"*.sh

echo "Installed. Run: ${ROOT_DIR}/scripts/menu.sh"
