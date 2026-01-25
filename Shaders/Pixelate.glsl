#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Pixelate parameters
uniform float basePixelSize;
uniform float audioPixelSize;
uniform float aspectRatio;  // 0=square, 1=preserve aspect

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Calculate pixel size
    float pixelSize = basePixelSize + audio * audioPixelSize;
    
    // Apply pixelation
    vec2 pixelScale = vec2(pixelSize);
    if (aspectRatio > 0.5) {
        pixelScale.x *= iResolution.x / iResolution.y;
    }
    
    vec2 pixelatedUv = floor(uv * iResolution.xy / pixelScale) * pixelScale / iResolution.xy;
    
    fragColor = texture(iChannel0, pixelatedUv);
}

