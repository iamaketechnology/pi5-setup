# Dashboard Icons

## Generate PNG icons from SVG

```bash
# Install ImageMagick (if not already installed)
brew install imagemagick

# Generate icons
convert -background none icon.svg -resize 192x192 icon-192.png
convert -background none icon.svg -resize 512x512 icon-512.png
```

## Or use online tool

1. Upload `icon.svg` to https://realfavicongenerator.net/
2. Download generated icons
3. Replace `icon-192.png` and `icon-512.png`

## Icon specifications

- **icon-192.png**: 192x192px (Android home screen)
- **icon-512.png**: 512x512px (Android splash screen)
- Format: PNG with transparency
- Purpose: `any maskable` (works with Android adaptive icons)
