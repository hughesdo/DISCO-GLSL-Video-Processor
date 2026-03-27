
# DISCO - GLSL Shader Video Processor

> Transform videos into trippy, beat-synced visual experiences using GLSL shaders

---

### First and foremost...

This was an experiment in *vibe coding*.
Most credit for the original shaders goes to [ShaderToy](https://www.shadertoy.com/). I was merely poking around, seeing if layering vibe-driven tweaks could make it more interesting. Also see `attributions.txt` for other GLSL shaders that I either outright used or borrowed from. I'm trying now to keep `attributions.txt` in the root because AI tends to remove comments in code as it sees fit.

[![Watch the video](https://img.youtube.com/vi/zvIya7i-uOA/0.jpg)](https://www.youtube.com/watch?v=zvIya7i-uOA)

---

## Development & Attribution

This project was an experiment in "vibe coding" conducted in collaboration with [Augment Code](https://www.augmentcode.com/) and later [Claude Code](https://claude.ai/). The work involved both expanding existing GLSL shaders from the community and creating original new shader effects. It grew from a simple shader experiment into a comprehensive video processing application with 90 visual effects and audio-reactive capabilities.

During the AI-assisted development process, attribution comments were sometimes inadvertently removed from GLSL files. Approximately 2-3 hours were spent manually restoring proper credits. All known attributions are documented in `attributions.txt`.

If any attributions were missed, please reach out: [@OneHung](https://twitter.com/OneHung) on Twitter/X

---

## Overview

DISCO is a web-based video processing application that applies GLSL shaders to videos frame-by-frame, creating stunning visual effects. Think "AI-generated video meets MilkDrop with a twist of LSD" -- trippy, reactive, and organically synced to the beat.

## Features

- **Video Processing** - Frame-by-frame shader application with OpenGL
- **Audio Analysis** - Beat detection and frequency analysis with Librosa
- **90 GLSL Shaders** - Massive collection across multiple categories
- **Audio-Reactive** - Two modes: audio texture sampling and bass/mid/treble uniforms
- **300+ Configurable Parameters** - Real-time sliders for every shader uniform
- **Web Interface** - Browser-based UI with live preview and shader controls
- **Progress Tracking** - Real-time progress bars during rendering
- **Video Player** - Embedded playback with download option

## Quick Start

### Prerequisites

- **Python 3.8+** - [python.org](https://www.python.org/) (check "Add Python to PATH" during install)
- **FFmpeg** - [ffmpeg.org](https://ffmpeg.org/download.html) (must be in system PATH)
- **Modern web browser**
- **OpenGL 3.3+** support (most modern GPUs)

### Installation

**Option 1 - Run the installer:**
```
install.bat
```
This checks all prerequisites and installs Python packages into a virtual environment.

**Option 2 - Manual setup:**
```
python -m venv disco_venv
disco_venv\Scripts\activate
pip install -r requirements.txt
```

See `install.txt` for detailed step-by-step instructions.

### Launch

```
startapp.bat
```

This activates the virtual environment, starts the server, and opens your browser to `http://localhost:8000`.

## Usage

1. **Upload** your video and audio files
2. **Choose** a shader from the categorized dropdown
3. **Adjust** parameters with the real-time sliders
4. **Render** and watch the progress bar
5. **Download** your processed video

## Shader Categories

| Category | Description |
|---|---|
| Audio-Reactive | Beat-synced effects (BeatDropShake, BeatFlash, EasyBeats, etc.) |
| Bass Reactive | Bass-driven distortions and wobbles |
| Visual Effects | General visual transformations |
| Color Effects | Color cycling, hue rotation, posterize, etc. |
| Distortion | Barrel distortion, heat haze, liquid effects |
| Blur Effects | Radial blur, zoom blur, directional blur |
| Geometric | Kaleidoscope, hexagons, spirals, mirrors |
| Glitch | Digital glitch, datamosh, VHS tape |
| Edge Effects | Edge glow, neon outlines |
| Overlay | Grid, matrix rain, particles, starfields |
| 3D Effects | Raymarched scenes, chrome spheres, energy tunnels |

## Project Structure

```
Disco/
├── install.bat                  # Installer - checks prereqs, installs packages
├── install.txt                  # Plain-text installation instructions
├── startapp.bat                 # Launches the application
├── main.py                      # FastAPI backend server
├── shader_video_processor.py    # Core video processing engine
├── streaming_video_processor.py # Streaming video processor
├── index.html                   # Web interface
├── requirements.txt             # Python dependencies
├── attributions.txt             # Shader credits and attributions
├── README.md                    # This file
├── Shaders/                     # 90 GLSL shader files + config
│   └── shader_config.json       # Shader parameters and categories
├── Textures/                    # Texture assets used by shaders
├── Outputs/                     # Rendered output videos (local only)
├── Videos/                      # Input video/audio files (local only)
└── Separated/                   # Separated instrument tracks (local only)
```

## Technical Stack

**Backend:** FastAPI, ModernGL (OpenGL), FFmpeg, Librosa, NumPy, Pillow, OpenCV

**Frontend:** HTML5, JavaScript, CSS3 (dark theme)

**Processing pipeline:** FFmpeg extracts frames -> OpenGL applies shaders -> Librosa analyzes audio -> FFmpeg reassembles video with audio

## Audio Reactivity

Shaders can react to audio in two ways:

**Audio Texture mode** - Shaders sample a frequency texture (`iChannel1`) for precise frequency data at any point in the spectrum.

**Audio Uniform mode** - Shaders receive `bassLevel`, `midLevel`, and `trebleLevel` uniforms that update per-frame based on the audio analysis.

## Troubleshooting

| Problem | Solution |
|---|---|
| FFmpeg not found | Install FFmpeg and add its `bin` folder to system PATH |
| OpenGL errors | Update graphics drivers; need OpenGL 3.3+ |
| Server won't start | Check if port 8000 is in use; try `uvicorn main:app --port 8080` |
| Video processing fails | Check video format, disk space, and that audio file isn't corrupted |
| Shader not in dropdown | Verify its category in `shader_config.json` matches a category in `index.html` |

## Shader Development

To add your own shader, see `CLAUDE.md` for the full integration guide. The short version:

1. Create a `.glsl` file in `Shaders/` using `#version 330`, `in vec2 v_text`, `out vec4 fragColor`
2. Add an entry to `Shaders/shader_config.json` with category, uniforms, and descriptions
3. Restart the server and hard-refresh the browser

## License

This project is open source. Feel free to modify and distribute according to your needs.

---

**Ready to create some trippy videos? Fire up DISCO and let your creativity flow!**
