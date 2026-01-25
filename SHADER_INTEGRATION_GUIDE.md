# Shader Integration Guide - Shadertoy to DISCO Conversion

## Overview
This document outlines the systematic approach for converting shaders from the "New Categorized Video Effects" reference folder into DISCO-compatible shaders.

## Conversion Pattern

### 1. Function Signature Change
**FROM (Shadertoy):**
```glsl
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    ...
}
```

**TO (DISCO):**
```glsl
#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture (if needsAudioTexture: true)
uniform vec2 iResolution;
uniform float iTime;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);  // Flip Y coordinate
    ...
}
```

### 2. Audio Sampling Options

**Option A: Use Audio Texture (Recommended for complex frequency sampling)**
- Set `needsAudioTexture: true` in shader_config.json
- Keep `texture(iChannel1, vec2(frequency, 0.25)).x` calls in shader
- Frequency mapping:
  - 0.02 = Sub-bass/kick (20-60 Hz)
  - 0.05 = Bass (60-250 Hz)
  - 0.15 = Low-mid (250-500 Hz)
  - 0.2 = Mid (500-2000 Hz)
  - 0.4 = High (2000+ Hz)

**Option B: Use Audio Uniforms (Simpler, for basic reactivity)**
- Set `needsAudioTexture: false` in shader_config.json
- Replace audio texture sampling with uniforms:
  - `texture(iChannel1, vec2(0.05, 0.25)).x` → `bassLevel`
  - `texture(iChannel1, vec2(0.2, 0.25)).x` → `midLevel`
  - `texture(iChannel1, vec2(0.4, 0.25)).x` → `trebleLevel`

### 3. Extract Hardcoded Values to Uniforms

**Identify tunable parameters:**
- Effect intensity/strength values
- Speed/frequency multipliers
- Color parameters
- Threshold values

**Example:**
```glsl
// BEFORE (hardcoded):
float ripple = sin(dist * 30.0 - iTime * 5.0) * 0.02;

// AFTER (with uniforms):
uniform float rippleFrequency;  // default: 30.0, range: 10.0-50.0
uniform float rippleSpeed;      // default: 5.0, range: 1.0-10.0
uniform float rippleStrength;   // default: 0.02, range: 0.0-0.1

float ripple = sin(dist * rippleFrequency - iTime * rippleSpeed) * rippleStrength;
```

### 4. Shader Config Entry Template

```json
"ShaderName.glsl": {
  "category": "category-name",
  "description": "Brief description of the effect",
  "audioReactive": true,
  "needsAudioTexture": true,  // or false
  "uniforms": {
    "parameterName": {"value": 1.0, "min": 0.0, "max": 2.0, "step": 0.1}
  },
  "uniformDescriptions": {
    "parameterName": "User-friendly description for UI"
  },
  "audioEffects": ["bassLevel", "midLevel", "trebleLevel"]  // if needsAudioTexture: false
}
```

## Category Mapping

- **01_Color_Effects** → category: "color-effects"
- **02_Distortion_Effects** → category: "distortion"
- **03_Blur_Effects** → category: "blur-effects"
- **04_Geometric_Effects** → category: "geometric"
- **05_Glitch_Effects** → category: "glitch"
- **06_Edge_Effects** → category: "edge-effects"
- **07_Bass_Reactive** → category: "bass-reactive"
- **08_Overlay_Effects** → category: "overlay"

## Integration Checklist

For each shader:
- [ ] Read reference shader from New Categorized Video Effects
- [ ] Convert mainImage() to main() with proper DISCO format
- [ ] Add #version 330 and proper uniforms
- [ ] Flip Y coordinate in UV calculation
- [ ] Decide on audio texture vs audio uniforms
- [ ] Extract hardcoded values to uniforms with sensible defaults
- [ ] Create shader_config.json entry
- [ ] Save converted shader to main Shaders/ directory
- [ ] Test in DISCO system

## Naming Convention

Use descriptive PascalCase names for shader files:
- `s01_chromatic_aberration.glsl` → `ChromaticAberration.glsl`
- `bass_wobble_screen_shake.glsl` → `BassWobbleScreenShake.glsl`
- `color_waves.glsl` → `ColorWaves.glsl`

## Default Value Guidelines

- **Intensity/Strength**: 0.3-0.5 (noticeable but not overpowering)
- **Speed**: 1.0-3.0 (visible animation without being too fast)
- **Frequency**: Match original shader's hardcoded values
- **Audio multipliers**: 0.5-1.0 (moderate audio response)
- **Thresholds**: 0.3-0.5 (trigger on moderate audio levels)

## Total Shaders to Integrate: 48

- 01_Color_Effects: 6 shaders
- 02_Distortion_Effects: 7 shaders
- 03_Blur_Effects: 4 shaders
- 04_Geometric_Effects: 4 shaders
- 05_Glitch_Effects: 3 shaders
- 06_Edge_Effects: 2 shaders
- 07_Bass_Reactive: 3 shaders
- 08_Overlay_Effects: 19 shaders

