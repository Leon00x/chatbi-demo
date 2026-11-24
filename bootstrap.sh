#!/usr/bin/env bash
# Prepares the ChatBI demo for offline development on macOS (Apple silicon).
#
# Usage:
#   bash ./bootstrap.sh
#   bash ./bootstrap.sh --repair
#   bash ./bootstrap.sh --force
#   bash ./bootstrap.sh --uninstall
set -euo pipefail

REPO="hhuang37/chatbi-demo"
TAG="deps-v1"
REPAIR=0
FORCE=0
UNINSTALL=0
MARK_BEGIN="# >>> chatbi-demo offline >>>"
MARK_END="# <<< chatbi-demo offline <<<"

usage() {
  printf '%s\n' \
    'Usage: bash ./bootstrap.sh [--tag TAG] [--repair] [--force] [--uninstall]' \
    '' \
    '  --tag TAG     Release tag that holds the dependency bundles (default: deps-v1)' \
    '  --repair      Rebuild backend/.venv from the local bundle' \
    '  --force       Download and extract the bundle again' \
    '  --uninstall   Remove the PATH entry added by this script'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="${2:-}"; shift 2 ;;
    --repair) REPAIR=1; shift ;;
    --force) FORCE=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage; exit 1 ;;
  esac
done

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_ROOT="$PROJECT_ROOT/backend"
FRONTEND_ROOT="$PROJECT_ROOT/frontend"
OFFLINE_ROOT="$PROJECT_ROOT/.offline"
VENV_PYTHON="$BACKEND_ROOT/.venv/bin/python"

step() { printf '==> %s\n' "$1"; }

remove_path_block() {
  local rcfile="$HOME/.zshrc"
  [[ -f "$rcfile" ]] || return 0
  if grep -qF "$MARK_BEGIN" "$rcfile"; then
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
      $0 == b { skip = 1; next }
      $0 == e { skip = 0; next }
      !skip { print }
    ' "$rcfile" > "$rcfile.tmp"
    mv "$rcfile.tmp" "$rcfile"
    return 0
  fi
  return 0
}

if [[ "$UNINSTALL" -eq 1 ]]; then
  step 'Removing the bundled Node.js entry from ~/.zshrc'
  remove_path_block
  printf '%s\n' 'Done. Open a new terminal for the change to take effect.'
  printf '%s\n' 'You can delete .offline, backend/.venv and frontend/node_modules to reclaim disk space.'
  exit 0
fi

OS="$(uname -s)"
ARCH="$(uname -m)"
if [[ "$OS" != "Darwin" ]]; then
  printf 'This script supports macOS only. On Windows use bootstrap.ps1.\n' >&2
  exit 1
fi
if [[ "$ARCH" == "arm64" ]]; then
  PLATFORM="mac-arm64"
elif [[ "$ARCH" == "x86_64" ]]; then
  printf 'Intel Macs are not supported by the offline bundle. Use setup.sh with a local Python 3.11+ and Node 20+.\n' >&2
  exit 1
else
  printf 'Unsupported architecture: %s\n' "$ARCH" >&2
  exit 1
fi

VERSION_SUFFIX="${TAG#deps-}"
ASSET_NAME="chatbi-deps-${PLATFORM}-${VERSION_SUFFIX}.zip"
step "Platform: $PLATFORM"
step "Dependency bundle: $ASSET_NAME (release $TAG)"

need_bundle=1
if [[ "$FORCE" -eq 0 && -f "$OFFLINE_ROOT/manifest.json" ]]; then
  need_bundle=0
  step 'Using the dependency bundle already in .offline'
fi

if [[ "$need_bundle" -eq 1 ]]; then
  BASE_URL="https://github.com/$REPO/releases/download/$TAG"
  TMP_DIR="$PROJECT_ROOT/.download-tmp"
  rm -rf "$TMP_DIR"
  mkdir -p "$TMP_DIR"
  trap 'rm -rf "$TMP_DIR"' EXIT
  ZIP_PATH="$TMP_DIR/$ASSET_NAME"
  SUMS_PATH="$TMP_DIR/SHA256SUMS"

  step "Downloading $BASE_URL/$ASSET_NAME"
  curl -fL --retry 3 --progress-bar -o "$ZIP_PATH" "$BASE_URL/$ASSET_NAME"
  curl -fL --retry 3 -sS -o "$SUMS_PATH" "$BASE_URL/SHA256SUMS"

  step 'Verifying the SHA256 checksum'
  expected="$(grep -F "$ASSET_NAME" "$SUMS_PATH" | awk '{print $1}' | head -n 1)"
  if [[ -z "$expected" ]]; then
    printf 'SHA256SUMS does not list %s\n' "$ASSET_NAME" >&2
    exit 1
  fi
  if command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
  else
    actual="$(sha256sum "$ZIP_PATH" | awk '{print $1}')"
  fi
  if [[ "$expected" != "$actual" ]]; then
    printf 'Checksum mismatch for %s: expected %s, got %s\n' "$ASSET_NAME" "$expected" "$actual" >&2
    exit 1
  fi

  step 'Extracting the bundle'
  EXTRACT_DIR="$TMP_DIR/extract"
  mkdir -p "$EXTRACT_DIR"
  unzip -q "$ZIP_PATH" -d "$EXTRACT_DIR"

  rm -rf "$OFFLINE_ROOT"
  mkdir -p "$OFFLINE_ROOT"
  for name in node python wheels npm-cache node.tar.gz python.tar.gz; do
    if [[ -e "$EXTRACT_DIR/$name" ]]; then
      mv "$EXTRACT_DIR/$name" "$OFFLINE_ROOT/$name"
    fi
  done
  [[ -f "$EXTRACT_DIR/manifest.json" ]] && mv "$EXTRACT_DIR/manifest.json" "$OFFLINE_ROOT/manifest.json"

  if [[ -e "$EXTRACT_DIR/node_modules" ]]; then
    rm -rf "$FRONTEND_ROOT/node_modules"
    mv "$EXTRACT_DIR/node_modules" "$FRONTEND_ROOT/node_modules"
  fi

  step 'Removing the macOS quarantine attribute from downloaded binaries'
  xattr -dr com.apple.quarantine "$OFFLINE_ROOT" 2>/dev/null || true
