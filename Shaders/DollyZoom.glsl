#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Dolly zoom parameters
uniform float zoomSpeed;
uniform float zoomIntensity;
uniform float rotationIntensity;
uniform float vignetteStrength;
uniform float vignetteSize;
uniform float centerX;
uniform float centerY;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    
    vec2 center = vec2(centerX, centerY);
    
    // Zoom factor based on audio
    float zoom = 1.0 + sin(iTime * zoomSpeed + bass * 5.0) * audio * zoomIntensity;
    
    // Scale from center
    vec2 scaledUv = center + (uv - center) / zoom;
    
    // Add slight rotation for more dramatic effect
    float angle = bass * rotationIntensity;
    float s = sin(angle);
    float c = cos(angle);
    mat2 rot = mat2(c, -s, s, c);
    scaledUv = center + rot * (scaledUv - center);
    
    vec3 col = texture(iChannel0, scaledUv).rgb;
    
    // Vignette effect that intensifies with audio
    float vignette = length(uv - center);
    vignette = 1.0 - smoothstep(vignetteSize, vignetteSize + vignetteStrength - audio * 0.3, vignette);
    col *= vignette;
    
    fragColor = vec4(col, 1.0);
}

