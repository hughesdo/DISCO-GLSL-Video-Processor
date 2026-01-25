#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Ripple parameters
uniform float rippleFrequency;
uniform float rippleSpeed;
uniform float baseAmplitude;
uniform float audioAmplitude;
uniform float centerX;
uniform float centerY;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Ripple center
    vec2 center = vec2(centerX, centerY);
    float dist = length(uv - center);
    
    // Calculate ripple displacement
    float ripple = sin(dist * rippleFrequency - iTime * rippleSpeed) * (baseAmplitude + audio * audioAmplitude);
    vec2 offset = normalize(uv - center) * ripple;
    
    // Sample video with ripple offset
    fragColor = texture(iChannel0, uv + offset);
}

