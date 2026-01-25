// RGB Shift Wave
// Wavy RGB channel separation with audio reactivity
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
uniform float waveFrequency;
uniform float waveSpeed;
uniform float baseShift;
uniform float audioShift;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Audio-reactive wave
    float audio = (bassLevel + midLevel + trebleLevel) / 3.0;
    float wave = sin(uv.y * waveFrequency + iTime * waveSpeed) * (baseShift + audio * audioShift);
    
    // Sample RGB channels with wave offset
    float r = texture(iChannel0, uv + vec2(wave, 0.0)).r;
    float g = texture(iChannel0, uv).g;
    float b = texture(iChannel0, uv - vec2(wave, 0.0)).b;
    
    fragColor = vec4(r, g, b, 1.0);
}

