#!/bin/sh
# Render web icons from assets/icon/app_icon.svg. Needs rsvg-convert
# (brew install librsvg). Run from flutter_app/.
set -eu
src=assets/icon/app_icon.svg
rounded=$(mktemp -t app_icon_rounded).svg
# Non-maskable icons get rounded corners (22% radius, like an app tile);
# maskable icons stay full-bleed because the platform crops them.
sed -e 's|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">|&<clipPath id="tile"><rect width="1024" height="1024" rx="225"/></clipPath><g clip-path="url(#tile)">|' \
    -e 's|</svg>|</g></svg>|' "$src" > "$rounded"
for size in 192 512; do
  rsvg-convert -w $size -h $size "$rounded" -o web/icons/Icon-$size.png
  rsvg-convert -w $size -h $size "$src" -o web/icons/Icon-maskable-$size.png
done
rsvg-convert -w 32 -h 32 "$rounded" -o web/favicon.png
rm "$rounded"
