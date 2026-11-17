#!/usr/bin/env bash
# Sora Screen Recorder Script (wf-recorder)

SAVE_DIR="$HOME/Videos/Recordings"
mkdir -p "$SAVE_DIR"

# 1. Toggle: If wf-recorder is running, stop it gracefully (SIGINT)
if pgrep -x wf-recorder > /dev/null; then
    pkill --signal SIGINT -x wf-recorder
    notify-send -u normal -i media-record -a "Sora Recorder" "Recording Finished" "Video saved to ~/Videos/Recordings/"
    exit 0
fi

# 2. Parse arguments
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

# 3. Determine region or monitor
FILENAME="$SAVE_DIR/record_$(date +'%Y-%m-%d_%H-%M-%S').mp4"

if [ "$MODE" = "fullscreen" ]; then
    ACTIVE_MONITOR=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null)
    notify-send -u normal -i media-record -a "Sora Recorder" "Screen Recording Started" "Mode: Fullscreen ($ACTIVE_MONITOR)\nPress shortcut again to stop"
    if [ -n "$ACTIVE_MONITOR" ]; then
        wf-recorder $AUDIO_FLAG -o "$ACTIVE_MONITOR" --pixel-format yuv420p -f "$FILENAME" >/dev/null 2>&1 & disown
    else
        wf-recorder $AUDIO_FLAG --pixel-format yuv420p -f "$FILENAME" >/dev/null 2>&1 & disown
    fi
else
    # Region selection via slurp
    REGION=$(slurp 2>/dev/null)
    if [ -z "$REGION" ]; then
        exit 0 # Cancelled by user
    fi
    notify-send -u normal -i media-record -a "Sora Recorder" "Region Recording Started" "Press shortcut again to stop"
    wf-recorder $AUDIO_FLAG -g "$REGION" --pixel-format yuv420p -f "$FILENAME" >/dev/null 2>&1 & disown
fi
