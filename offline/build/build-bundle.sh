#!/usr/bin/env bash
# Builds the offline dependency bundle for macOS on Apple silicon.
# Usage: bash offline/build/build-bundle.sh [mac-arm64] [v1]
set -euo pipefail

PLATFORM="${1:-mac-arm64}"
VERSION="${2:-v1}"

if [[ "$PLATFORM" != "mac-arm64" ]]; then
  printf 'Unsupported platform for this script: %s\n' "$PLATFORM" >&2
  exit 1
fi

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD="$ROOT/.build/bundle-$PLATFORM"
DOWNLOADS="$ROOT/.build/downloads"
NODE_DIR="$BUILD/node"
PYTHON_DIR="$BUILD/python"
WHEEL_DIR="$BUILD/wheels"
VENV_DIR="$BUILD/venv"
NPM_CACHE="$BUILD/npm-cache"
STAGE="$BUILD/stage-$PLATFORM"
VERIFY="$BUILD/verify-$PLATFORM"
DIST="$ROOT/dist"
ZIP_PATH="$DIST/chatbi-deps-$PLATFORM-$VERSION.zip"
RUNtimes="$ROOT/offline/runtimes.json"

mkdir -p "$BUILD" "$DOWNLOADS" "$DIST"

step() { printf '==> %s\n' "$1"; }

if ! command -v node >/dev/null 2>&1; then
  printf 'Node.js is required to read offline/runtimes.json.\n' >&2
  exit 1
fi

json_get() {
  node -e 'const c=require(process.argv[1]); const v=process.argv[2].split(".").reduce((o,k)=>o[k],c); process.stdout.write(String(v))' "$RUNtimes" "$1"
}

download_pinned() {
  local key="$1"
  local file url sha target actual
  file="$(json_get "$key.file")"
  url="$(json_get "$key.url")"
  sha="$(json_get "$key.sha256")"
  target="$DOWNLOADS/$file"
  if [[ ! -f "$target" ]]; then
    step "Downloading $file"
    curl -fL --retry 3 -o "$target" "$url"
  fi
  actual="$(shasum -a 256 "$target" | awk '{print $1}')"
  if [[ "$actual" != "$sha" ]]; then
    printf 'Checksum mismatch for %s: %s\n' "$file" "$actual" >&2
    exit 1
  fi
  printf '%s' "$target"
}

if [[ ! -x "$NODE_DIR/bin/node" ]]; then
  node_tar="$(download_pinned "node.assets.$PLATFORM")"
  step 'Extracting Node.js'
  rm -rf "$BUILD/node-extract"
  mkdir -p "$BUILD/node-extract"
  tar -xzf "$node_tar" -C "$BUILD/node-extract"
  inner="$(find "$BUILD/node-extract" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  rm -rf "$NODE_DIR"
  mv "$inner" "$NODE_DIR"
  rm -rf "$BUILD/node-extract"
fi

if [[ ! -x "$PYTHON_DIR/bin/python3" ]]; then
  python_tar="$(download_pinned "python.assets.$PLATFORM")"
  step 'Extracting CPython'
  rm -rf "$BUILD/python-extract"
  mkdir -p "$BUILD/python-extract"
  tar -xzf "$python_tar" -C "$BUILD/python-extract"
  if [[ ! -x "$BUILD/python-extract/python/bin/python3" ]]; then
    printf 'The CPython archive has an unexpected layout.\n' >&2
    exit 1
  fi
  rm -rf "$PYTHON_DIR"
  mv "$BUILD/python-extract/python" "$PYTHON_DIR"
  rm -rf "$BUILD/python-extract"
fi

step 'Downloading the backend wheelhouse'
rm -rf "$WHEEL_DIR"
mkdir -p "$WHEEL_DIR"
"$PYTHON_DIR/bin/python3" -m pip download \
  -r "$ROOT/backend/requirements.txt" \
  -c "$ROOT/offline/constraints.txt" \
  --only-binary=:all: --disable-pip-version-check \
  -d "$WHEEL_DIR"

export PATH="$NODE_DIR/bin:$PATH"
# Keep the cache isolated so the bundle ships only the packages this build fetched.
rm -rf "$NPM_CACHE"
mkdir -p "$NPM_CACHE"
export npm_config_cache="$NPM_CACHE"

step 'Installing node_modules and running the frontend build'
( cd "$ROOT/frontend" && npm ci && npm run build )

step 'Running backend tests with the bundled Python'
rm -rf "$VENV_DIR"
"$PYTHON_DIR/bin/python3" -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --no-index --disable-pip-version-check \
  --find-links "$WHEEL_DIR" -c "$ROOT/offline/constraints.txt" \
  -r "$ROOT/backend/requirements.txt"
( cd "$ROOT/backend" && "$VENV_DIR/bin/python" -m pytest -q )

step 'Assembling the bundle'
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$NODE_DIR" "$STAGE/node"
cp -R "$PYTHON_DIR" "$STAGE/python"
cp -R "$WHEEL_DIR" "$STAGE/wheels"
cp -R "$ROOT/frontend/node_modules" "$STAGE/node_modules"
cp -R "$NPM_CACHE" "$STAGE/npm-cache"

ECHARTS_VERSION="$(node -p "require('$ROOT/frontend/node_modules/echarts/package.json').version")"
cat > "$STAGE/manifest.json" <<JSON
{
  "platform": "$PLATFORM",
  "node": "$(json_get node.version)",
  "python": "$(json_get python.version)",
  "echarts": "$ECHARTS_VERSION",
  "constraints": "offline/constraints.txt",
  "built": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON

step 'Creating the zip archive'
rm -f "$ZIP_PATH"
( cd "$STAGE" && zip -q -r -y "$ZIP_PATH" . )

step 'Verifying the archive from a clean extraction'
rm -rf "$VERIFY"
mkdir -p "$VERIFY"
unzip -q "$ZIP_PATH" -d "$VERIFY"

"$VERIFY/python/bin/python3" -c 'import sqlite3, sys; print(sys.version.split()[0]); sys.exit(0 if hasattr(sqlite3.Connection, "setlimit") else 1)'

"$VERIFY/python/bin/python3" -m venv "$VERIFY/venv"
"$VERIFY/venv/bin/python" -m pip install --no-index --disable-pip-version-check \
  --find-links "$VERIFY/wheels" -c "$ROOT/offline/constraints.txt" \
  -r "$ROOT/backend/requirements.txt"
( cd "$ROOT/backend" && "$VERIFY/venv/bin/python" -m pytest -q )

export NODE_PATH="$VERIFY/node_modules"
"$VERIFY/node/bin/node" -e "const esbuild = require('esbuild'); if (!esbuild.version) { process.exit(1) } console.log('esbuild', esbuild.version)"
"$VERIFY/node/bin/node" "$VERIFY/node_modules/vite/bin/vite.js" --version
[[ -f "$VERIFY/node_modules/echarts/package.json" ]] || { printf 'echarts is missing from the bundle.\n' >&2; exit 1; }

rm -rf "$VERIFY"

SIZE_MB="$(du -m "$ZIP_PATH" | awk '{print $1}')"
step "Bundle ready: $ZIP_PATH (${SIZE_MB} MB)"
