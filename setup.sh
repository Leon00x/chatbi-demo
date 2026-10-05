#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
backend_root="$project_root/backend"
venv_python="$backend_root/.venv/bin/python"

command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 || {
  printf '%s\n' 'Install Node.js with npm, then run this script again.' >&2
  exit 1
}
node --version

if [[ -x "$venv_python" ]]; then
  printf '%s\n' 'Reusing backend/.venv.'
else
  if [[ -n "${PYTHON:-}" ]]; then
    python_command="$PYTHON"
  elif command -v python3 >/dev/null 2>&1; then
    python_command=python3
  elif command -v python >/dev/null 2>&1; then
    python_command=python
  else
    printf '%s\n' 'Install Python with venv support, then run this script again.' >&2
    exit 1
  fi
  "$python_command" -m venv "$backend_root/.venv" || {
    printf '%s\n' 'Could not create the virtual environment. Ensure Python includes venv (some Linux distributions package it separately).' >&2
    exit 1
  }
fi

"$venv_python" -c 'import sqlite3, sys; print(sys.version.split()[0]); sys.exit(0 if hasattr(sqlite3.Connection, "setlimit") else "This backend needs sqlite3.Connection.setlimit (Python 3.11+). Choose a compatible Python and recreate backend/.venv.")'

if [[ ! -e "$backend_root/.env" ]]; then
  cp "$backend_root/.env.example" "$backend_root/.env"
  printf '%s\n' 'Created backend/.env from the template.'
else
  printf '%s\n' 'Keeping existing backend/.env.'
fi
if ! "$venv_python" -m pip --version >/dev/null 2>&1; then
  "$venv_python" -m ensurepip
fi
"$venv_python" -m pip install -r "$backend_root/requirements.txt"
(
  cd "$project_root/frontend"
  if [[ -f package-lock.json ]]; then npm ci; else npm install; fi
)

printf '%s\n' \
  'Setup complete. No services were started.' \
  'Edit backend/.env with your MaaS endpoint, token and model, then follow guide.md to start manually.' \
  'After manual startup, open the frontend URL printed by Vite. See guide.md for default commands and addresses.'
