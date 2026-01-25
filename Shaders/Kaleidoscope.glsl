#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Kaleidoscope parameters
uniform float baseSegments;
uniform float audioSegments;
uniform float rotation;
uniform float rotationSpeed;
uniform float zoom;

#define PI 3.14159265359

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Center and scale
    vec2 centered = (uv * 2.0 - 1.0) * vec2(iResolution.x / iResolution.y, 1.0) * zoom;
    
    float angle = atan(centered.y, centered.x) + rotation + iTime * rotationSpeed;
    float radius = length(centered);
    
    // Number of segments (audio reactive)
    float segments = baseSegments + audio * audioSegments;
    angle = mod(angle, PI * 2.0 / segments);
    
    // Mirror every other segment
    if(mod(floor(atan(centered.y, centered.x) / (PI * 2.0 / segments)), 2.0) == 1.0) {
        angle = PI * 2.0 / segments - angle;
    }
    
    vec2 newUv = vec2(cos(angle), sin(angle)) * radius;
    newUv = newUv * 0.5 + 0.5;
    
    fragColor = texture(iChannel0, newUv);
}

