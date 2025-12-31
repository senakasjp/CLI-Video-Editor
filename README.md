# Video Editing Pipeline (LUT + Assembly)

This folder contains a two-step Bash workflow for preparing camera clips and assembling a 4K cinematic edit. The first script batch-processes footage with lens correction, normalization, and a LUT using FFmpeg. The second script assembles the graded clips into a final movie with titles, music, and optional looks. Run the LUT pass first, then the editor/assembler.

## Scripts

### `LUT_CONVERTER.SH`
Applies lens correction, normalization, and a 3D LUT to all clips in `./clips`, then writes processed files into `./Out_LUTed`.

Key behavior:
- Skips clips shorter than 5 seconds.
- Prompts for approval when a clip is longer than 20 seconds.
- Uses `lenscorrection` + `crop` to reduce fisheye distortion.
- Normalizes exposure before applying `lut.cube`.
- Outputs 10-bit HEVC via `hevc_videotoolbox` at ~15 Mbps.
- Sets `-tag:v hvc1` and `-movflags +faststart` for better player compatibility.
- Pauses 15 seconds between clips to reduce thermal load.

Inputs:
- `./clips` (source video files)
- `./lut.cube` (3D LUT file)

Outputs:
- `./Out_LUTed` (processed clips, same filenames)

### `VIDEO_EDITOR.SH`
Interactive assembler that trims/scales clips to 4K, applies global look adjustments, adds titles, mixes music, and renders the final movie plus a thumbnail.

Key behavior:
- Reads/writes `last.config` for persistent settings.
- Lets you select intro/outro clips and a music track.
- Applies global controls: saturation, gamma, brightness, temperature, yellow cast fix.
- Optional cinematic presets (teal/orange, vintage, sepia, B&W, etc.).
- Generates a 5‑second preview before full render.
- Outputs 10-bit HEVC (preview, intermediates, and final) with QuickTime-friendly tags.
- Outputs a 4K final movie and a YouTube-style thumbnail.

Inputs:
- `./Out_LUTed` (main clips after LUT pass)
- `./First_clip` (optional intro clips)
- `./Last_clip` (optional outro clips)
- `./Music` (audio tracks)
- `./Sk-Modernist.ttf` (title font)

Outputs:
- `./Final_Movie/Final_Movie_4K.mp4`
- `./Final_Movie/SAMPLE_PREVIEW.mp4`
- `./Thumbnail/Thumbnail.jpg`

## Quick Start

1) Prepare clips + LUT
```bash
./LUT_CONVERTER.SH
```

2) Assemble the final movie
```bash
./VIDEO_EDITOR.SH
```

## Requirements

- `ffmpeg` and `ffprobe` (video processing, LUTs, scaling, titles, audio mix)
- `bc` (duration math and conditional checks)
- Apple Silicon recommended for `hevc_videotoolbox` hardware encoding

## Workflow Notes

- This pipeline keeps 10-bit precision through LUT conversion and final assembly to minimize banding.
- Outputs are HEVC in MP4 with `hvc1` tags; QuickTime is more likely to open them without warnings.

## Configuration Notes

- `last.config` stores the previous run’s settings (color, text, music, intro/outro selection).
- `VIDEO_EDITOR.SH` targets 3840x2160, 30 fps, and ~60 Mbps.
- Text overlays are drawn near the bottom-left with a simple fade-in/out alpha ramp.
