#!/bin/zsh
# Regenerates Resources/AppIcon.icns from Resources/AppIcon.svg (needs rsvg-convert: brew install librsvg).
set -euo pipefail
cd "$(dirname "$0")"

ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    rsvg-convert -w $size -h $size Resources/AppIcon.svg -o "$ICONSET/icon_${size}x${size}.png"
    rsvg-convert -w $((size * 2)) -h $((size * 2)) Resources/AppIcon.svg -o "$ICONSET/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"

# Rounded preview for the README (needs ImageMagick: brew install imagemagick).
magick "$ICONSET/icon_256x256@2x.png" -alpha set \
    \( -size 512x512 xc:none -fill white -draw "roundrectangle 0,0 511,511 115,115" \) \
    -compose DstIn -composite PNG32:Resources/AppIcon.png
echo "Wrote Resources/AppIcon.png"
