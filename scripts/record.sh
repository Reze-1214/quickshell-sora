#!/usr/bin/env bash
# Sora Screen Recorder Script (wf-recorder)

SAVE_DIR="$HOME/Videos/Recordings"
mkdir -p "$SAVE_DIR"

# 1. Toggle: Jika wf-recorder sedang berjalan, hentikan dengan anggun (SIGINT)
if pgrep -x wf-recorder > /dev/null; then
    pkill --signal SIGINT -x wf-recorder
    notify-send -u normal -i media-record -a "Sora Recorder" "Perekaman Selesai" "Video disimpan di ~/Videos/Recordings/"
    exit 0
fi

# 2. Parse argumen
AUDIO_FLAG=""
MODE="region"

for arg in "$@"; do
    case "$arg" in
        -s|--sound)
            AUDIO_FLAG="-a"
            ;;
        -f|--fullscreen)
            MODE="fullscreen"
            ;;
    esac
done

# 3. Tentukan area atau monitor
FILENAME="$SAVE_DIR/record_$(date +'%Y-%m-%d_%H-%M-%S').mp4"

if [ "$MODE" = "fullscreen" ]; then
    ACTIVE_MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null)
    notify-send -u normal -i media-record -a "Sora Recorder" "Perekaman Layar Dimulai" "Mode: Layar Penuh ($ACTIVE_MONITOR)\nTekan shortcut lagi untuk berhenti"
    if [ -n "$ACTIVE_MONITOR" ]; then
        wf-recorder $AUDIO_FLAG -o "$ACTIVE_MONITOR" --pixel-format yuv420p -f "$FILENAME" >/dev/null 2>&1 & disown
    else
        wf-recorder $AUDIO_FLAG --pixel-format yuv420p -f "$FILENAME" >/dev/null 2>&1 & disown
    fi
else
    # Region selection via slurp
    REGION=$(slurp 2>/dev/null)
    if [ -z "$REGION" ]; then
        exit 0 # Dibatalkan oleh pengguna
    fi
    notify-send -u normal -i media-record -a "Sora Recorder" "Perekaman Area Dimulai" "Tekan shortcut lagi untuk berhenti"
    wf-recorder $AUDIO_FLAG -g "$REGION" --pixel-format yuv420p -f "$FILENAME" >/dev/null 2>&1 & disown
fi
