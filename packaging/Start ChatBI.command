#!/bin/bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "$0")" && pwd)"
source "$project_root/packaging/runtime.sh"
exec "$project_root/backend/.venv/bin/python" -I -B "$project_root/packaging/serve.py" "$@"
