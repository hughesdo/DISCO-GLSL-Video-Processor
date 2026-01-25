// Digital Glitch Effect
// Random digital glitch artifacts with audio reactivity
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
uniform float glitchFrequency;
uniform float glitchThreshold;
uniform float displacementAmount;
uniform float chromaticShift;
uniform float audioSensitivity;

float hash(float p) {
    return fract(sin(p) * 43758.5453);
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Audio-reactive glitch trigger
    float audio = (bassLevel + midLevel + trebleLevel) / 3.0;
    float glitch = step(glitchThreshold, hash(floor(iTime * glitchFrequency)));
    glitch *= audio * audioSensitivity;
    
    // Horizontal displacement per scanline
    float yOffset = hash(floor(uv.y * 100.0 + iTime)) * displacementAmount * glitch;
    uv.x += yOffset;
    
    // Sample video
    vec3 col = texture(iChannel0, uv).rgb;
    
    // Chromatic aberration on glitch
    if(glitch > 0.5) {
        col.r = texture(iChannel0, uv + vec2(chromaticShift, 0.0)).r;
        col.b = texture(iChannel0, uv - vec2(chromaticShift, 0.0)).b;
    }
    
    fragColor = vec4(col, 1.0);
}

