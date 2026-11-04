#!/usr/bin/env bash
set -euo pipefail

# Compose App Store screenshots from raw simulator captures.
# Raw captures come from an iPhone 17 Pro simulator (1206x2622) with the status
# bar overridden to 9:41: `xcrun simctl status_bar <id> override --time 9:41 ...`
# then `xcrun simctl io <id> screenshot AppStore/Screenshots/raw/<name>.png`.
# Usage: scripts/compose-store-screenshots.sh   (needs ImageMagick 7)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW="$ROOT_DIR/AppStore/Screenshots/raw"
# The first face of each collection: Avenir Next Bold and Avenir Book.
FONT_TITLE="${FONT_TITLE:-/System/Library/Fonts/Avenir Next.ttc}"
FONT_TEXT="${FONT_TEXT:-/System/Library/Fonts/Avenir.ttc}"

# name | raw capture | title | subtitle | top color | bottom color | text color | subtitle color
SHOTS=(
  "01-gesture-keyboard|01-home-light.png|Nine keys.\nEvery letter.|Tap a center letter. Swipe toward the rest.|#e9f7f5|#c9e6e2|#10302d|#3c5b58"
  "02-themes|02-ember-dark.png|Make it yours|Color themes, edge softness and gesture trails.|#1d1a14|#0b0a08|#fbe3bd|#c7b393"
  "03-layout-editor|03-layout.png|Move any letter|Edit the letters, symbols and numbers on every key.|#203241|#121c25|#e6f4f2|#a6bcc4"
)

# output folder | canvas width | canvas height
SIZES=(
  "iphone-6.9|1320|2868"
  "iphone-6.5|1242|2688"
)

for size in "${SIZES[@]}"; do
  IFS='|' read -r folder W H <<<"$size"
  out_dir="$ROOT_DIR/AppStore/Screenshots/$folder"
  rm -rf "$out_dir"
  mkdir -p "$out_dir"
  s=$(awk "BEGIN{print $W/1320}")
  px() { awk "BEGIN{printf \"%d\", $1*$s}"; }
  shot_w=$(px 1100)
  shot_h=$(awk "BEGIN{printf \"%d\", $shot_w*2622/1206}")
  radius=$(px 96)
  top=$(px 640)
  for spec in "${SHOTS[@]}"; do
    IFS='|' read -r name raw title subtitle c1 c2 fg sub <<<"$spec"
    tmp="$(mktemp -d "${TMPDIR:-/tmp}/tapeze-shot.XXXXXX")"
    # Rounded screenshot with a soft shadow.
    magick "$RAW/$raw" -resize "${shot_w}x${shot_h}!" \
      \( +clone -alpha extract -fill black -colorize 100 -fill white \
         -draw "roundrectangle 0,0,$((shot_w-1)),$((shot_h-1)),$radius,$radius" \) \
      -alpha off -compose CopyOpacity -composite "$tmp/shot.png"
    magick "$tmp/shot.png" \( +clone -background '#00000070' -shadow "60x$(px 36)+0+$(px 24)" \) \
      +swap -background none -layers merge +repage "$tmp/shadowed.png"
    magick -size "${W}x${H}" gradient:"$c1-$c2" \
      -font "$FONT_TITLE" -fill "$fg" -pointsize "$(px 118)" -interline-spacing "$(px -6)" \
      -gravity northwest -annotate "+$(px 110)+$(px 150)" "$(printf '%b' "$title")" \
      -font "$FONT_TEXT" -fill "$sub" -pointsize "$(px 50)" \
      -annotate "+$(px 112)+$(px 470)" "$subtitle" \
      "$tmp/shadowed.png" -gravity north -geometry "+0+$((top - $(px 36)))" -composite \
      -alpha off -strip "$out_dir/$name.png"
    rm -rf "$tmp"
  done
done
echo "Wrote $(ls "$ROOT_DIR"/AppStore/Screenshots/iphone-*/*.png | wc -l | tr -d ' ') screenshots."
