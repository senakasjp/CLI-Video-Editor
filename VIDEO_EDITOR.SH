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
mkdir -p "$OUTPUT_DIR" "$THUMB_DIR"

# Load previous settings if file exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "--- Last Used Settings Found ---"
    echo " Saturation: ${LAST_SAT_VAL:-1.0}"
    echo " Gamma:      ${LAST_GAMMA_VAL:-1.0}"
    echo " Temp:       ${LAST_TEMP_VAL:-0.0}"
    echo " Curves:     ${LAST_CURVES_PRESET:-off}"
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

# Saturation Guide
read -r -p "Enter saturation value (0.8-2) [${LAST_SAT_VAL:-1.0}]: " SAT_VAL
SAT_VAL=${SAT_VAL:-${LAST_SAT_VAL:-1.0}}

# Gamma Guide
read -r -p "Enter gamma value (0.8-1.4) [${LAST_GAMMA_VAL:-1.0}]: " GAMMA_VAL
GAMMA_VAL=${GAMMA_VAL:-${LAST_GAMMA_VAL:-1.0}}

# Temperature Guide
echo "TEMP: 0.0 (Neutral), 0.1 (Warm), -0.1 (Cool)"
read -r -p "Enter temperature adjustment [${LAST_TEMP_VAL:-0.0}]: " TEMP_VAL
TEMP_VAL=${TEMP_VAL:-${LAST_TEMP_VAL:-0.0}}

# Curves Selection
echo ""
echo "CURVES presets:"
echo "  0) Off"
echo "  1) Cool (reduce yellow cast)"
echo "  2) Warm (add warmth)"
echo "  3) Contrast punch (slight S-curve)"
read -r -p "Select Curves preset [${LAST_CURVES_PRESET:-0}]: " CURVES_PRESET
CURVES_PRESET=${CURVES_PRESET:-${LAST_CURVES_PRESET:-0}}

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
LAST_TEMP_VAL="$TEMP_VAL"
LAST_CURVES_PRESET="$CURVES_PRESET"
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

# Analyse a clip quickly to decide which curve preset to apply (robust: text stats)
analyze_clip_type() {
    local file="$1"

    # Sample a few frames, downscale for speed, then compute signal stats.
    # We'll classify:
    #  - DARK if YAVG is low
    #  - GREEN_DOM if G is notably higher than R and B
    local stats
    stats=$(ffmpeg -nostdin -hide_banner -loglevel info -i "$file" \
        -vf "fps=1,scale=320:180,signalstats" -frames:v 5 -f null - 2>&1 || true)

    # Extract last seen averages from signalstats lines
    local y r g b
    y=$(printf "%s\n" "$stats" | awk -F'YAVG:' '/YAVG:/ {split($2,a," "); y=a[1]} END{print y+0}')
    r=$(printf "%s\n" "$stats" | awk -F'RAVG:' '/RAVG:/ {split($2,a," "); r=a[1]} END{print r+0}')
    g=$(printf "%s\n" "$stats" | awk -F'GAVG:' '/GAVG:/ {split($2,a," "); g=a[1]} END{print g+0}')
    b=$(printf "%s\n" "$stats" | awk -F'BAVG:' '/BAVG:/ {split($2,a," "); b=a[1]} END{print b+0}')

    # Heuristics (8-bit scale 0-255)
    if awk -v y="$y" 'BEGIN{exit !(y>0 && y<85)}'; then
        echo "DARK"
        return
    fi

    # green dominance: G higher than mean(R,B) by margin, and B not keeping up
    if awk -v r="$r" -v g="$g" -v b="$b" 'BEGIN{
        m=(r+b)/2;
        exit !(g > (m+10) && b < (g-8));
    }'; then
        echo "GREEN_DOM"
        return
    fi

    echo "NORMAL"
}

