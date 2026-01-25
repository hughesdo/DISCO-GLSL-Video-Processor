#version 330

// ============================================
// Psychedelic Trails - Converted from Shadertoy multi-buffer shader
// Original: A6 - My Trails1 (BufferA + BufferB + Image)
// 
// DISCO CHANNEL MAPPING:
//   iChannel0 = Video input (was BufferA's iChannel0)
//   iChannel1 = Feedback buffer (replaces BufferB's self-feedback on iChannel0)
//
// ORIGINAL SHADERTOY WIRING:
//   BufferA: iChannel0=Video, iChannel1=BufferB (unused)
//   BufferB: iChannel0=BufferB(self), iChannel1=BufferA, iChannel2=Audio
//   Image:   iChannel0=BufferA, iChannel1=BufferB -> max(video, tracer)
// ============================================

uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;    // Video input
uniform sampler2D iChannel1;    // Feedback buffer (previous frame output)
uniform int iFrame;

// Audio uniforms (DISCO system - replaces iChannel2 audio texture)
uniform float bassLevel;
uniform float midLevel;
uniform float trebleLevel;

// User-adjustable parameters (originally #defines)
uniform float trailLength;      // 0.0 = no trails, 0.96 = very long trails
uniform float colorSpeed;       // How fast colors cycle
uniform float colorSpread;      // How much color varies by position
uniform float effectIntensity;  // Brightness of new tracer pixels
uniform float saturation;       // Color saturation

// Audio reactivity strengths
uniform float bassBrightness;   // How much bass boosts brightness
uniform float bassHueShift;     // How much bass shifts colors
uniform float highSaturation;   // How much highs boost saturation

in vec2 v_text;
out vec4 fragColor;

// HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main()
{
    // DISCO coordinate system - flip Y
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Pixel offset for edge detection (scaled for resolution)
    vec2 px = 1.5 / iResolution.xy;
    
    // ===== AUDIO VALUES (from DISCO uniforms instead of texture) =====
    float bass = bassLevel;
    float mid = midLevel;
    float high = trebleLevel;
    
    // Apply defaults if uniforms not set
    float decay = trailLength > 0.01 ? trailLength : 0.96;
    float colSpeed = colorSpeed > 0.001 ? colorSpeed : 0.15;
    float colSpread = colorSpread > 0.001 ? colorSpread : 0.3;
    float intensity = effectIntensity > 0.001 ? effectIntensity : 0.275;
    float sat = saturation > 0.01 ? saturation : 0.9;
    float bassBright = bassBrightness > 0.001 ? bassBrightness : 0.4;
    float bassHue = bassHueShift > 0.001 ? bassHueShift : 0.5;
    float highSat = highSaturation > 0.001 ? highSaturation : 0.3;
    
    // ===== SAMPLE VIDEO (equivalent to BufferA output) =====
    vec4 video = texture(iChannel0, uv);
    
    // ===== EDGE DETECTION on video =====
    vec4 tx = video;
    float dist = distance(tx, texture(iChannel0, uv + px));
    px.y *= -1.0;
    dist += distance(tx, texture(iChannel0, uv + px));
    px.x *= -1.0;
    dist += distance(tx, texture(iChannel0, uv + px));
    px.y *= -1.0;
    dist += distance(tx, texture(iChannel0, uv + px));
    
    // ===== TRANSFORM (slight rotation/scale for swirl effect) =====
    vec2 feedbackUV = uv;
    feedbackUV *= mat2(0.99, 0.01, -0.001, 0.99);
    
    // ===== FEEDBACK WITH DECAY (from iChannel1 = previous frame) =====
    vec4 feedback = texture(iChannel1, feedbackUV + 0.002);
    feedback.rgb *= decay;
    
    // ===== PSYCHEDELIC COLORS =====
    // Rainbow hue cycling with audio modulation
    float hue = fract(iTime * colSpeed + uv.y * colSpread + bass * bassHue);
    
    // Intensity from edge detection
    float edgeIntensity = smoothstep(0.3, 0.8, dist) + smoothstep(0.3, 1.4, dist);
    
    // Audio modulates brightness
    float val = edgeIntensity * (1.0 + bass * bassBright);
    
    // Saturation with audio boost from highs
    float finalSat = sat + high * highSat;
    
    vec3 trippyColor = hsv2rgb(vec3(hue, finalSat, val));
    
    // ===== COMBINE: feedback trails + new tracer pixels =====
    vec3 tracer = feedback.rgb + trippyColor * intensity;
    tracer = clamp(tracer, 0.0, 1.0);
    
    // ===== FINAL COMPOSITE: max(video, tracer) =====
    // This was the Image shader's job - compositing BufferA and BufferB
    vec3 result = max(video.rgb, tracer + 0.002);
    
    fragColor = vec4(result, 1.0);
}

