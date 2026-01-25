# Testing Checklist for New Shaders

## Issue Summary
- **Problem 1**: BassWobbleScreenShake shows no audio reactivity
- **Problem 2**: Uniforms not appearing in web UI for new shaders

## Troubleshooting Steps

### 1. Restart the Server
The server needs to reload `shader_config.json` to pick up the new shaders and their uniforms.

**Action:**
1. Stop the current server (Ctrl+C in the terminal running startapp.bat)
2. Restart: `startapp.bat`
3. Wait for "Uvicorn running on http://0.0.0.0:8000"
4. Refresh your browser (Ctrl+F5 for hard refresh)

### 2. Verify Shaders Appear in Dropdown
Open http://localhost:8000 and check:
- [ ] "bass-reactive" category exists
- [ ] BassWobbleScreenShake.glsl appears in dropdown
- [ ] PulseVignette.glsl appears in dropdown
- [ ] StrobeFlash.glsl appears in dropdown
- [ ] "color-effects" category has 5 new shaders
- [ ] "glitch" category has 2 new shaders
- [ ] "edge-effects" category has 2 new shaders

### 3. Verify Uniforms Appear
Select "BassWobbleScreenShake.glsl" from dropdown:
- [ ] "Shader Controls" section appears below shader dropdown
- [ ] You see 8 sliders with labels:
  - shakeIntensity
  - wobbleIntensity
  - wobbleFrequency
  - wobbleSpeed
  - chromaticAberration
  - bassThreshold
  - kickThreshold
  - shakeUpdateRate

### 4. Test Audio Reactivity

**Test Setup:**
1. Upload a test video (any video with motion)
2. Upload audio with strong bass (electronic music, hip-hop, etc.)
3. Select "BassWobbleScreenShake.glsl"
4. **IMPORTANT**: Lower the `bassThreshold` slider to 0.1 (or even 0.0)
5. Increase `shakeIntensity` to 0.05 or higher
6. Click "Process Full Video" or "Preview"

**Expected Results:**
- Screen should shake/wobble when bass hits
- The shake should be random direction
- Radial wobble should emanate from center
- On heavy kicks, you should see RGB chromatic aberration

### 5. If Uniforms Still Don't Appear

**Check Browser Console:**
1. Press F12 to open developer tools
2. Go to "Console" tab
3. Look for JavaScript errors
4. Check "Network" tab - verify `/shaders/config` returns JSON with new shaders

**Check Server Logs:**
Look in terminal for:
```
INFO:     Found shaders: [..., 'BassWobbleScreenShake.glsl', ...]
INFO:     Loaded configuration for shader: BassWobbleScreenShake.glsl
```

### 6. Test Each Shader Category

**Bass Reactive (should be VERY noticeable):**
- [ ] BassWobbleScreenShake - screen shakes on bass
- [ ] PulseVignette - edges darken/pulse on bass
- [ ] StrobeFlash - white flashes on bass (WARNING: intense!)

**Color Effects (should affect colors):**
- [ ] ChromaticAberration - RGB channels separate
- [ ] RGBShift - wavy RGB separation
- [ ] HueRotate - colors cycle through spectrum
- [ ] Posterize - reduced color depth (retro look)
- [ ] ColorWaves - animated color waves overlay

**Glitch (should glitch on audio):**
- [ ] DigitalGlitch - scanline displacement
- [ ] Datamosh - compression artifacts

**Edge Effects (should highlight edges):**
- [ ] EdgeGlow - colorful glow on edges
- [ ] EdgeNeon - neon outlines (darkens video)

## Common Issues & Fixes

### Issue: "No audio reactivity"
**Cause**: bassThreshold too high or audio file has no bass
**Fix**: 
- Lower `bassThreshold` to 0.0-0.2
- Increase effect intensity uniforms
- Use audio with strong bass frequencies

### Issue: "Uniforms not showing"
**Cause**: Server hasn't reloaded config
**Fix**:
- Restart server completely
- Hard refresh browser (Ctrl+F5)
- Check browser console for errors

### Issue: "Effect too subtle"
**Cause**: Default values too conservative
**Fix**: Increase intensity uniforms:
- BassWobbleScreenShake: increase shakeIntensity to 0.08
- PulseVignette: increase pulseIntensity to 3.0
- EdgeGlow: increase glowIntensity to 2.0

### Issue: "Shader compiles but shows black screen"
**Cause**: Shader error or missing texture
**Fix**: Check server logs for OpenGL errors

## Current Default Values (Updated for Sensitivity)

### BassWobbleScreenShake.glsl
- shakeIntensity: 0.03 (was 0.02)
- wobbleIntensity: 0.05 (was 0.03)
- bassThreshold: 0.1 (was 0.3) ← **More sensitive now**
- kickThreshold: 0.3 (was 0.5) ← **More sensitive now**

### PulseVignette.glsl
- flashThreshold: 0.6 (was 0.8) ← **More sensitive now**

### StrobeFlash.glsl
- strobeThreshold: 0.5 (was 0.6) ← **More sensitive now**

## Next Steps After Testing

Once you confirm:
1. ✅ Uniforms appear in UI
2. ✅ Audio reactivity works
3. ✅ Effects are visually noticeable

Then we can:
- Continue integrating remaining 36 shaders
- Fine-tune default values based on your feedback
- Add more categories (Distortion, Blur, Geometric, Overlay)

