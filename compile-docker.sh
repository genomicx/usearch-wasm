#!/bin/bash
# ============================================================
# Build usearch12 WASM inside Docker (emscripten/emsdk)
# Works on macOS (including Apple Silicon) and Linux
# ============================================================
set -e

echo "Building usearch12 WASM via Docker..."
docker run --rm --platform linux/amd64 \
  -v "$(pwd):/work" \
  emscripten/emsdk:3.1.50 \
  bash /work/compile.sh

echo ""
echo "Output files in build/:"
ls -lh build/usearch.js build/usearch.wasm build/usearch.worker.js 2>/dev/null || true
