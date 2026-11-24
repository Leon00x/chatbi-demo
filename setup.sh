#!/usr/bin/env bash
# The online installer is replaced by the offline bootstrap. guide.md keeps
# calling setup.sh, so this file stays as the documented entry point.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$script_dir/bootstrap.sh" "$@"
