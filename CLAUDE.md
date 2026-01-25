# CLAUDE.md - Guide for Integrating New Shaders into DISCO

## 🎯 Purpose
This document contains critical knowledge for integrating new GLSL shaders into the DISCO video processing system. Read this EVERY time before adding new shaders to avoid common pitfalls.

## 📋 Integration Checklist

When adding a new shader, you MUST touch these files in this order:

1. ✅ Create `.glsl` file in `Shaders/` directory
2. ✅ Add configuration to `Shaders/shader_config.json`
3. ✅ Verify category exists in `index.html` (or add it)
4. ✅ Test in web UI after server restart

## 🔧 Touch Points - Critical Files

### 1. `Shaders/YourShader.glsl` - The Shader File

**Required Format:**
```glsl
#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input (ALWAYS present)
uniform sampler2D iChannel1;  // Audio texture (if needsAudioTexture: true)
uniform vec2 iResolution;
uniform float iTime;

// Your custom uniforms
uniform float yourUniform;

void main() {
    // CRITICAL: Y-flip required for DISCO
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video input
    vec4 video = texture(iChannel0, uv);
    
    // Your shader logic here
    
    fragColor = video;
}
```

**Key Points:**
- ✅ MUST use `#version 330`
- ✅ MUST use `in vec2 v_text` (not `fragCoord`)
- ✅ MUST use `out vec4 fragColor` (not `void mainImage(...)`)
- ✅ MUST flip Y coordinate: `vec2(v_text.x, 1.0 - v_text.y)`
- ✅ iChannel0 is ALWAYS the video input
- ✅ iChannel1 is audio texture (only if `needsAudioTexture: true`)

### 2. `Shaders/shader_config.json` - Shader Configuration

**Required Entry:**
```json
"YourShader.glsl": {
  "category": "category-name",
  "description": "Brief description for UI tooltip",
  "audioReactive": true,
  "needsAudioTexture": true,
  "uniforms": {
    "yourUniform": {"value": 1.0, "min": 0.0, "max": 2.0, "step": 0.1}
  },
  "uniformDescriptions": {
    "yourUniform": "Human-readable description for UI"
  }
}
```

**Key Points:**
- ✅ Filename MUST match exactly (case-sensitive, include `.glsl`)
- ✅ Category MUST exist in `index.html` categories list
- ✅ Every uniform in GLSL MUST have entry in `uniforms` object
- ✅ Every uniform SHOULD have description in `uniformDescriptions`
- ✅ Set `needsAudioTexture: true` if shader uses `texture(iChannel1, ...)`
- ✅ Set `needsAudioTexture: false` if shader uses `bassLevel`, `midLevel`, `trebleLevel` uniforms

### 3. `index.html` - Web UI Categories

**Location:** Line ~344-358

**Current Categories:**
```javascript
const categories = {
  'audio-reactive': '🎵 Audio-Reactive',
  'bass-reactive': '🔊 Bass Reactive',
  'visual-effects': '🎨 Visual Effects',
  'color-effects': '🌈 Color Effects',
  'distortion': '🌀 Distortion',
  'blur-effects': '💫 Blur Effects',
  'geometric': '📐 Geometric',
  'glitch': '⚡ Glitch',
  'edge-effects': '✨ Edge Effects',
  'overlay': '🎭 Overlay',
  '3d-effects': '🚀 3D Effects',
  'other': '📁 Other'
};
```

**CRITICAL:** If your shader uses a category NOT in this list, it will NOT appear in the dropdown!

**To Add New Category:**
1. Edit `index.html` around line 344
2. Add new entry to `categories` object
3. Use format: `'category-key': '🎨 Display Name'`
4. Restart server and hard refresh browser (Ctrl+F5)

## 🎨 Audio Reactivity - Two Modes

### Mode 1: Audio Texture (needsAudioTexture: true)

**Use when:** Shader needs frequency-specific data

**In GLSL:**
```glsl
uniform sampler2D iChannel1;  // Audio texture

void main() {
    // Sample specific frequencies
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    float kick = texture(iChannel1, vec2(0.02, 0.25)).x;
    float mid = texture(iChannel1, vec2(0.2, 0.25)).x;
    float high = texture(iChannel1, vec2(0.4, 0.25)).x;
}
```

**Frequency Map:**
- `0.02` = Kick drum (sub-bass)
- `0.05` = Bass
- `0.15` = Low-mid
- `0.2` = Mid
- `0.4` = High/treble

**In shader_config.json:**
```json
"needsAudioTexture": true
```

### Mode 2: Audio Uniforms (needsAudioTexture: false)

**Use when:** Shader only needs general audio levels

**In GLSL:**
```glsl
uniform float bassLevel;    // Auto-updated by DISCO
uniform float midLevel;     // Auto-updated by DISCO
uniform float trebleLevel;  // Auto-updated by DISCO

void main() {
    float intensity = bassLevel * 2.0;
}
```

**In shader_config.json:**
```json
"needsAudioTexture": false,
"audioEffects": ["bassLevel", "midLevel", "trebleLevel"]
```

## 🔄 Conversion Pattern: Shadertoy → DISCO

### Shadertoy Format:
```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec4 video = texture(iChannel0, uv);
    fragColor = video;
}
```

### DISCO Format:
```glsl
#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;
uniform vec2 iResolution;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);  // Y-flip!
    vec4 video = texture(iChannel0, uv);
    fragColor = video;
}
```

