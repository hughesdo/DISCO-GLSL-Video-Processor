#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Barrel distortion parameters
uniform float baseStrength;
uniform float audioStrength;
uniform float centerX;
uniform float centerY;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.15, 0.25)).x;
    
    // Center coordinates
    vec2 center = vec2(centerX, centerY);
    vec2 delta = uv - center;
    
    // Barrel distortion strength (audio reactive)
    float strength = baseStrength + audio * audioStrength;
    
    // Distance from center
    float dist = length(delta);
    
    // Apply barrel distortion formula
    float distortedDist = dist * (1.0 + strength * dist * dist);
    
    // Calculate new UV coordinates
    vec2 distortedUv = center + normalize(delta) * distortedDist;
    
    // Sample texture
    vec3 col = texture(iChannel0, distortedUv).rgb;
    
    fragColor = vec4(col, 1.0);
}

