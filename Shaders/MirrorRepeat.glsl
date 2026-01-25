#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Mirror repeat parameters
uniform float baseSegments;
uniform float audioSegments;
uniform float baseRotation;
uniform float audioRotation;
uniform float centerX;
uniform float centerY;

mat2 rot(float a) {
    return mat2(cos(a), -sin(a), sin(a), cos(a));
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.15, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    
    // Center coordinates
    vec2 center = vec2(centerX, centerY);
    vec2 delta = uv - center;
    
    // Rotate based on audio
    float angle = baseRotation + bass * audioRotation;
    delta = rot(angle) * delta;
    
    // Number of mirror segments (audio controlled)
    float segments = baseSegments + floor(audio * audioSegments);
    
    // Convert to polar
    float radius = length(delta);
    float theta = atan(delta.y, delta.x);
    
    // Mirror repeat
    float segmentAngle = 6.28318 / segments;
    theta = mod(theta, segmentAngle);
    
    // Mirror every other segment
    if(mod(floor(theta / segmentAngle * segments), 2.0) > 0.5) {
        theta = segmentAngle - theta;
    }
    
    // Convert back to Cartesian
    vec2 mirroredUv = center + vec2(cos(theta), sin(theta)) * radius;
    
    // Sample texture
    vec3 col = texture(iChannel0, mirroredUv).rgb;
    
    fragColor = vec4(col, 1.0);
}

