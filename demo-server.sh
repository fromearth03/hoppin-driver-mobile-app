#!/usr/bin/env bash
# HOPPIN Driver — build the web app and serve it locally.
#
#   bash demo-server.sh          # build + serve on :8101
#   bash demo-server.sh --serve  # serve an existing build (skip the rebuild)
#
# Driver -> http://localhost:8101
#
# NOTE: the driver app's real target is ANDROID — a browser tab cannot hold a
# driver's shift (no background geolocation). This web build is for demo and
# UI review only; use `flutter build apk` for anything real.
#
# Adapted from the monorepo demo server for this standalone repo (the app now
# lives at ./driver_app rather than ./apps/driver).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER="${FLUTTER:-flutter}"
APP_DIR="$ROOT/driver_app"
DEFINES="$APP_DIR/demodefines.json"
PORT=8101

if [ ! -f "$DEFINES" ]; then
  echo "ERROR: $DEFINES not found."
  echo "       cp driver_app/demodefines.example.json driver_app/demodefines.json"
  echo "       then fill in the real Supabase values."
  exit 1
fi

if [ "${1:-}" != "--serve" ]; then
  echo "Building driver web (release)..."
  ( cd "$APP_DIR" && "$FLUTTER" build web --release \
      --dart-define-from-file=demodefines.json )
fi

echo "Serving http://localhost:$PORT  (Ctrl-C to stop)"
cd "$APP_DIR/build/web" && python -m http.server "$PORT"
