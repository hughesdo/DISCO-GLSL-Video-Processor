
# 🎬 DISCO - GLSL Shader Video Processor

> Transform videos into trippy, beat-synced visual experiences using GLSL shaders

---

### First and foremost...

This was an experiment in *vibe coding*.  
All credit for the original shader goes to [ScratchDev on ShaderToy](https://www.shadertoy.com/view/mdcBRl), created on 2023-10-17. I was merely poking around, seeing if layering vibe-driven tweaks could make it more interesting. It was mostly a failed attempt — but sometimes failure teaches us what not to do, and that’s still a step forward.

---

## 🌟 Overview

DISCO is a web-based video processing application that applies GLSL shaders to videos frame-by-frame, creating stunning visual effects. Think "AI-generated video meets MilkDrop with a twist of LSD" — trippy, reactive, and organically synced to the beat.

## ✨ Features

- 🎥 **Video Processing**: Frame-by-frame shader application with OpenGL
- 🎵 **Audio Analysis**: Beat detection and frequency analysis with Librosa
- 🎨 **Multiple Shaders**: Choose from various visual effect styles
- 📊 **Progress Tracking**: Real-time progress bars with detailed status
- 🎬 **Video Player**: Embedded playback with download option
- 🌐 **Web Interface**: User-friendly browser-based UI
- 🔧 **Configurable**: Adjustable shader parameters for fine-tuning

## 🚀 Quick Start

### Prerequisites

- Python 3.8+
- FFmpeg (for video processing)
- Modern web browser
- OpenGL 3.3+ support

### Installation & Launch

**Windows (Recommended):**
```bash
# Simply double-click or run:
startapp.bat
```

**Manual Setup:**
```bash
# Create virtual environment
python -m venv disco_venv
source disco_venv/bin/activate  # Linux/Mac
# or
disco_venv\Scripts\activate     # Windows

# Install dependencies
pip install -r requirements.txt

# Start server
python -m uvicorn main:app --reload --port 8000
```

Open your browser to `http://localhost:8000`

## 🎯 Usage

1. **Upload Files**: Select your video and audio files
2. **Choose Shader**: Pick from available visual effects
3. **Adjust Parameters**: Fine-tune shader uniforms with sliders
4. **Render**: Click "Render Video" and watch the progress
5. **Enjoy**: View your trippy video in the embedded player

## 📁 Project Structure

```
Disco/
├── main.py                    # FastAPI backend server
├── shader_video_processor.py  # Core video processing engine
├── index.html                 # Frontend web interface
├── requirements.txt           # Python dependencies
├── startapp.bat               # Windows startup script
├── Shaders/                   # GLSL shader files
│   ├── After EffectsTik Tok Edit.glsl  # Primary trippy shader
│   ├── DiscoLights.glsl
│   ├── WaveDistortion.glsl
│   ├── ParticleSystem.glsl
│   └── shader_config.json     # Shader configuration
├── Videos/                    # Sample video files
├── Full Music/                # Complete audio tracks
└── Separated/                 # Separated instrument tracks
```

## 🎨 Available Shaders

### 🌈 After Effects TikTok Edit (Primary)
- **Style**: Trippy ray-traced effects with dynamic distortions
- **Features**: Time-based warping, vignette effects, color saturation
- **Best For**: Creating psychedelic music videos

<!-- Future additions -->
<!--
### 💡 Disco Lights
- **Style**: Disco ball lighting effects
- **Features**: Strobe patterns, color rotation, bloom effects
- **Best For**: Dance music and party vibes

### 🌊 Wave Distortion
- **Style**: Wave-based visual distortions
- **Features**: Frequency-based waves, amplitude control
- **Best For**: Electronic music and fluid effects

### ✨ Particle System
- **Style**: Particle-based visual effects
- **Features**: Dynamic particles, explosion forces, energy levels
- **Best For**: High-energy tracks and abstract visuals
-->

## 🔧 Technical Details

### Backend Stack
- **FastAPI**: Modern Python web framework
- **ModernGL**: OpenGL bindings for shader rendering
- **FFmpeg**: Video frame extraction and combination
- **Librosa**: Audio analysis and beat detection
- **PIL**: Image processing and manipulation

### Frontend Stack
- **HTML5**: Responsive web interface
- **JavaScript**: Dynamic UI and progress tracking
- **CSS3**: Dark theme with smooth animations

### Processing Pipeline
1. **Frame Extraction**: FFmpeg breaks video into PNG frames
2. **Shader Rendering**: OpenGL applies effects to each frame
3. **Audio Analysis**: Librosa extracts beat and frequency data
4. **Video Combination**: FFmpeg merges processed frames with audio

## ⚙️ Configuration

### Shader Parameters
Each shader has configurable uniforms:
- **Numeric sliders** for continuous parameters
- **Real-time preview** of values
- **Default values** from `shader_config.json`

### Output Settings
- **Resolution**: 1280x720 (HD)
- **Frame Rate**: 30 FPS
- **Video Codec**: H.264 (CRF 18, high quality)
- **Audio Codec**: AAC

## 🎵 Audio Reactivity

While the current version focuses on core functionality, the foundation is built for audio-reactive effects:
- Beat detection algorithms ready for implementation
- Frequency analysis for bass/mid/treble separation
- Shader uniforms designed for audio input
- Extensible architecture for future enhancements

## 🐛 Troubleshooting

### Common Issues

**FFmpeg not found:**
- Install FFmpeg and add to system PATH
- Windows: Download from https://ffmpeg.org/download.html

**OpenGL errors:**
- Update graphics drivers
- Ensure OpenGL 3.3+ support

**Server won't start:**
- Check if port 8000 is available
- Try different port: `uvicorn main:app --port 8080`

**Video processing fails:**
- Check video format compatibility
- Ensure sufficient disk space for temporary files
- Verify audio file is not corrupted

## 📝 Version Notes

### Current Status: Stable Working Version ✅

**What's Working:**
- ✅ Complete video processing pipeline
- ✅ Web interface with progress tracking
- ✅ Video player with download option
- ✅ Multiple shader support
- ✅ Error handling and logging
- ✅ Automatic temporary file cleanup

**Removed for Simplicity:**
- ❌ Instrument audio effects mapping (was overly complex)
- ❌ Auto-download behavior (replaced with video player)
- ❌ Red-biased color outputs (fixed in shaders)

**Design Philosophy:**
- **Simplicity over complexity**: Clean, focused interface
- **User experience first**: Progress feedback and intuitive controls
- **Reliability**: Robust error handling and graceful fallbacks
- **Extensibility**: Clean architecture for future enhancements

## 🎨 Shader Development

Want to create your own shaders? Check out the existing ones in the `Shaders/` directory:

1. Create a new `.glsl` file
2. Add configuration to `shader_config.json`
3. Use standard uniforms: `iTime`, `iResolution`, `iChannel0`
4. Add custom uniforms for user control

## 🤝 Contributing

This is a working version optimized for creating trippy visual effects. Future enhancements could include:
- Real-time audio reactivity
- Additional shader effects
- Batch processing capabilities
- Advanced audio analysis features

## 📄 License

This project is open source. Feel free to modify and distribute according to your needs.

---

## ⚠️ Minor UI Issue

One small thing: the buttons under the video sometimes display strange placeholder text instead of emojis. Honestly, emojis aren’t necessary here — either replace them with something clean or just remove them. Function matters more than flair.

Examples:
- `Download Video`
- `Process Another Video`

---

**Ready to create some trippy videos? Fire up DISCO and let your creativity flow! 🌈✨**
