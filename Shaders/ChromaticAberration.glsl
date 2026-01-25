// Chromatic Aberration
// RGB channel separation effect - simulates lens distortion
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
uniform float baseOffset;
uniform float audioIntensity;
uniform float offsetAngle;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Audio-reactive offset
    float audio = (bassLevel + midLevel + trebleLevel) / 3.0;
    float offsetAmount = baseOffset + audio * audioIntensity;
    
    // Calculate offset direction
    vec2 offset = vec2(cos(offsetAngle), sin(offsetAngle)) * offsetAmount;
    
    // Sample RGB channels with offset
    float r = texture(iChannel0, uv + offset).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - offset).b;
    
    fragColor = vec4(r, g, b, 1.0);
}