fi

# The macOS fallback bundle ships the runtimes as tarballs, because symlinks
# cannot be preserved when the archive is assembled on Windows.
materialize_runtime() {
  local name="$1" tarball="$2" probe="$3"
  [[ -e "$OFFLINE_ROOT/$name/$probe" ]] && return 0
  [[ -f "$OFFLINE_ROOT/$tarball" ]] || return 0
  step "Extracting $tarball"
  local tmp="$OFFLINE_ROOT/.extract-$name"
  rm -rf "$tmp"
  mkdir -p "$tmp"
  tar -xzf "$OFFLINE_ROOT/$tarball" -C "$tmp"
  local inner
  inner="$(find "$tmp" -mindepth 1 -maxdepth 1 | head -n 1)"
  rm -rf "$OFFLINE_ROOT/$name"
  mv "$inner" "$OFFLINE_ROOT/$name"
  rm -rf "$tmp"
  rm -f "$OFFLINE_ROOT/$tarball"
}
materialize_runtime node node.tar.gz bin/node
materialize_runtime python python.tar.gz bin/python3
xattr -dr com.apple.quarantine "$OFFLINE_ROOT" 2>/dev/null || true

OFFLINE_PYTHON="$OFFLINE_ROOT/python/bin/python3"
if [[ ! -x "$OFFLINE_PYTHON" ]]; then
  printf 'The bundle does not contain python/bin/python3. Run again with --force.\n' >&2
  exit 1
fi

venv_ok=0
if [[ -x "$VENV_PYTHON" && "$REPAIR" -eq 0 ]]; then
  if "$VENV_PYTHON" -c 'import sys' >/dev/null 2>&1; then
    venv_ok=1
  fi
fi
if [[ "$venv_ok" -eq 0 ]]; then
  step 'Creating backend/.venv from the bundled Python'
  rm -rf "$BACKEND_ROOT/.venv"
  "$OFFLINE_PYTHON" -m venv "$BACKEND_ROOT/.venv"
fi

step 'Installing backend packages from the local wheelhouse'
PIP_ARGS=(-m pip install --no-index --disable-pip-version-check --find-links "$OFFLINE_ROOT/wheels")
if [[ -f "$PROJECT_ROOT/offline/constraints.txt" ]]; then
  PIP_ARGS+=(-c "$PROJECT_ROOT/offline/constraints.txt")
fi
PIP_ARGS+=(-r "$BACKEND_ROOT/requirements.txt")
"$VENV_PYTHON" "${PIP_ARGS[@]}"

step 'Configuring the offline npm cache'
NPMRC_CACHE="$(printf '%s' "$OFFLINE_ROOT/npm-cache" | sed 's/\\/\//g')"
{
  printf 'cache=%s\n' "$NPMRC_CACHE"
  printf 'prefer-offline=true\n'
  printf 'audit=false\n'
  printf 'fund=false\n'
} > "$FRONTEND_ROOT/.npmrc"

if [[ ! -d "$FRONTEND_ROOT/node_modules" ]]; then
  step 'Restoring frontend/node_modules from the bundled npm cache'
  ( cd "$FRONTEND_ROOT" && "$OFFLINE_ROOT/node/bin/npm" ci --offline )
fi

if [[ ! -f "$BACKEND_ROOT/.env" ]]; then
  cp "$BACKEND_ROOT/.env.example" "$BACKEND_ROOT/.env"
  step 'Created backend/.env from the template'
fi

NODE_BIN_DIR="$OFFLINE_ROOT/node/bin"
need_path=0
if ! command -v node >/dev/null 2>&1; then
  need_path=1
else
  current_major="$(node -v | sed 's/^v//' | cut -d. -f1)"
  if [[ -n "$current_major" && "$current_major" -lt 20 ]]; then
    need_path=1
  fi
fi

if [[ "$need_path" -eq 1 ]]; then
  if ! grep -qF "$MARK_BEGIN" "$HOME/.zshrc" 2>/dev/null; then
    {
      printf '\n%s\n' "$MARK_BEGIN"
      printf 'export PATH="%s:$PATH"\n' "$NODE_BIN_DIR"
      printf '%s\n' "$MARK_END"
    } >> "$HOME/.zshrc"
    step 'Added the bundled Node.js to ~/.zshrc'
    printf '    Open a new terminal (restart your IDE) for that change to take effect.\n'
    printf '    For this shell only: export PATH="%s:$PATH"\n' "$NODE_BIN_DIR"
  fi
fi

printf '\n%s\n' 'Setup complete. No services were started.'
printf '%s\n' 'Next: edit backend/.env with your MaaS endpoint, token and model, then start both services.'
printf '\n%s\n' '  Terminal 1 (backend):'
printf '    cd backend\n'
printf '    .venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload\n'
printf '\n%s\n' '  Terminal 2 (frontend):'
printf '    cd frontend\n'
printf '    npm run dev -- --port 5173 --strictPort\n'
printf '\n%s\n' 'Then open the address printed by Vite. See guide.md for details.'
