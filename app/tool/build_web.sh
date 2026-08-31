#!/usr/bin/env bash
# Builds the web bundle and substitutes the Google Maps browser key into the
# generated index.html.
#
# The key is NOT committed. Supply it as an environment variable:
#
#   MAPS_API_KEY=AIza... ./tool/build_web.sh
#
# Without it the build still succeeds and every screen works; only the map
# tiles fail to load. That is deliberate — a missing key must not block a
# build.
#
# A web Maps key is public by nature: it ships inside the page, and anyone
# viewing the site can read it. Restricting it by HTTP referrer in the Google
# Cloud console is the only thing that stops someone else billing your
# project. Set that restriction and a daily quota cap before this bundle is
# served anywhere public.
set -euo pipefail

cd "$(dirname "$0")/.."

flutter build web --release --dart-define-from-file=config/dev.json "$@"

INDEX="build/web/index.html"

if [[ -z "${MAPS_API_KEY:-}" ]]; then
  echo "MAPS_API_KEY not set — built without a Maps key; map tiles will not load." >&2
  exit 0
fi

# Substitute in the built output only, never in the source template, so the
# key cannot be committed by accident.
python - "$INDEX" "$MAPS_API_KEY" <<'PY'
import io, sys

path, key = sys.argv[1], sys.argv[2]
html = io.open(path, encoding='utf-8').read()

if '__MAPS_API_KEY__' not in html:
    print('placeholder not found in %s — did the template change?' % path,
          file=sys.stderr)
    sys.exit(1)

io.open(path, 'w', encoding='utf-8').write(
    html.replace('__MAPS_API_KEY__', key))
print('Maps key substituted into %s' % path)
PY
