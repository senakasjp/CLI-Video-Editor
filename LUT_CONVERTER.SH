#!/bin/bash

# Create output directories
mkdir -p ./Out_LUTed

# Path to your LUT
LUT="./lut.cube"

# --- LENS CORRECTION SETTINGS ---
# For Action Cams (Fisheye removal):
# Try values between 0.1 and 0.3. 
# 0.0 = No correction
# 0.1 = Subtle correction
# 0.2 = Stronger correction (Common for DJI/GoPro)
CX="0.18"
CY="0.18"
CROP_VAL="iw*0.86:ih*0.86"

# Verify LUT exists
if [ ! -f "$LUT" ]; then
    echo "ERROR: LUT file not found at $LUT"
    exit 1
fi

# 1. Loop through files
ls -tr ./clips/*.{mp4,MP4,mov,MOV,mkv,m4v} 2>/dev/null | while read -r file; do
    
    filename=$(basename "$file")
    
    # --- DURATION CHECK ---
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")
    
    if (( $(echo "$duration < 5" | bc -l) )); then
        echo "SKIPPING: $filename (Too short: ${duration}s)"
        continue
    fi

    out_once="./Out_LUTed/$filename"
    temp_file_once="./Out_LUTed/$filename.tmp"

    echo "PROCESSING: $filename (Correction + Normalize + LUT)"

    # --- PROCESSING PASS ---
    if [ ! -f "$out_once" ]; then
        # 1. lenscorrection: Straightens the fisheye distortion
        # 2. crop: Zoom in slightly to remove stretched corners
        # 3. normalize: Equalizes brightness levels before the LUT
        # 4. lut3d: Apply your color grade
        # 5. format: Ensure compatibility with standard players
        nice -n 20 ffmpeg -y -nostdin -i "$file" \
        -vf "lenscorrection=cx=$CX:cy=$CY,crop=$CROP_VAL,normalize=smoothing=30:independence=0,lut3d=file='$LUT':interp=tetrahedral,format=yuv420p" \
        -map_metadata 0 -c:v h264_videotoolbox -b:v 15M -c:a copy -f mp4 "$temp_file_once"
        
        if [ $? -eq 0 ]; then
            mv "$temp_file_once" "$out_once"
            touch -r "$file" "$out_once"
            echo "SUCCESS: $filename"
        else
            echo "ERROR: Failed processing $filename"
            rm -f "$temp_file_once"
        fi
    fi

    # --- THERMAL PAUSE ---
    echo "Pausing for 15 seconds to manage heat..."
    sleep 15

done

echo "------------------------------------------------------"
echo "Done! Lens corrected, Normalized, and LUT applied."
