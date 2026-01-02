#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------
# 1. Configuration & Input Setup
# ------------------------------------------------------------
CONFIG_FILE="last.config"
INPUT_DIR="./Out_LUTed"
FIRST_CLIPS_DIR="./First_clip"
LAST_CLIPS_DIR="./Last_clip"
OUTPUT_DIR="./Final_Movie"
THUMB_DIR="./Thumbnail"
MUSIC_DIR="./Music"
FONT_FILE="./Sk-Modernist.ttf"
PROCESS_DELAY_SEC="5"
mkdir -p "$OUTPUT_DIR" "$THUMB_DIR"
OUTPUT_DIR_ABS="$(cd "$OUTPUT_DIR" && pwd)"

# Load previous settings if file exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "--- Last Used Settings Found ---"
    echo " Saturation: ${LAST_SAT_VAL:-1.0}"
    echo " Gamma:      ${LAST_GAMMA_VAL:-1.0}"
    echo " Brightness: ${LAST_BRIGHT_VAL:-0.0}"
    echo " Temp:       ${LAST_TEMP_VAL:-0.0}"
    echo " YellowFix:  ${LAST_YELLOW_FIX_LEVEL:-0}"
    echo " Cinematic:  ${LAST_CINEMATIC_PRESET:-0}"
    echo " Text 1:     ${LAST_TEXT1:-None}"
    echo " Text 2:     ${LAST_TEXT2:-None}"
    echo " Music ID:   ${LAST_MUSIC_IDX:-None}"
    echo " Intro ID:   ${LAST_FIRST_IDX:-None}"
    echo " Outro ID:   ${LAST_LAST_IDX:-None}"
    echo "--------------------------------"
fi

echo "------------------------------------------------"
echo "🎥 CINEMATIC 4K ASSEMBLY (Apple Silicon Optimized)"
echo "------------------------------------------------"

if [ ! -f "$FONT_FILE" ]; then
    echo "⚠️  Font file $FONT_FILE not found."
    exit 1
fi

echo "⚠️  Just enter to keep last used values."

