# Expected UI Behavior - What You Should See

## When You Open http://localhost:8000

### 1. Shader Dropdown ("Select Shader:")

You should see these **new categories** with new shaders:

```
Select Shader:
├── bass-reactive
│   ├── BassWobbleScreenShake
│   ├── PulseVignette
│   └── StrobeFlash
├── color-effects
│   ├── ChromaticAberration
│   ├── ColorWaves
│   ├── HueRotate
│   ├── Posterize
│   └── RGBShift
├── edge-effects
│   ├── EdgeGlow
│   └── EdgeNeon
├── glitch
│   ├── Datamosh
│   └── DigitalGlitch
└── [existing categories...]
```

### 2. When You Select "BassWobbleScreenShake.glsl"

Below the shader dropdown, you should see:

**Shader Controls** (blue header)

Then a grid of 8 control panels:

```
┌─────────────────────────────────┐
│ shakeIntensity                  │
│ Strength of screen shake effect │
│ [====|--------] 0.03            │
│ [0.03]                          │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ wobbleIntensity                 │
│ Strength of radial wobble...    │
│ [====|--------] 0.05            │
│ [0.05]                          │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ wobbleFrequency                 │
│ Frequency of wobble waves       │
│ [====|--------] 20.0            │
│ [20.0]                          │
└─────────────────────────────────┘

... (5 more controls)
```

Each control has:
- **Label** (uniform name)
- **Description** (gray text explaining what it does)
- **Slider** (horizontal bar you can drag)
- **Number input** (editable value box)

### 3. When You Adjust a Slider

- Slider moves
- Number box updates
- Value display updates
- Changes are saved when you click "Process Full Video"

### 4. When You Process Video

The uniform values you set are sent to the shader:
- Lower `bassThreshold` → more sensitive to bass
- Higher `shakeIntensity` → stronger shake effect
- etc.

## Example: Testing BassWobbleScreenShake

### Step-by-Step

1. **Select shader**: Choose "BassWobbleScreenShake" from dropdown
2. **Verify uniforms appear**: You should see 8 sliders
3. **Adjust for visibility**:
   - Set `bassThreshold` to **0.0** (most sensitive)
   - Set `shakeIntensity` to **0.08** (very noticeable)
   - Set `wobbleIntensity` to **0.1** (maximum)
4. **Upload files**:
   - Video: Any video with motion
   - Audio: Electronic music or hip-hop with strong bass
5. **Process**: Click "Preview" (faster) or "Process Full Video"

### Expected Visual Result

You should see:
- **Screen shaking** randomly when bass hits
- **Radial wobble** emanating from center
- **RGB chromatic aberration** on heavy kicks (red/blue separation)
- Effect intensity follows the bass rhythm

If you see **NO effect**:
- Check server logs for errors
- Try lowering `bassThreshold` to 0.0
- Try increasing `shakeIntensity` to 0.15
- Verify audio file has bass frequencies

## Example: Testing EdgeGlow

### Settings for Visibility

1. Select "EdgeGlow" from dropdown
2. Adjust uniforms:
   - `glowIntensity`: **2.0** (bright glow)
   - `bassColorMult`: **3.0** (strong red on bass)
   - `midColorMult`: **3.0** (strong green on mids)
   - `highColorMult`: **3.0** (strong blue on highs)

### Expected Visual Result

- Edges of objects glow with rainbow colors
- Colors change based on audio frequencies:
  - Bass → Red glow
  - Mids → Green glow
  - Highs → Blue glow
- Glow pulses with the music

## Example: Testing ChromaticAberration

### Settings for Visibility

1. Select "ChromaticAberration" from dropdown
2. Adjust uniforms:
   - `baseOffset`: **0.02** (noticeable separation)
   - `audioIntensity`: **0.05** (strong audio effect)
   - `offsetAngle`: **0.0** (horizontal separation)

### Expected Visual Result

- RGB channels separate (red/green/blue split)
- Separation increases with audio level
- Creates a "lens distortion" or "3D glasses" effect

## If Uniforms DON'T Appear

### Checklist

- [ ] Did you restart the server after adding shaders?
- [ ] Did you hard refresh the browser (Ctrl+F5)?
- [ ] Does the shader appear in the dropdown?
- [ ] Check browser console (F12) for JavaScript errors
- [ ] Check server logs for "Loaded configuration for shader: ..."

### Browser Console Check

Press F12, go to Console tab, look for:
```javascript
// Should see shader config loaded
Object { BassWobbleScreenShake.glsl: {...}, ... }
```

### Network Tab Check

Press F12, go to Network tab:
1. Refresh page
2. Look for request to `/shaders/config`
3. Click on it
4. Check "Response" tab
5. Search for "BassWobbleScreenShake"
6. Should see full config with uniforms

## If Audio Reactivity Doesn't Work

### Common Causes

1. **Threshold too high**: Lower `bassThreshold`, `kickThreshold`, etc. to 0.0-0.2
2. **Intensity too low**: Increase effect intensity uniforms
3. **Audio has no bass**: Try different audio file
4. **Audio not being processed**: Check server logs

### Debug Steps

1. **Test with extreme values**:
   - Set ALL thresholds to 0.0
   - Set ALL intensities to maximum
   - If still no effect → shader or audio processing issue

2. **Check server logs**:
   ```
   INFO: Processing audio...
   INFO: Audio texture created: 512x2
   INFO: Bass level: 0.45, Mid: 0.32, Treble: 0.28
   ```

3. **Try a different shader**:
   - If EdgeGlow works but BassWobbleScreenShake doesn't → shader-specific issue
   - If NO shaders react to audio → audio processing issue

## Success Criteria

You know everything is working when:

✅ All 12 new shaders appear in dropdown under correct categories
✅ Selecting a shader shows "Shader Controls" section
✅ Each shader shows the correct number of uniform sliders
✅ Sliders are adjustable and values update
✅ Processing video applies the shader effect
✅ Audio-reactive shaders respond to music
✅ Adjusting uniforms changes the visual effect

## Next Steps After Successful Testing

Once you confirm everything works:
1. Report which shaders work well
2. Report which need default value adjustments
3. Decide whether to continue integrating remaining 36 shaders
4. Prioritize which categories to integrate next

