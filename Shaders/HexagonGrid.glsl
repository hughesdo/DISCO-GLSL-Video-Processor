#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Hexagon grid parameters
uniform float hexSize;
uniform float hexThickness;
uniform float hexSmoothness;
uniform float hexIntensity;
uniform float audioBoost;
uniform float blendAmount;
uniform vec3 hexColor;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Hexagon pattern
    vec2 hexUv = uv * hexSize;
    
    vec2 r = vec2(1.0, 1.73);
    vec2 h = r * 0.5;
    vec2 a = mod(hexUv, r) - h;
    vec2 b = mod(hexUv - h, r) - h;
    
    vec2 gv = length(a) < length(b) ? a : b;
    float d = length(gv);
    
    float c = smoothstep(hexThickness, hexThickness + hexSmoothness, d);
    c *= hexIntensity * (1.0 + audio * audioBoost);
    
    vec3 hexCol = vec3(c) * hexColor;
    
    // Blend with video
    float alpha = blendAmount + audio * 0.3;
    vec3 col = mix(videoCol, hexCol, alpha);
    
    fragColor = vec4(col, 1.0);
}

