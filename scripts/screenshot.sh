#!/usr/bin/env bash
# Sora Ultra HD Screenshot Script
# Menyimpan tangkapan layar dengan 2x/3x supersampling agar tajam dan tidak pecah

SAVE_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$SAVE_DIR"

SCALE="${SORA_SCREENSHOT_SCALE:-2}"
MODE="region"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--fullscreen)
            MODE="fullscreen"
            shift
            ;;
        -w|--window)
            MODE="window"
            shift
            ;;
        -r|--region)
            MODE="region"
            shift
            ;;
        -s|--scale)
            SCALE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

FILENAME="$SAVE_DIR/screenshot_$(date +'%Y-%m-%d_%H-%M-%S').png"

case "$MODE" in
    fullscreen)
        ACTIVE_MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null)
        if [ -n "$ACTIVE_MONITOR" ]; then
            grim -s "$SCALE" -o "$ACTIVE_MONITOR" "$FILENAME"
        else
            grim -s "$SCALE" "$FILENAME"
        fi
        ;;
    window)
        ACTIVE_WINDOW=$(hyprctl activewindow -j 2>/dev/null)
        GEOMETRY=$(echo "$ACTIVE_WINDOW" | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null)
        if [ -z "$GEOMETRY" ] || [ "$GEOMETRY" = "null,null nullxnull" ]; then
            exit 1
        fi
        grim -s "$SCALE" -g "$GEOMETRY" "$FILENAME"
        ;;
    region|*)
        GEOMETRY=$(slurp -d 2>/dev/null)
        if [ -z "$GEOMETRY" ]; then
            exit 0 # Dibatalkan pengguna
        fi
        grim -s "$SCALE" -g "$GEOMETRY" "$FILENAME"
        ;;
esac

if [ -f "$FILENAME" ] && [ -s "$FILENAME" ]; then
    wl-copy --type image/png < "$FILENAME" 2>/dev/null & disown
    canberra-gtk-play -i camera-shutter 2>/dev/null & disown
    notify-send -a "Sora Screenshot" \
        -i "$FILENAME" \
        -h string:image-path:"$FILENAME" \
        "Screenshot Tersimpan (HD ${SCALE}x)" \
        "Disimpan di ~/Pictures/Screenshots dan disalin ke clipboard" & disown
fi
