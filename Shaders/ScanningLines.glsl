#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Scanning lines parameters
uniform float lineFrequency;
uniform float lineSpeed;
uniform float lineSharpness;
uniform float lineIntensity;
uniform float audioBoost;
uniform vec3 lineColor;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Animated scanning lines
    float lines = sin(uv.y * iResolution.y * lineFrequency + iTime * lineSpeed) * 0.5 + 0.5;
    lines = pow(lines, lineSharpness);
    lines *= lineIntensity * (1.0 + audio * audioBoost);
    
    vec3 lineCol = vec3(lines) * lineColor;
    
    // Additive blend
    vec3 col = videoCol + lineCol * audio * 0.3;
    
    fragColor = vec4(col, 1.0);
}