# Basic numeric validation to avoid broken filter strings.
is_number() {
    [[ "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]]
}

# Saturation Guide
read -r -p "Enter saturation value (0.8-2) [${LAST_SAT_VAL:-1.0}]: " SAT_VAL
SAT_VAL=${SAT_VAL:-${LAST_SAT_VAL:-1.0}}
if ! is_number "$SAT_VAL"; then
    SAT_VAL="1.0"
fi

# Gamma Guide
read -r -p "Enter gamma value (0.8-1.4) [${LAST_GAMMA_VAL:-1.0}]: " GAMMA_VAL
GAMMA_VAL=${GAMMA_VAL:-${LAST_GAMMA_VAL:-1.0}}
if ! is_number "$GAMMA_VAL"; then
    GAMMA_VAL="1.0"
fi

# Brightness Guide
read -r -p "Enter brightness value (-0.2 to 0.2) [${LAST_BRIGHT_VAL:-0.0}]: " BRIGHT_VAL
BRIGHT_VAL=${BRIGHT_VAL:-${LAST_BRIGHT_VAL:-0.0}}
if ! is_number "$BRIGHT_VAL"; then
    BRIGHT_VAL="0.0"
fi

# Temperature Guide
echo "TEMP: 0.0 (Neutral), 0.1 (Warm), -0.1 (Cool)"
read -r -p "Enter temperature adjustment [${LAST_TEMP_VAL:-0.0}]: " TEMP_VAL
TEMP_VAL=${TEMP_VAL:-${LAST_TEMP_VAL:-0.0}}

# Yellow cast correction (global)
read -r -p "Yellow cast correction level (0=Off, 1=Low, 2=Med, 3=High) [${LAST_YELLOW_FIX_LEVEL:-0}]: " YELLOW_FIX_LEVEL
YELLOW_FIX_LEVEL=${YELLOW_FIX_LEVEL:-${LAST_YELLOW_FIX_LEVEL:-0}}

# Cinematic filter selection (global)
echo ""
echo "CINEMATIC presets:"
echo "  0) Off"
echo "  1) Blockbuster (teal/orange punch)"
echo "  2) Vintage Camo (muted greens)"
echo "  3) Film Warm (soft warm)"
echo "  4) Bleach Bypass (desaturated, contrasty)"
echo "  5) Sepia (classic warm brown)"
echo "  6) Sci‑Fi (cool, metallic)"
echo "  7) Black & White (iMovie‑style)"
read -r -p "Select Cinematic preset [${LAST_CINEMATIC_PRESET:-0}]: " CINEMATIC_PRESET
CINEMATIC_PRESET=${CINEMATIC_PRESET:-${LAST_CINEMATIC_PRESET:-0}}

# Text Selection
echo ""
read -r -p "Enter Text Line 1 (Top) [${LAST_TEXT1:-}]: " TEXT_LINE1
TEXT_LINE1=${TEXT_LINE1:-${LAST_TEXT1:-}}
read -r -p "Enter Text Line 2 (Bottom) [${LAST_TEXT2:-}]: " TEXT_LINE2
TEXT_LINE2=${TEXT_LINE2:-${LAST_TEXT2:-}}

# ------------------------------------------------------------
# 2. Selection: Music, Intro & Outro
# ------------------------------------------------------------
shopt -s nullglob

# Select Music
MUSIC_FILES=("$MUSIC_DIR"/*.{mp3,wav,m4a,aac})
if [ ${#MUSIC_FILES[@]} -eq 0 ]; then
    echo "⚠️  No music files found in $MUSIC_DIR"
    exit 1
fi
for i in "${!MUSIC_FILES[@]}"; do echo "  [$((i+1))] $(basename "${MUSIC_FILES[$i]}")"; done
read -r -p "Select Music Number [${LAST_MUSIC_IDX:-}]: " MUSIC_IDX
MUSIC_IDX=${MUSIC_IDX:-${LAST_MUSIC_IDX:-}}
if [ -z "${MUSIC_IDX:-}" ]; then
    echo "⚠️  No music selected."
    exit 1
fi
SELECTED_MUSIC="${MUSIC_FILES[$((MUSIC_IDX-1))]}"

# Select First Clip (Intro)
SELECTED_FIRST_CLIP=""
FIRST_FILES=("$FIRST_CLIPS_DIR"/*.{MP4,mp4,mov,mkv})
if [ ${#FIRST_FILES[@]} -gt 0 ]; then
    echo -e "\n--- Available Intro Clips (First Clip) ---"
    for i in "${!FIRST_FILES[@]}"; do echo "  [$((i+1))] $(basename "${FIRST_FILES[$i]}")"; done
    read -r -p "Select Intro Number [${LAST_FIRST_IDX:-1}]: " FIRST_IDX
    FIRST_IDX=${FIRST_IDX:-${LAST_FIRST_IDX:-1}}
    if [ -n "$FIRST_IDX" ]; then
        SELECTED_FIRST_CLIP="${FIRST_FILES[$((FIRST_IDX-1))]}"
    fi
fi

# Select Last Clip (Outro)
echo -e "\n--- Available Outro Clips (Last Clip) ---"
LAST_FILES=("$LAST_CLIPS_DIR"/*.{mp4,mov,mkv})
for i in "${!LAST_FILES[@]}"; do echo "  [$((i+1))] $(basename "${LAST_FILES[$i]}")"; done
read -r -p "Select Outro Number [${LAST_LAST_IDX:-1}]: " LAST_IDX
LAST_IDX=${LAST_IDX:-${LAST_LAST_IDX:-1}}
SELECTED_LAST_CLIP="${LAST_FILES[$((LAST_IDX-1))]}"

# Save all settings to last.config for next run
cat <<EOF > "$CONFIG_FILE"
LAST_SAT_VAL="$SAT_VAL"
LAST_GAMMA_VAL="$GAMMA_VAL"
LAST_BRIGHT_VAL="$BRIGHT_VAL"
LAST_TEMP_VAL="$TEMP_VAL"
LAST_YELLOW_FIX_LEVEL="$YELLOW_FIX_LEVEL"
LAST_CINEMATIC_PRESET="$CINEMATIC_PRESET"
LAST_TEXT1="$TEXT_LINE1"
LAST_TEXT2="$TEXT_LINE2"
LAST_MUSIC_IDX="$MUSIC_IDX"
LAST_FIRST_IDX="${FIRST_IDX:-}"
LAST_LAST_IDX="$LAST_IDX"
EOF

TARGET_W=3840
TARGET_H=2160
BITRATE="60M"
FADE_DUR=1.5
THREADS=4 

# ------------------------------------------------------------
# Cache setup for preprocessed clips (reused across runs)
# ------------------------------------------------------------
CACHE_DIR="./.cache_preprocessed"
mkdir -p "$CACHE_DIR"

SETTINGS_STR="w=$TARGET_W,h=$TARGET_H,temp=$TEMP_VAL,yellow=$YELLOW_FIX_LEVEL,sat=$SAT_VAL,gamma=$GAMMA_VAL,bright=$BRIGHT_VAL,cinematic=$CINEMATIC_PRESET,fade=$FADE_DUR,bitrate=$BITRATE"
SETTINGS_HASH=$(printf "%s" "$SETTINGS_STR" | shasum -a 256 | awk '{print $1}')
SETTINGS_HASH_FILE="$CACHE_DIR/settings.hash"
printf "%s" "$SETTINGS_HASH" > "$SETTINGS_HASH_FILE"

# ------------------------------------------------------------
# 3. Gather All Clips (Conditional Assembly)
# ------------------------------------------------------------
MAIN_FILES=($(find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mov" \) | LC_ALL=C sort))

FILES=()
if [ -n "$SELECTED_FIRST_CLIP" ]; then
    FILES+=("$SELECTED_FIRST_CLIP")
fi

for f in "${MAIN_FILES[@]}"; do
    FILES+=("$f")
done

# Index of the very last clip from MAIN_FILES (before outro is added)
LAST_MAIN_INDEX=$(( ${#FILES[@]} - 1 ))

if [ -n "$SELECTED_LAST_CLIP" ]; then
    FILES+=("$SELECTED_LAST_CLIP")
fi

NUM_FILES=${#FILES[@]}

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT
CONCAT_LIST="$TMPDIR/concat.txt"


escape_drawtext() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//:/\\:}
    s=${s//,/\\,}
    s=${s//%/\\%}
    printf "%s" "$s"
}

measure_text_width() {
    local text="$1"
    local size="$2"
    local crop
    if [ -z "$text" ]; then
        echo 0
        return
    fi
    crop=$(ffmpeg -hide_banner -loglevel info -f lavfi -i "color=black:s=${TARGET_W}x${TARGET_H}:d=1" \
        -frames:v 5 -vf "drawtext=fontfile=${FONT_FILE}:text=${text}:fontsize=${size}:x=0:y=0:fontcolor=white,format=gray,cropdetect=24:16:0" \
        -f null - 2>&1 | grep -oE "crop=[0-9]+:[0-9]+:[0-9]+:[0-9]+" | tail -n 1)
    if [ -z "$crop" ]; then
        echo 0
        return
    fi
    echo "${crop#crop=}" | cut -d: -f1
}

cinematic_filter() {
    case "$CINEMATIC_PRESET" in
        1)
            echo ",colorbalance=rs=0.06:gs=-0.04:bs=-0.10:rm=0.04:bm=-0.05,eq=contrast=1.25:saturation=1.28,curves=all='0/0 0.22/0.15 0.5/0.55 0.78/0.88 1/1',unsharp=9:9:1.2:7:7:0.8,vignette=0.45"
            ;;
        2)
            echo ",colorbalance=rs=-0.02:gs=0.04:bs=-0.03:rm=-0.02:gm=0.04:bm=-0.03,eq=contrast=0.90:saturation=0.70,unsharp=5:5:0.6:5:5:0.4,vignette=0.45"
            ;;
        3)
            echo ",colorbalance=rs=0.04:gs=0.02:bs=-0.04:rm=0.03:gm=0.02:bm=-0.03,eq=contrast=1.08:saturation=1.18"
            ;;
        4)
            echo ",hue=s=0.30,eq=contrast=1.22:brightness=-0.03,unsharp=7:7:0.7"
            ;;
        5)
            echo ",colorbalance=rs=0.07:gs=0.03:bs=-0.08:rm=0.06:gm=0.03:bm=-0.07,eq=contrast=1.10:saturation=0.80"
            ;;
        6)
            echo ",colorbalance=rs=-0.03:gs=0.00:bs=0.07:rm=-0.03:gm=0.00:bm=0.06,eq=contrast=1.20:saturation=0.80,unsharp=7:7:0.8"
            ;;
        7)
            echo ",hue=s=0,eq=contrast=1.22:brightness=0.02,curves=all='0/0 0.2/0.12 0.5/0.52 0.8/0.9 1/1'"
            ;;
        *)
            echo ""
            ;;
    esac
}

# ------------------------------------------------------------
# Preview: 5-second sample without preprocessing all clips
# ------------------------------------------------------------
ALPHA='if(lt(t,3),0,if(lt(t,4),(t-3)/1,if(lt(t,9),1,if(lt(t,10),(1-(t-9)/1),0))))'
ESC_TEXT1=$(escape_drawtext "$TEXT_LINE1")
ESC_TEXT2=$(escape_drawtext "$TEXT_LINE2")
BOX_ENABLE="between(t,3,10)"
LINE1_SIZE=200
LINE2_SIZE=130
LINE1_X=150
LINE2_X=150
STRIP_LINE1_BASELINE_OFFSET=520
STRIP_LINE2_BASELINE_OFFSET=340
TEXT_LINE1_BASELINE_OFFSET=630
TEXT_LINE2_BASELINE_OFFSET=450
LINE1_ASC_PCT=70
LINE2_DESC_PCT=25
BOX_PAD_X=24
BOX_PAD_Y=12
PAD_BEFORE_FADE=200
FADE_W=300

TEXT1_LEN=${#TEXT_LINE1}
TEXT2_LEN=${#TEXT_LINE2}
TEXT1_W=$(measure_text_width "$ESC_TEXT1" "$LINE1_SIZE")
TEXT2_W=$(measure_text_width "$ESC_TEXT2" "$LINE2_SIZE")
if [ "$TEXT1_W" -le 0 ]; then
    TEXT1_W=$(awk -v len="$TEXT1_LEN" -v size="$LINE1_SIZE" 'BEGIN {printf "%.0f", len*size*0.55}')
fi
if [ "$TEXT2_W" -le 0 ]; then
    TEXT2_W=$(awk -v len="$TEXT2_LEN" -v size="$LINE2_SIZE" 'BEGIN {printf "%.0f", len*size*0.55}')
fi
MAX_TEXT_W=$TEXT1_W
if [ "$TEXT2_W" -gt "$MAX_TEXT_W" ]; then
    MAX_TEXT_W=$TEXT2_W
fi

BOX_W=$((MAX_TEXT_W + (BOX_PAD_X * 2) + PAD_BEFORE_FADE))
MIN_BOX_W=$((FADE_W + 80))
if [ "$BOX_W" -lt "$MIN_BOX_W" ]; then
    BOX_W=$MIN_BOX_W
fi
BOX_X=$((LINE1_X - BOX_PAD_X))

LINE1_ASC=$((LINE1_SIZE * LINE1_ASC_PCT / 100))
LINE2_DESC=$((LINE2_SIZE * LINE2_DESC_PCT / 100))
BOX_TOP_OFFSET=$((STRIP_LINE1_BASELINE_OFFSET + LINE1_ASC + BOX_PAD_Y))
BOX_BOTTOM_OFFSET=$((STRIP_LINE2_BASELINE_OFFSET - LINE2_DESC - BOX_PAD_Y))
BOX_H=$((BOX_TOP_OFFSET - BOX_BOTTOM_OFFSET))
BOX_Y_EXPR="ih-$BOX_TOP_OFFSET"

BOX_W_MAIN=$((BOX_W - FADE_W))
FADE_STEP=30
FADE_X0=$((BOX_X + BOX_W_MAIN))
FADE_X1=$((FADE_X0 + FADE_STEP))
FADE_X2=$((FADE_X1 + FADE_STEP))
FADE_X3=$((FADE_X2 + FADE_STEP))
FADE_X4=$((FADE_X3 + FADE_STEP))
FADE_X5=$((FADE_X4 + FADE_STEP))
FADE_X6=$((FADE_X5 + FADE_STEP))
FADE_X7=$((FADE_X6 + FADE_STEP))
FADE_X8=$((FADE_X7 + FADE_STEP))
FADE_X9=$((FADE_X8 + FADE_STEP))
PREVIEW_DUR=5
SAMPLE_SOURCE="${FILES[0]}"
PREVIEW_FADE_OUT_ST=$(awk -v d="$PREVIEW_DUR" -v f="$FADE_DUR" 'BEGIN {st=d-f; if (st<0) st=0; printf "%.2f", st}')

PREVIEW_VFILT="scale=$TARGET_W:$TARGET_H:force_original_aspect_ratio=increase,crop=$TARGET_W:$TARGET_H"
if [ "$TEMP_VAL" != "0.0" ] && [ "$TEMP_VAL" != "0" ]; then
    R_MAX=$(awk -v t="$TEMP_VAL" 'BEGIN { val = (t < 0 ? 1.0 + t : 1.0); printf "%.3f", (val > 1.0 ? 1.0 : (val < 0 ? 0 : val)) }')
    B_MAX=$(awk -v t="$TEMP_VAL" 'BEGIN { val = (t > 0 ? 1.0 - t : 1.0); printf "%.3f", (val > 1.0 ? 1.0 : (val < 0 ? 0 : val)) }')
    PREVIEW_VFILT="$PREVIEW_VFILT,colorlevels=romax=$R_MAX:bomax=$B_MAX"
fi
case "$YELLOW_FIX_LEVEL" in
    1) PREVIEW_VFILT="$PREVIEW_VFILT,colorbalance=rm=-0.03:gm=-0.03:bm=0.03" ;;
    2) PREVIEW_VFILT="$PREVIEW_VFILT,colorbalance=rm=-0.06:gm=-0.06:bm=0.06" ;;
    3) PREVIEW_VFILT="$PREVIEW_VFILT,colorbalance=rm=-0.10:gm=-0.10:bm=0.10" ;;
    *) ;;
esac

PREVIEW_VFILT="$PREVIEW_VFILT,fps=30,eq=saturation=$SAT_VAL:gamma=$GAMMA_VAL:brightness=$BRIGHT_VAL,format=yuv420p10le"
PREVIEW_VFILT="$PREVIEW_VFILT$(cinematic_filter)"
PREVIEW_V_FILTER_MAIN="[0:v]${PREVIEW_VFILT},drawbox=x=${BOX_X}:y=${BOX_Y_EXPR}:w=${BOX_W_MAIN}:h=${BOX_H}:color=white@0.6:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X0}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.6:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X1}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.54:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X2}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.48:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X3}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.42:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X4}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.36:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X5}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.30:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X6}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.24:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X7}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.18:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X8}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.12:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X9}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.06:t=fill:enable='${BOX_ENABLE}',drawtext=fontfile=${FONT_FILE}:text=${ESC_TEXT1}:fontcolor=black:fontsize=${LINE1_SIZE}:x=${LINE1_X}:y=H-${TEXT_LINE1_BASELINE_OFFSET}:alpha='${ALPHA}',drawtext=fontfile=${FONT_FILE}:text=${ESC_TEXT2}:fontcolor=black@0.95:fontsize=${LINE2_SIZE}:x=${LINE2_X}:y=H-${TEXT_LINE2_BASELINE_OFFSET}:alpha='${ALPHA}',fade=t=in:st=0:d=0.1[vout]"
PREVIEW_V_FILTER_PLAIN="[0:v]${PREVIEW_VFILT}[vout]"
PREVIEW_A_FILTER="[1:a]afade=t=in:st=0:d=$FADE_DUR,afade=t=out:st=$PREVIEW_FADE_OUT_ST:d=$FADE_DUR[aout]"

echo "Generating 5-second sample clips..."
SAMPLE_IDX_1=0
SAMPLE_IDX_2=$(( NUM_FILES / 4 ))
SAMPLE_IDX_3=$(( NUM_FILES / 2 ))
SAMPLE_IDX_4=$(( (NUM_FILES * 3) / 4 ))
SAMPLE_IDXS=("$SAMPLE_IDX_1" "$SAMPLE_IDX_2" "$SAMPLE_IDX_3" "$SAMPLE_IDX_4")
SAMPLE_OUTPUTS=()
USED_SAMPLE_IDXS=()
SAMPLE_COUNT=0
for idx in "${SAMPLE_IDXS[@]-}"; do
    if [[ -z "${idx:-}" || ! "$idx" =~ ^[0-9]+$ ]]; then
        continue
    fi
    if [ "$idx" -ge "$NUM_FILES" ]; then
        continue
    fi
    SKIP=0
    for used in "${USED_SAMPLE_IDXS[@]-}"; do
        if [[ -z "${used:-}" || ! "$used" =~ ^[0-9]+$ ]]; then
            continue
        fi
        if [ "$idx" -eq "$used" ]; then
            SKIP=1
            break
        fi
    done
    if [ "$SKIP" -eq 1 ]; then
        continue
    fi
    USED_SAMPLE_IDXS+=("$idx")
    SAMPLE_COUNT=$((SAMPLE_COUNT + 1))
    SAMPLE_SOURCE="${FILES[$idx]}"
    SAMPLE_NAME="SAMPLE_PREVIEW_$(printf "%02d" "$SAMPLE_COUNT").mp4"
    SAMPLE_OUTPUT="$OUTPUT_DIR/$SAMPLE_NAME"
    SAMPLE_OUTPUTS+=("$SAMPLE_OUTPUT")
    if [ "$SAMPLE_COUNT" -eq 1 ]; then
        PREVIEW_V_FILTER="$PREVIEW_V_FILTER_MAIN"
    else
        PREVIEW_V_FILTER="$PREVIEW_V_FILTER_PLAIN"
    fi

    nice -n 20 ffmpeg -hide_banner -loglevel error -y -threads "$THREADS" \
        -i "$SAMPLE_SOURCE" \
        -stream_loop -1 -i "$SELECTED_MUSIC" \
        -filter_complex "$PREVIEW_V_FILTER;$PREVIEW_A_FILTER" \
        -map "[vout]" -map "[aout]" \
        -shortest \
        -c:v hevc_videotoolbox -b:v "$BITRATE" -tag:v hvc1 -movflags +faststart \
        -c:a aac -t "$PREVIEW_DUR" \
        "$SAMPLE_OUTPUT"
done

if [ "${#SAMPLE_OUTPUTS[@]}" -gt 1 ]; then
    SAMPLE_CONCAT_LIST="$TMPDIR/sample_concat.txt"
    : > "$SAMPLE_CONCAT_LIST"
    SAMPLE_CONCAT_COUNT=0
    GRID_INPUTS=()
    for s in "${SAMPLE_OUTPUTS[@]}"; do
        if [ -f "$s" ]; then
            printf "file '%s'\n" "$OUTPUT_DIR_ABS/$(basename "$s")" >> "$SAMPLE_CONCAT_LIST"
            SAMPLE_CONCAT_COUNT=$((SAMPLE_CONCAT_COUNT + 1))
            GRID_INPUTS+=("$s")
        fi
    done

    if [ "$SAMPLE_CONCAT_COUNT" -eq 4 ]; then
        SAMPLE_GRID="$OUTPUT_DIR/SAMPLE_PREVIEW_GRID.mp4"
        ffmpeg -hide_banner -loglevel error -y \
            -i "${GRID_INPUTS[0]}" -i "${GRID_INPUTS[1]}" -i "${GRID_INPUTS[2]}" -i "${GRID_INPUTS[3]}" \
            -filter_complex "[0:v][1:v]hstack=inputs=2[top];[2:v][3:v]hstack=inputs=2[bottom];[top][bottom]vstack=inputs=2[v]" \
            -map "[v]" -shortest \
            -c:v hevc_videotoolbox -b:v "$BITRATE" -tag:v hvc1 -movflags +faststart \
            "$SAMPLE_GRID"
        echo "✅ Grid sample created: $SAMPLE_GRID"
    elif [ "$SAMPLE_CONCAT_COUNT" -gt 1 ]; then
        SAMPLE_ALL="$OUTPUT_DIR/SAMPLE_PREVIEW_ALL.mp4"
        ffmpeg -hide_banner -loglevel error -f concat -safe 0 -i "$SAMPLE_CONCAT_LIST" \
            -c copy "$SAMPLE_ALL" -y
        echo "✅ Combined sample created: $SAMPLE_ALL"
    fi
fi
read -r -p 'Review the sample. Continue to render full video? (y/n): ' CONTINUE_RENDER

if [[ ! "$CONTINUE_RENDER" =~ ^[Yy]$ ]]; then
    exit 0
fi

# ------------------------------------------------------------
# 4. Step 1: Pre-process All Clips
# ------------------------------------------------------------
echo -e "\nStep 1/2: Preprocessing $NUM_FILES clips..."

for i in "${!FILES[@]}"; do
    INFILE="${FILES[$i]}"
    FADE_IN=0
    FADE_OUT=0
    if [[ $i -eq 0 ]]; then
        FADE_IN=1
    fi
    if [[ $i -eq $LAST_MAIN_INDEX ]] || [[ $i -eq $((NUM_FILES - 1)) ]]; then
        FADE_OUT=1
    fi

    CLIP_KEY=$(printf "%s|%s|%s|%s" "$SETTINGS_HASH" "$INFILE" "$FADE_IN" "$FADE_OUT" | shasum -a 256 | awk '{print $1}')
    OUTCLIP="$CACHE_DIR/clip_${CLIP_KEY:0:12}.mp4"
    
    PERCENT=$(( (i + 1) * 100 / NUM_FILES ))
    echo -ne "    Processing: [$((i+1))/$NUM_FILES] ($PERCENT%) $(basename "$INFILE")\r"

    VFILT="scale=$TARGET_W:$TARGET_H:force_original_aspect_ratio=increase,crop=$TARGET_W:$TARGET_H"

    if [ "$TEMP_VAL" != "0.0" ] && [ "$TEMP_VAL" != "0" ]; then
        R_MAX=$(awk -v t="$TEMP_VAL" 'BEGIN { val = (t < 0 ? 1.0 + t : 1.0); printf "%.3f", (val > 1.0 ? 1.0 : (val < 0 ? 0 : val)) }')
        B_MAX=$(awk -v t="$TEMP_VAL" 'BEGIN { val = (t > 0 ? 1.0 - t : 1.0); printf "%.3f", (val > 1.0 ? 1.0 : (val < 0 ? 0 : val)) }')
        VFILT="$VFILT,colorlevels=romax=$R_MAX:bomax=$B_MAX"
    fi
    case "$YELLOW_FIX_LEVEL" in
        1) VFILT="$VFILT,colorbalance=rm=-0.03:gm=-0.03:bm=0.03" ;;
        2) VFILT="$VFILT,colorbalance=rm=-0.06:gm=-0.06:bm=0.06" ;;
        3) VFILT="$VFILT,colorbalance=rm=-0.10:gm=-0.10:bm=0.10" ;;
        *) ;;
    esac

    VFILT="$VFILT,fps=30,eq=saturation=$SAT_VAL:gamma=$GAMMA_VAL:brightness=$BRIGHT_VAL,format=yuv420p10le"
    VFILT="$VFILT$(cinematic_filter)"

    if [[ $FADE_IN -eq 1 ]]; then
        VFILT="$VFILT,fade=t=in:st=0:d=$FADE_DUR"
    fi

    if [[ $FADE_OUT -eq 1 ]]; then
        DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INFILE")
        ST=$(awk -v d="$DUR" -v f="$FADE_DUR" 'BEGIN {printf "%.2f", d-f}')
        VFILT="$VFILT,fade=t=out:st=$ST:d=$FADE_DUR"
    fi

    if [ -f "$OUTCLIP" ] && [ "$OUTCLIP" -nt "$INFILE" ]; then
        : # Cache hit; reuse existing preprocessed clip.
    else
        nice -n 20 ffmpeg -nostdin -hide_banner -loglevel error -threads "$THREADS" -i "$INFILE" \
            -an -vf "$VFILT" -c:v hevc_videotoolbox -b:v "$BITRATE" -tag:v hvc1 -movflags +faststart "$OUTCLIP" -y
    fi
    
    printf "file '%s'\n" "$OUTCLIP" >> "$CONCAT_LIST"
    sleep "$PROCESS_DELAY_SEC"
done

# ------------------------------------------------------------
# 5. Step 2: Final Assembly
# ------------------------------------------------------------
echo -e "\n\nStep 2/2: Final Assembly..."
CONCAT_VIDEO="$TMPDIR/temp_joined.mp4"

ffmpeg -hide_banner -loglevel error -f concat -safe 0 -i "$CONCAT_LIST" \
    -fflags +genpts -avoid_negative_ts make_zero -c copy "$CONCAT_VIDEO" -y

TOTAL_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$CONCAT_VIDEO")
FADE_OUT_ST=$(awk -v d="$TOTAL_DUR" -v f="$FADE_DUR" 'BEGIN {printf "%.2f", d-f}')
FIRST_CLIP_DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${FILES[0]}")
TEXT_ENABLE="between(t,0,${FIRST_CLIP_DUR})"

# Build V_FILTER - construct step by step to avoid quoting issues
V_FILTER="[0:v]drawbox=x=${BOX_X}:y=${BOX_Y_EXPR}:w=${BOX_W_MAIN}:h=${BOX_H}:color=white@0.6:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X0}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.6:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X1}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.54:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X2}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.48:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X3}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.42:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X4}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.36:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X5}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.30:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X6}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.24:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X7}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.18:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X8}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.12:t=fill:enable='${BOX_ENABLE}',drawbox=x=${FADE_X9}:y=${BOX_Y_EXPR}:w=${FADE_STEP}:h=${BOX_H}:color=white@0.06:t=fill:enable='${BOX_ENABLE}',drawtext=fontfile=${FONT_FILE}:text=${ESC_TEXT1}:fontcolor=black:fontsize=${LINE1_SIZE}:x=${LINE1_X}:y=H-${TEXT_LINE1_BASELINE_OFFSET}:alpha='${ALPHA}':enable='${TEXT_ENABLE}',drawtext=fontfile=${FONT_FILE}:text=${ESC_TEXT2}:fontcolor=black@0.95:fontsize=${LINE2_SIZE}:x=${LINE2_X}:y=H-${TEXT_LINE2_BASELINE_OFFSET}:alpha='${ALPHA}':enable='${TEXT_ENABLE}',fade=t=in:st=0:d=0.1[vout]"

A_FILTER="[1:a]afade=t=in:st=0:d=$FADE_DUR,afade=t=out:st=$FADE_OUT_ST:d=$FADE_DUR[aout]"

FINAL_VIDEO_PATH="$OUTPUT_DIR/Final_Movie_4K.mp4"

echo "Rendering full video..."
nice -n 20 ffmpeg -hide_banner -stats -y -threads "$THREADS" \
    -i "$CONCAT_VIDEO" \
    -stream_loop -1 -i "$SELECTED_MUSIC" \
    -filter_complex "$V_FILTER;$A_FILTER" \
    -map "[vout]" -map "[aout]" \
    -shortest \
    -c:v hevc_videotoolbox -b:v "$BITRATE" -tag:v hvc1 -movflags +faststart \
    -c:a aac -b:a 320k \
    -t "$TOTAL_DUR" \
    "$FINAL_VIDEO_PATH"

# ------------------------------------------------------------
# 6. Step 3: Create Thumbnail
# ------------------------------------------------------------
echo -e "\nCreating YouTube Thumbnail from 5-second mark..."
ffmpeg -hide_banner -loglevel error -ss 5 -i "$FINAL_VIDEO_PATH" \
    -frames:v 1 -q:v 2 "$THUMB_DIR/Thumbnail.jpg" -y

echo "✅ Thumbnail saved to: $THUMB_DIR/Thumbnail.jpg"

exit 0
