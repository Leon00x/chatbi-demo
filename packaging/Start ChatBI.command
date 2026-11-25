#!/bin/bash
set -e
cd -- "$(dirname -- "$0")"
exec ./runtime/bin/python3 -I -B ./packaging/serve.py "$@"
