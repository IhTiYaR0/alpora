#!/usr/bin/env bash
# ALPORA Screen Tools: Screenshots, Annotation, Screen Recording, OCR, and QR Code Scanner
set -euo pipefail

MODE="${1:-screenshot-region}"
PICTURES="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")"
VIDEOS="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

ensure_dir() {
    mkdir -p "$1"
}

notify() {
    local title="$1"
    local msg="$2"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "ALPORA Screen Tools" "$title" "$msg"
    fi
}

case "$MODE" in
    screenshot-region|--region|-r)
        ensure_dir "$PICTURES/Screenshots"
        OUTPUT="$PICTURES/Screenshots/ALPORA-${TIMESTAMP}.png"
        REGION="$(slurp 2>/dev/null)" || exit 0
        grim -g "$REGION" "$OUTPUT"
        wl-copy --type image/png < "$OUTPUT" 2>/dev/null || true
        notify "Screenshot Taken" "Region saved: $(basename "$OUTPUT") (copied to clipboard)"
        ;;

    screenshot-full|--full|-f)
        ensure_dir "$PICTURES/Screenshots"
        OUTPUT="$PICTURES/Screenshots/ALPORA-${TIMESTAMP}.png"
        grim "$OUTPUT"
        wl-copy --type image/png < "$OUTPUT" 2>/dev/null || true
        notify "Screenshot Taken" "Fullscreen saved: $(basename "$OUTPUT") (copied to clipboard)"
        ;;

    screenshot-window|--window|-w)
        ensure_dir "$PICTURES/Screenshots"
        OUTPUT="$PICTURES/Screenshots/ALPORA-${TIMESTAMP}.png"
        # Extract active window geometry if inside Hyprland
        if command -v hyprctl >/dev/null 2>&1; then
            BOX="$(hyprctl activewindow -j 2>/dev/null | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null || echo "")"
            if [[ -n "$BOX" && "$BOX" != "null,null nullxnull" ]]; then
                grim -g "$BOX" "$OUTPUT"
            else
                grim "$OUTPUT"
            fi
        else
            grim "$OUTPUT"
        fi
        wl-copy --type image/png < "$OUTPUT" 2>/dev/null || true
        notify "Screenshot Taken" "Window saved: $(basename "$OUTPUT")"
        ;;

    screenshot-satty|--satty|-s)
        ensure_dir "$PICTURES/Screenshots"
        OUTPUT="$PICTURES/Screenshots/ALPORA-${TIMESTAMP}.png"
        REGION="$(slurp 2>/dev/null)" || exit 0
        if command -v satty >/dev/null 2>&1; then
            grim -g "$REGION" - | satty --filename - --output-filename "$OUTPUT"
        else
            grim -g "$REGION" "$OUTPUT"
            wl-copy --type image/png < "$OUTPUT" 2>/dev/null || true
            notify "Screenshot Taken" "Satty not found, saved to $(basename "$OUTPUT")"
        fi
        ;;

    ocr|--ocr)
        if ! command -v tesseract >/dev/null 2>&1; then
            notify "OCR Error" "tesseract is not installed. Please install tesseract and language packs."
            exit 1
        fi
        REGION="$(slurp 2>/dev/null)" || exit 0
        notify "ALPORA OCR" "Đang nhận diện văn bản..."
        # Determine available langs
        LANGS="eng"
        if tesseract --list-langs 2>/dev/null | grep -q 'vie'; then
            LANGS="eng+vie"
        fi
        TEXT="$(grim -g "$REGION" - | tesseract stdin stdout -l "$LANGS" 2>/dev/null | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        if [[ -n "$TEXT" ]]; then
            echo -n "$TEXT" | wl-copy
            PREVIEW="${TEXT:0:80}"
            notify "OCR Text Copied" "$PREVIEW..."
        else
            notify "OCR" "No text recognized in selected area."
        fi
        ;;

    qr|--qr)
        if ! command -v zbarimg >/dev/null 2>&1; then
            notify "QR Scanner Error" "zbarimg (zbar) is not installed."
            exit 1
        fi
        REGION="$(slurp 2>/dev/null)" || exit 0
        notify "ALPORA QR" "Đang quét mã QR..."
        QR_DATA="$(grim -g "$REGION" - | zbarimg -q --raw - 2>/dev/null || true)"
        if [[ -n "$QR_DATA" ]]; then
            echo -n "$QR_DATA" | wl-copy
            notify "QR Code Decoded" "$QR_DATA"
        else
            notify "QR Scanner" "No QR code detected in selected area."
        fi
        ;;

    record-start|--record)
        ensure_dir "$VIDEOS/Recordings"
        OUTPUT="$VIDEOS/Recordings/ALPORA-${TIMESTAMP}.mp4"
        PID_FILE="/tmp/alpora-recorder.pid"

        if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            notify "Screen Recorder" "Recording already in progress."
            exit 0
        fi

        WITH_AUDIO=false
        if [[ "${2:-}" == "--with-audio" ]]; then
            WITH_AUDIO=true
        fi

        REGION="$(slurp 2>/dev/null)" || exit 0

        if command -v gpu-screen-recorder >/dev/null 2>&1; then
            if [[ "$WITH_AUDIO" == true ]]; then
                gpu-screen-recorder -w "$REGION" -f 60 -a default_output -o "$OUTPUT" &
            else
                gpu-screen-recorder -w "$REGION" -f 60 -o "$OUTPUT" &
            fi
            echo "$!" > "$PID_FILE"
            notify "Screen Recording" "Started recording region..."
        elif command -v wf-recorder >/dev/null 2>&1; then
            if [[ "$WITH_AUDIO" == true ]]; then
                wf-recorder --audio -g "$REGION" -f "$OUTPUT" &
            else
                wf-recorder -g "$REGION" -f "$OUTPUT" &
            fi
            echo "$!" > "$PID_FILE"
            notify "Screen Recording" "Started recording with wf-recorder..."
        else
            notify "Recorder Error" "Neither gpu-screen-recorder nor wf-recorder is installed."
            exit 1
        fi
        ;;

    record-stop|--stop-record)
        PID_FILE="/tmp/alpora-recorder.pid"
        if [[ -f "$PID_FILE" ]]; then
            PID="$(cat "$PID_FILE")"
            if kill -0 "$PID" 2>/dev/null; then
                kill -INT "$PID" 2>/dev/null || kill "$PID" 2>/dev/null
                rm -f "$PID_FILE"
                notify "Screen Recording" "Recording saved."
            else
                rm -f "$PID_FILE"
                notify "Screen Recording" "No active recording found."
            fi
        else
            # Try killall wf-recorder / gpu-screen-recorder
            killall -INT wf-recorder 2>/dev/null || killall -INT gpu-screen-recorder 2>/dev/null || true
            notify "Screen Recording" "Stopped recording."
        fi
        ;;

    *)
        echo "Usage: $0 {screenshot-region|screenshot-full|screenshot-window|screenshot-satty|ocr|qr|record-start|record-stop}"
        exit 1
        ;;
esac