**Changes Required:**
1. Add `#version 330` at top
2. Change `void mainImage(...)` → `void main()`
3. Change `in vec2 fragCoord` → `in vec2 v_text`
4. Change `out vec4 fragColor` → declare as global
5. Replace `fragCoord / iResolution.xy` → `vec2(v_text.x, 1.0 - v_text.y)`
6. Add all `uniform` declarations at top

## 💡 Uniform Exposure Best Practices

**DO:**
- ✅ Extract ALL hardcoded magic numbers to uniforms
- ✅ Provide sensible defaults that look good immediately
- ✅ Set min/max ranges that prevent broken visuals
- ✅ Use step sizes appropriate for the value (0.001 for small, 1.0 for large)
- ✅ Write clear descriptions explaining what each uniform does
- ✅ Include threshold uniforms for audio-reactive effects

**DON'T:**
- ❌ Leave hardcoded values in shader code
- ❌ Use extreme defaults that require adjustment
- ❌ Allow ranges that break the effect (e.g., divide by zero)
- ❌ Use generic names like `param1`, `value2`
- ❌ Forget to add uniformDescriptions

**Example - Good Uniform Design:**
```json
"shakeIntensity": {
  "value": 0.03,           // Visible but not overwhelming
  "min": 0.0,              // Off
  "max": 0.15,             // Maximum before too chaotic
  "step": 0.005            // Fine control
},
"bassThreshold": {
  "value": 0.1,            // Sensitive enough for most music
  "min": 0.0,              // Most sensitive
  "max": 0.8,              // Least sensitive
  "step": 0.05             // Reasonable increments
}
```

## 🐛 Common Pitfalls & Solutions

### Problem: Shader doesn't appear in dropdown
**Cause:** Category in `shader_config.json` doesn't exist in `index.html`
**Solution:** Add category to `index.html` categories object (line ~344)

### Problem: Uniforms don't appear in UI
**Cause:** Shader not selected, or JavaScript error
**Solution:** Check browser console (F12), verify shader is selected

### Problem: No audio reactivity
**Cause:** Thresholds too high, or wrong audio mode
**Solution:** Lower threshold uniforms to 0.0-0.2 range, verify `needsAudioTexture` setting

### Problem: Shader compiles but shows black screen
**Cause:** Missing Y-flip, or wrong texture sampling
**Solution:** Verify `vec2(v_text.x, 1.0 - v_text.y)` is used

### Problem: Colors look inverted/wrong
**Cause:** Y-coordinate not flipped
**Solution:** Always use `1.0 - v_text.y` for Y coordinate

### Problem: Effect too subtle or too strong
**Cause:** Poor default uniform values
**Solution:** Adjust `value` in shader_config.json, test with real content

## 📁 Category Mapping Reference

Reference folder → DISCO category:
- `01_Color_Effects` → `"color-effects"`
- `02_Distortion_Effects` → `"distortion"`
- `03_Blur_Effects` → `"blur-effects"`
- `04_Geometric_Effects` → `"geometric"`
- `05_Glitch_Effects` → `"glitch"`
- `06_Edge_Effects` → `"edge-effects"`
- `07_Bass_Reactive` → `"bass-reactive"`
- `08_Overlay_Effects` → `"overlay"`

## 🧪 Testing Workflow

After adding a shader:

1. **Restart server:** `Ctrl+C` then `startapp.bat`
2. **Hard refresh browser:** `Ctrl+F5` on http://localhost:8000
3. **Check dropdown:** Verify shader appears in correct category
4. **Check uniforms:** Select shader, verify controls appear
5. **Test with video:** Upload test video + audio
6. **Adjust defaults:** If effect too weak/strong, update shader_config.json
7. **Repeat:** Restart server, test again

## 📊 Progress Tracking

**Completed:** 48/48 shaders (100%) ✅

**Integrated Categories:**
- ✅ Bass Reactive: 3/3 (100%)
- ✅ Color Effects: 6/6 (100%)
- ✅ Glitch: 3/3 (100%)
- ✅ Edge Effects: 2/2 (100%)
- ✅ Distortion: 7/7 (100%)
- ✅ Blur Effects: 4/4 (100%)
- ✅ Geometric: 4/4 (100%)
- ✅ Overlay: 19/19 (100%)

**ALL SHADERS INTEGRATED!** 🎉

## 🎓 Lessons Learned

1. **Always check category exists in index.html FIRST** - This was the root cause of shaders not appearing
2. **Y-flip is non-negotiable** - DISCO requires `1.0 - v_text.y`
3. **Audio thresholds should be low** - 0.1-0.3 range works better than 0.5-0.8
4. **Test immediately after each shader** - Don't batch too many before testing
5. **Uniforms are mandatory** - Every tweakable value must be exposed
6. **Descriptions matter** - Users need to understand what each control does

## 🚀 Quick Reference Commands

```bash
# Restart server
Ctrl+C
startapp.bat

# Hard refresh browser
Ctrl+F5

# Check server logs
# Look for: "Found shaders: [...]"
# Look for: "Shader compilation error: ..."
```

## 📝 File Locations Quick Reference

- Shader files: `./Shaders/*.glsl`
- Configuration: `./Shaders/shader_config.json`
- Web UI: `./index.html` (line ~344 for categories)
- Reference shaders: `./Shaders/New Categorized Video Effects/`
- Server: `./main.py`
- Processor: `./shader_video_processor.py`, `./streaming_video_processor.py`

---

**Remember:** When in doubt, check this file first! It contains everything learned through trial and error.

