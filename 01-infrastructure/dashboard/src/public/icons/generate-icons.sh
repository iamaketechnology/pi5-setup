#!/bin/bash
# Generate PNG icons from SVG using ImageMagick

if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick not installed"
    echo "Install with: brew install imagemagick"
    exit 1
fi

echo "🎨 Generating PNG icons from SVG..."

convert -background none icon.svg -resize 192x192 icon-192.png
convert -background none icon.svg -resize 512x512 icon-512.png

echo "✅ Icons generated:"
echo "   - icon-192.png (192x192)"
echo "   - icon-512.png (512x512)"
