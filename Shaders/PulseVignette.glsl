// Pulse Vignette Effect
// Creates a pulsing vignette that responds to bass
// Perfect for music video beat emphasis
// Converted for DISCO from New Categorized Video Effects

#version 330

in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Tunable parameters
uniform float vignetteSize;
uniform float vignetteSoftness;
uniform float pulseIntensity;
uniform float vignetteStrength;
uniform float brightnessPulse;
uniform float flashThreshold;
uniform float flashIntensity;
uniform float vignetteColorR;
uniform float vignetteColorG;
uniform float vignetteColorB;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);

    // Sample audio
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    float kick = texture(iChannel1, vec2(0.02, 0.25)).x;
    float audio = texture(iChannel1, vec2(0.15, 0.25)).x;

    // Get original video
    vec3 col = texture(iChannel0, uv).rgb;

    // Distance from center
    vec2 center = vec2(0.5);
    float dist = length(uv - center);

    // Pulsing vignette
    float pulse = bass * pulseIntensity;
    float dynamicVignetteSize = vignetteSize - pulse * 0.3;
    float dynamicVignetteSoftness = vignetteSoftness + kick * 0.3;

    float vignette = smoothstep(dynamicVignetteSize, dynamicVignetteSize + dynamicVignetteSoftness, dist);

    // Vignette color based on audio
    vec3 vignetteColor = vec3(0.0);

    // Color the vignette based on beat
    if(bass > 0.5) {
        vignetteColor = vec3(
            bass * vignetteColorR,
            bass * vignetteColorG,
            bass * vignetteColorB
        );
    }

    // Apply vignette
    col = mix(col, vignetteColor, vignette * vignetteStrength);

    // Additional brightness pulse
    float brightness = 1.0 + kick * brightnessPulse;
    col *= brightness;

    // Flash effect on strong kicks
    if(kick > flashThreshold) {
        float flash = (kick - flashThreshold) / (1.0 - flashThreshold);
        col = mix(col, vec3(1.0), flash * flashIntensity);
    }

    fragColor = vec4(col, 1.0);
}