escape_drawtext() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//:/\\:}
    s=${s//,/\\,}
    s=${s//%/\\%}
    printf "%s" "$s"
}

# ------------------------------------------------------------
# Preview: 5-second sample without preprocessing all clips
# ------------------------------------------------------------
ALPHA='if(lt(t,3),0,if(lt(t,4),(t-3)/1,if(lt(t,9),1,if(lt(t,10),(1-(t-9)/1),0))))'
ESC_TEXT1=$(escape_drawtext "$TEXT_LINE1")
ESC_TEXT2=$(escape_drawtext "$TEXT_LINE2")
PREVIEW_DUR=5
SAMPLE_SOURCE="${FILES[0]}"
PREVIEW_FADE_OUT_ST=$(awk -v d="$PREVIEW_DUR" -v f="$FADE_DUR" 'BEGIN {st=d-f; if (st<0) st=0; printf "%.2f", st}')

PREVIEW_VFILT="scale=$TARGET_W:$TARGET_H:force_original_aspect_ratio=increase,crop=$TARGET_W:$TARGET_H"
if [ "$TEMP_VAL" != "0.0" ] && [ "$TEMP_VAL" != "0" ]; then
    R_MAX=$(awk -v t="$TEMP_VAL" 'BEGIN { val = (t < 0 ? 1.0 + t : 1.0); printf "%.3f", (val > 1.0 ? 1.0 : (val < 0 ? 0 : val)) }')
    B_MAX=$(awk -v t="$TEMP_VAL" 'BEGIN { val = (t > 0 ? 1.0 - t : 1.0); printf "%.3f", (val > 1.0 ? 1.0 : (val < 0 ? 0 : val)) }')
    PREVIEW_VFILT="$PREVIEW_VFILT,colorlevels=romax=$R_MAX:bomax=$B_MAX"
fi

CLIP_TYPE=$(analyze_clip_type "$SAMPLE_SOURCE")
if [ "${CURVES_PRESET}" = "0" ] || [ "${CURVES_PRESET}" = "off" ]; then
    :
else
    case "$CLIP_TYPE" in
        GREEN_DOM)
            PREVIEW_VFILT="$PREVIEW_VFILT,\
curves=r='0/0 0.5/0.49 1/1':\
g='0/0 0.5/0.50 1/1':\
b='0/0 0.5/0.48 1/1',\
hue=h=0:s=0.93"
            ;;
        DARK)
            PREVIEW_VFILT="$PREVIEW_VFILT,\
curves=all='0/0 0.35/0.40 0.7/0.72 1/1',\
hue=h=0:s=0.98"
            ;;
        NORMAL|*)
            case "${CURVES_PRESET}" in
                1)
                    PREVIEW_VFILT="$PREVIEW_VFILT,\
curves=r='0/0 0.5/0.48 1/1':\
g='0/0 0.5/0.44 1/1':\
b='0/0 0.5/0.54 1/1',\
hue=h=0:s=0.95"
                    ;;
                2)
                    PREVIEW_VFILT="$PREVIEW_VFILT,\
curves=r='0/0 0.5/0.54 1/1':\
g='0/0 0.5/0.50 1/1':\
b='0/0 0.5/0.46 1/1',\
hue=h=0:s=1.02"
                    ;;
                3)
                    PREVIEW_VFILT="$PREVIEW_VFILT,\
curves=all='0/0 0.25/0.18 0.5/0.52 0.75/0.85 1/1',\
hue=h=0:s=0.95,\
eq=contrast=1.05:brightness=-0.02"
                    ;;
                *)
                    : # Off
                    ;;
            esac
            ;;
    esac
fi

PREVIEW_VFILT="$PREVIEW_VFILT,fps=30,eq=saturation=$SAT_VAL:gamma=$GAMMA_VAL,format=yuv420p"
PREVIEW_V_FILTER="[0:v]${PREVIEW_VFILT},drawtext=fontfile=${FONT_FILE}:text=${ESC_TEXT1}:fontcolor=white:fontsize=160:x=150:y=H-450:borderw=2:bordercolor=black@0.3:shadowcolor=black@0.6:shadowx=3:shadowy=3:alpha='${ALPHA}',drawtext=fontfile=${FONT_FILE}:text=${ESC_TEXT2}:fontcolor=white@0.95:fontsize=100:x=150:y=H-270:borderw=1:bordercolor=black@0.3:shadowcolor=black@0.3:shadowx=2:shadowy=2:alpha='${ALPHA}',fade=t=in:st=0:d=0.1[vout]"
PREVIEW_A_FILTER="[1:a]afade=t=in:st=0:d=$FADE_DUR,afade=t=out:st=$PREVIEW_FADE_OUT_ST:d=$FADE_DUR[aout]"

echo "Generating 5-second sample clip..."
nice -n 20 ffmpeg -hide_banner -loglevel error -y -threads "$THREADS" \
    -i "$SAMPLE_SOURCE" \
    -stream_loop -1 -i "$SELECTED_MUSIC" \
    -filter_complex "$PREVIEW_V_FILTER;$PREVIEW_A_FILTER" \
    -map "[vout]" -map "[aout]" \
    -shortest \
    -c:v h264_videotoolbox -b:v "$BITRATE" \
    -c:a aac -t "$PREVIEW_DUR" \
    "$OUTPUT_DIR/SAMPLE_PREVIEW.mp4"

