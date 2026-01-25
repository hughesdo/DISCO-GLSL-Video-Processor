#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Twist parameters
uniform float twistStrength;
uniform float audioTwist;
uniform float centerX;
uniform float centerY;
uniform float animationSpeed;

mat2 rot(float a) {
    return mat2(cos(a), -sin(a), sin(a), cos(a));
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Twist center
    vec2 center = vec2(centerX, centerY);
    vec2 delta = uv - center;
    float dist = length(delta);
    
    // Calculate twist angle based on distance and audio
    float angle = dist * (twistStrength + audio * audioTwist) + iTime * animationSpeed;
    delta = rot(angle) * delta;
    
    fragColor = texture(iChannel0, center + delta);
}

