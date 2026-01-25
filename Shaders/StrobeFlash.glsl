// Strobe Flash Effect
// Creates strobe light flashes synced to bass
// WARNING: Use sparingly - can be intense/seizure-inducing
// Converted for DISCO from New Categorized Video Effects

#version 330

in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Tunable parameters
uniform float strobeThreshold;
uniform float flashSpeed;
uniform float flashIntensity;
uniform float colorInvert;
uniform float brightnessPulse;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);

    // Sample audio
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    float kick = texture(iChannel1, vec2(0.02, 0.25)).x;

    // Get original video
    vec3 col = texture(iChannel0, uv).rgb;

    // Strobe trigger (on strong bass)
    float strobe = step(strobeThreshold, kick);

    // Create rapid flashing
    float flash = mod(floor(iTime * flashSpeed), 2.0);
    flash *= strobe;

    // Apply strobe
    if(flash > 0.5) {
        // Invert colors on flash (controlled by colorInvert parameter)
        vec3 inverted = 1.0 - col;
        col = mix(col, inverted, colorInvert);

        // Add white flash intensity
        float flashAmount = (kick - strobeThreshold) / (1.0 - strobeThreshold);
        col = mix(col, vec3(1.0), flashAmount * flashIntensity);
    }

    // Subtle brightness pulse on bass even without strobe
    float pulse = 1.0 + bass * brightnessPulse;
    col *= pulse;

    fragColor = vec4(col, 1.0);
}