echo "✅ Sample created: $OUTPUT_DIR/SAMPLE_PREVIEW.mp4"
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
    OUTCLIP="$TMPDIR/clip_$(printf "%03d" "$i").mp4"
    
    PERCENT=$(( (i + 1) * 100 / NUM_FILES ))
    echo -ne "    Processing: [$((i+1))/$NUM_FILES] ($PERCENT%) $(basename "$INFILE")\r"

    VFILT="scale=$TARGET_W:$TARGET_H:force_original_aspect_ratio=increase,crop=$TARGET_W:$TARGET_H"

    if [ "$TEMP_VAL" != "0.0" ] && [ "$TEMP_VAL" != "0" ]; then
        R_MAX=$(awk -v t="$TEMP_VAL" 'BEGIN { val = (t < 0 ? 1.0 + t : 1.0); printf "%.3f", (val > 1.0 ? 1.0 : (val < 0 ? 0 : val)) }')
        B_MAX=$(awk -v t="$TEMP_VAL" 'BEGIN { val = (t > 0 ? 1.0 - t : 1.0); printf "%.3f", (val > 1.0 ? 1.0 : (val < 0 ? 0 : val)) }')
        VFILT="$VFILT,colorlevels=romax=$R_MAX:bomax=$B_MAX"
    fi

    # Curves preset application (improved color control) - auto per clip
    CLIP_TYPE=$(analyze_clip_type "$INFILE")

    # If user chose Off (0), keep Off for all clips
    if [ "${CURVES_PRESET}" = "0" ] || [ "${CURVES_PRESET}" = "off" ]; then
        :
    else
        case "$CLIP_TYPE" in
            GREEN_DOM)
                VFILT="$VFILT,\
curves=r='0/0 0.5/0.49 1/1':\
g='0/0 0.5/0.50 1/1':\
b='0/0 0.5/0.48 1/1',\
hue=h=0:s=0.93"

                ;;
            DARK)
                VFILT="$VFILT,\
curves=all='0/0 0.35/0.40 0.7/0.72 1/1',\
hue=h=0:s=0.98"
                ;;
            NORMAL|*)
                case "${CURVES_PRESET}" in
                    1)
                        VFILT="$VFILT,\
curves=r='0/0 0.5/0.48 1/1':\
g='0/0 0.5/0.44 1/1':\
b='0/0 0.5/0.54 1/1',\
hue=h=0:s=0.95"
                        ;;
                    2)
                        VFILT="$VFILT,\
curves=r='0/0 0.5/0.54 1/1':\
g='0/0 0.5/0.50 1/1':\
b='0/0 0.5/0.46 1/1',\
hue=h=0:s=1.02"
                        ;;
                    3)
                        VFILT="$VFILT,\
curves=all='0/0 0.25/0.18 0.5/0.52 0.75/0.85 1/1',\
hue=h=0:s=0.95,\
eq=contrast=1.05:brightness=-0.02"
                        ;;
                    *)
                        : # Off
                        ;;
                esac
                ;;
        esac
    fi

    VFILT="$VFILT,fps=30,eq=saturation=$SAT_VAL:gamma=$GAMMA_VAL,format=yuv420p"

    if [[ $i -eq 0 ]]; then
        VFILT="$VFILT,fade=t=in:st=0:d=$FADE_DUR"
    fi
    
    if [[ $i -eq $LAST_MAIN_INDEX ]] || [[ $i -eq $((NUM_FILES - 1)) ]]; then
        DUR=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INFILE")
        ST=$(awk -v d="$DUR" -v f="$FADE_DUR" 'BEGIN {printf "%.2f", d-f}')
        VFILT="$VFILT,fade=t=out:st=$ST:d=$FADE_DUR"
    fi

    nice -n 20 ffmpeg -nostdin -hide_banner -loglevel error -threads "$THREADS" -i "$INFILE" \
        -an -vf "$VFILT" -c:v h264_videotoolbox -b:v "$BITRATE" "$OUTCLIP" -y
    
    printf "file '%s'\n" "$OUTCLIP" >> "$CONCAT_LIST"
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

# Build V_FILTER - construct step by step to avoid quoting issues
V_FILTER="[0:v]drawtext=fontfile=${FONT_FILE}:text=${ESC_TEXT1}:fontcolor=white:fontsize=160:x=150:y=H-450:borderw=2:bordercolor=black@0.3:shadowcolor=black@0.6:shadowx=3:shadowy=3:alpha='${ALPHA}',drawtext=fontfile=${FONT_FILE}:text=${ESC_TEXT2}:fontcolor=white@0.95:fontsize=100:x=150:y=H-270:borderw=1:bordercolor=black@0.3:shadowcolor=black@0.3:shadowx=2:shadowy=2:alpha='${ALPHA}',fade=t=in:st=0:d=0.1[vout]"

A_FILTER="[1:a]afade=t=in:st=0:d=$FADE_DUR,afade=t=out:st=$FADE_OUT_ST:d=$FADE_DUR[aout]"

FINAL_VIDEO_PATH="$OUTPUT_DIR/Final_Movie_4K.mp4"

echo "Rendering full video..."
nice -n 20 ffmpeg -hide_banner -stats -y -threads "$THREADS" \
    -i "$CONCAT_VIDEO" \
    -stream_loop -1 -i "$SELECTED_MUSIC" \
    -filter_complex "$V_FILTER;$A_FILTER" \
    -map "[vout]" -map "[aout]" \
    -shortest \
    -c:v h264_videotoolbox -b:v "$BITRATE" \
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
