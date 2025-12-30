#!/bin/bash

# --- CONFIGURATION ---
STABILITY_THRESHOLD=4.0  # Lower = more strict
LUT="./lut.cube"
CLIPS_DIR="./clips"

# Check for LUT
if [ ! -f "$LUT" ]; then
    echo "ERROR: LUT file not found at $LUT"
    exit 1
fi

# 1. Loop through files in the clips folder
ls -tr "$CLIPS_DIR"/*.{mp4,MP4,mov,MOV,mkv,m4v} 2>/dev/null | while read -r file; do
    
    filename=$(basename "$file")
    trf_file="${file}.trf"
    temp_out="${file}.processed.mp4"
    
    echo "------------------------------------------------"
    echo "ANALYZING MOTION: $filename"

    # STEP 1: Generate motion log (.trf)
    # This identifies every shake and jolt in the video
    ffmpeg -y -i "$file" -vf "vidstabdetect=shakiness=10:result=$trf_file" -f null - 2>/dev/null

    # STEP 2: Find the stable "Video" section
    # Uses awk to find the first and last frames where movement is below threshold
    first_stable_frame=$(awk -v limit="$STABILITY_THRESHOLD" 'NR>2 {abs_x=($2<0?$2*-1:$2); abs_y=($3<0?$3*-1:$3); if(abs_x < limit && abs_y < limit) {print NR-3; exit}}' "$trf_file")
    last_stable_frame=$(awk -v limit="$STABILITY_THRESHOLD" 'NR>2 {abs_x=($2<0?$2*-1:$2); abs_y=($3<0?$3*-1:$3); if(abs_x < limit && abs_y < limit) last=NR-3} END {print last}' "$trf_file")

    # Get FPS to convert frames to timestamps
    fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 "$file" | bc -l)
    
    # Calculate start and duration
    start_time=$(echo "scale=3; $first_stable_frame / $fps" | bc -l)
    end_time=$(echo "scale=3; $last_stable_frame / $fps" | bc -l)
    new_duration=$(echo "scale=3; $end_time - $start_time" | bc -l)

    # STEP 3: Process the clip if it's long enough
    if (( $(echo "$new_duration > 1" | bc -l) )); then
        echo "STABLE SECTION FOUND: ${start_time}s to ${end_time}s"
        echo "APPLYING LUT & TRIMMING..."

        nice -n 20 ffmpeg -y -nostdin -ss "$start_time" -i "$file" \
        -t "$new_duration" \
        -vf "lut3d=file='$LUT':interp=tetrahedral,format=yuv420p" \
        -c:v h264_videotoolbox -b:v 15M -c:a copy "$temp_out"

        if [ $? -eq 0 ]; then
            # Replace the original file with the processed version
            mv "$temp_out" "$file"
            echo "SUCCESS: $filename updated in place."
        else
            echo "ERROR: Processing failed for $filename"
            rm -f "$temp_out"
        fi
    else
        echo "SKIPPING: $filename (Motion too chaotic to find a stable middle)"
    fi

    # Cleanup temporary motion file
    rm -f "$trf_file"

    echo "Heat Management Pause (5s)..."
    sleep 5
done

echo "------------------------------------------------"
echo "All clips in ./clips have been processed and trimmed."