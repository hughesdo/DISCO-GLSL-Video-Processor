# Quick Test Guide - Verify Shaders Are Working

## 🔧 Step 1: Restart Server

```bash
# In your terminal, stop the current server
Ctrl+C

# Restart it
startapp.bat
```

Wait for: `INFO:     Uvicorn running on http://0.0.0.0:8000`

## 🌐 Step 2: Refresh Browser

1. Open http://localhost:8000
2. Press `Ctrl+F5` (hard refresh to clear cache)

## ✅ Step 3: Verify Categories Appear

Click on the "Select Shader:" dropdown. You should see:

```
-- Select Shader --
🎵 Audio-Reactive
  [existing shaders...]
🔊 Bass Reactive          ← NEW!
  BassWobbleScreenShake   ← Should appear here!
  PulseVignette
  StrobeFlash
🎨 Visual Effects
  [existing shaders...]
🌈 Color Effects          ← NEW!
  ChromaticAberration
  ColorWaves
  HueRotate
  Posterize
  RGBShift
⚡ Glitch                 ← NEW!
  Datamosh
  DigitalGlitch
✨ Edge Effects           ← NEW!
  EdgeGlow
  EdgeNeon
```

## 🎛️ Step 4: Verify Uniforms Appear

1. Select "BassWobbleScreenShake" from dropdown
2. Scroll down below the shader dropdown
3. You should see:

```
Shader Controls
┌─────────────────────────────────┐
│ shakeIntensity                  │
│ Strength of screen shake effect │
│ [slider] [0.03]                 │
└─────────────────────────────────┘
... (7 more controls)
```

**If you see 8 sliders** ✅ Uniforms are working!

## 🎬 Step 5: Test Audio Reactivity

### Quick Test Setup

1. **Upload files**:
   - Video: Any video (even a static image works)
   - Audio: Music with strong bass (electronic, hip-hop, etc.)

2. **Select shader**: BassWobbleScreenShake

3. **Adjust for maximum visibility**:
   - `bassThreshold`: Set to **0.0** (most sensitive)
   - `shakeIntensity`: Set to **0.1** (very strong)
   - `wobbleIntensity`: Set to **0.15** (very strong)

4. **Process**: Click "Preview" (faster) or "Process Full Video"

### Expected Result

You should see:
- ✅ Screen shaking randomly when bass hits
- ✅ Radial wobble distortion from center
- ✅ RGB chromatic aberration on heavy kicks
- ✅ Effect intensity follows the music rhythm

### If No Effect Visible

Try these extreme settings:
- `bassThreshold`: **0.0**
- `shakeIntensity`: **0.15** (maximum)
- `wobbleIntensity`: **0.2** (maximum)
- `chromaticAberration`: **0.05** (maximum)

## 🧪 Test Each Category

### Bass Reactive Shaders

**BassWobbleScreenShake**
- Effect: Screen shake + wobble
- Test: Should shake on every bass hit
- Adjust: Lower `bassThreshold` if not sensitive enough

**PulseVignette**
- Effect: Edges darken/pulse
- Test: Edges should get darker on bass
- Adjust: Increase `pulseIntensity` for stronger effect

**StrobeFlash**
- Effect: White flashes (⚠️ INTENSE!)
- Test: Should flash white on bass
- Adjust: Lower `strobeThreshold` for more flashes

### Color Effects Shaders

**ChromaticAberration**
- Effect: RGB channel separation
- Test: Should see red/blue edges
- Adjust: Increase `baseOffset` to 0.03

**RGBShift**
- Effect: Wavy RGB separation
- Test: Should see wavy color separation
- Adjust: Increase `baseShift` and `audioShift`

**HueRotate**
- Effect: Colors cycle through spectrum
- Test: Colors should shift over time
- Adjust: Increase `rotationSpeed` to 3.0

**Posterize**
- Effect: Reduced color depth (retro look)
- Test: Should see "banded" colors
- Adjust: Lower `minLevels` to 2.0

**ColorWaves**
- Effect: Animated color waves
- Test: Should see rainbow waves moving
- Adjust: Increase `hueIntensity` to 2.0

### Glitch Shaders

**DigitalGlitch**
- Effect: Scanline displacement
- Test: Should see horizontal glitches
- Adjust: Lower `glitchThreshold` to 0.7

**Datamosh**
- Effect: Compression artifacts
- Test: Should see blocky distortion on bass
- Adjust: Lower `glitchThreshold` to 0.4

### Edge Effects Shaders

**EdgeGlow**
- Effect: Colorful glow on edges
- Test: Edges should glow with rainbow colors
- Adjust: Increase `glowIntensity` to 3.0

**EdgeNeon**
- Effect: Neon outlines (darkens video)
- Test: Should see bright neon edges on dark background
- Adjust: Increase `neonIntensity` to 4.0

## ❌ Troubleshooting

### Shaders Still Don't Appear
- [ ] Did you restart the server?
- [ ] Did you hard refresh browser (Ctrl+F5)?
- [ ] Check browser console (F12) for errors
- [ ] Check server logs for "Found shaders: [...]"

### Uniforms Don't Appear
- [ ] Is the shader selected in dropdown?
- [ ] Scroll down - uniforms appear below shader dropdown
- [ ] Check browser console for JavaScript errors
- [ ] Verify `/shaders/config` endpoint returns shader config

### No Audio Reactivity
- [ ] Lower ALL threshold uniforms to 0.0
- [ ] Increase ALL intensity uniforms to maximum
- [ ] Use audio file with strong bass
- [ ] Check server logs for "Processing audio..."

### Shader Compiles But Shows Black Screen
- [ ] Check server logs for OpenGL errors
- [ ] Try a different shader to verify system works
- [ ] Check if video/audio files are valid

## ✅ Success Criteria

You know everything is working when:

- [x] All 12 new shaders appear in dropdown
- [x] They're organized in 4 new categories with emojis
- [x] Selecting a shader shows "Shader Controls"
- [x] Each shader has the correct number of sliders
- [x] Sliders are adjustable and values update
- [x] Processing video applies the effect
- [x] Audio-reactive shaders respond to music
- [x] Adjusting uniforms changes the visual result

## 🎉 Next Steps

Once everything works:
1. ✅ Report which shaders work best
2. ✅ Report which need default adjustments
3. ✅ Decide on continuing with remaining 36 shaders
4. ✅ Prioritize next categories to integrate

