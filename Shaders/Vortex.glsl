#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Vortex parameters
uniform float vortexSpeed;
uniform float vortexFrequency;
uniform float vortexRadius;
uniform float vortexIntensity;
uniform float audioBoost;
uniform float blendMode;  // 0=overlay, 1=multiply, 2=add
uniform vec3 vortexColor;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video input
    vec4 video = texture(iChannel0, uv);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Center-based coordinates
    vec2 centered = (uv * 2.0 - 1.0) * vec2(iResolution.x / iResolution.y, 1.0);
    
    float angle = atan(centered.y, centered.x);
    float radius = length(centered);
    
    // Create vortex pattern
    float vortex = sin(angle * vortexFrequency - radius * vortexRadius + iTime * vortexSpeed);
    vortex = vortex * 0.5 + 0.5;
    vortex *= exp(-radius);
    vortex *= vortexIntensity * (1.0 + audio * audioBoost);
    
    vec3 vortexCol = vortex * vortexColor;
    
    // Blend with video
    vec3 result;
    if (blendMode < 0.5) {
        // Overlay
        result = video.rgb + vortexCol;
    } else if (blendMode < 1.5) {
        // Multiply
        result = video.rgb * (1.0 + vortexCol);
    } else {
        // Add
        result = video.rgb + vortexCol * 0.5;
    }
    
    fragColor = vec4(result, 1.0);
}

