// Posterize Effect
// Reduces color depth for a stylized, retro look
// Audio controls posterization levels
// Converted for DISCO from New Categorized Video Effects

#version 330

in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform vec2 iResolution;
uniform float iTime;

// Audio uniforms
uniform float bassLevel;
uniform float midLevel;
uniform float trebleLevel;

// Tunable parameters
uniform float minLevels;
uniform float maxLevels;
uniform float audioControl;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);

    // Sample audio
    float audio = (bassLevel + midLevel + trebleLevel) / 3.0;

    // Get original video
    vec3 col = texture(iChannel0, uv).rgb;

    // Number of color levels (audio controlled)
    // More audio = fewer levels (more posterized)
    float levels = mix(maxLevels, minLevels, audio * audioControl);
    levels = max(2.0, levels);  // Ensure at least 2 levels

    // Posterize
    col = floor(col * levels) / levels;

    fragColor = vec4(col, 1.0);
}

