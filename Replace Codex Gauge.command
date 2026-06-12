#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
script/replace_installed_app.sh

printf "\nDone. You can close this window.\n"
read -r -p "Press Return to close..." _
