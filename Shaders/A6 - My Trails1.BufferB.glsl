// ============================================
// BUFFER B - Psychedelic Tracer Effect (AUDIO REACTIVE)
// ============================================
// CHANNEL SETUP:
//   iChannel0 = Buffer B (self-feedback for trail effect)
//   iChannel1 = Buffer A (video input)
//   iChannel2 = Audio input (for audio reactivity)
// ============================================

// ========== TWEAKING VARIABLES ==========
// Adjust these to customize the effect!

#define TRAIL_LENGTH      0.96   // 0.0 = no trails, 0.95 = very long trails (keep < 1.0!)
#define COLOR_SPEED       0.15   // How fast colors cycle (0.05 = slow, 0.5 = fast)
#define COLOR_SPREAD      0.3    // How much color varies by position (0 = uniform, 1 = rainbow gradient)
#define EFFECT_INTENSITY  0.275  // Brightness of new tracer pixels (original = 0.175)
#define SATURATION        0.9    // Color saturation (0 = grayscale, 1 = vivid)

// Audio reactivity strengths
#define BASS_BRIGHTNESS   0.4    // How much bass boosts brightness (0 = off)
#define BASS_HUE_SHIFT    0.5    // How much bass shifts colors (0 = off)
#define HIGH_SATURATION   0.3    // How much highs boost saturation (0 = off)

// =========================================

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 px = 1.5 / vec2(640.0, 360.0);
    vec2 uv = fragCoord.xy / iResolution.xy;

    // ===== AUDIO REACTIVITY =====
    float bass = texture(iChannel2, vec2(0.05, 0.0)).x;
    float mid = texture(iChannel2, vec2(0.3, 0.0)).x;
    float high = texture(iChannel2, vec2(0.7, 0.0)).x;

    // ===== ORIGINAL EDGE DETECTION (unchanged) =====
    vec4 tx = texture(iChannel1, uv);
    float dist = distance(tx, texture(iChannel1, uv + px));
    px.y *= -1.0;
    dist += distance(tx, texture(iChannel1, uv + px));
    px.x *= -1.0;
    dist += distance(tx, texture(iChannel1, uv + px));
    px.y *= -1.0;
    dist += distance(tx, texture(iChannel1, uv + px));

    // ===== ORIGINAL TRANSFORM (unchanged) =====
    uv *= mat2(0.99, 0.01, -0.001, 0.99);

    // ===== FEEDBACK WITH DECAY =====
    vec4 feedback = texture(iChannel0, uv + 0.002);
    feedback.rgb *= TRAIL_LENGTH;

    // ===== PSYCHEDELIC COLORS =====
    float time = iTime;

    // Rainbow hue cycling
    float hue = fract(time * COLOR_SPEED + uv.y * COLOR_SPREAD + bass * BASS_HUE_SHIFT);

    // Intensity from edge detection
    float intensity = smoothstep(0.3, 0.8, dist) + smoothstep(0.3, 1.4, dist);

    // Audio modulates brightness
    float val = intensity * (1.0 + bass * BASS_BRIGHTNESS);

    // Saturation with audio boost
    float sat = SATURATION + high * HIGH_SATURATION;

    vec3 trippyColor = hsv2rgb(vec3(hue, sat, val));

    // ===== COMBINE =====
    vec3 result = feedback.rgb + trippyColor * EFFECT_INTENSITY;
    result = clamp(result, 0.0, 1.0);

    fragColor = vec4(result, 1.0);
}
