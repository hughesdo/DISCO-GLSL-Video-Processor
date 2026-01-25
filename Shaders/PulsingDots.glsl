#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Pulsing dots parameters
uniform float dotGridSize;
uniform float baseDotSize;
uniform float audioDotSize;
uniform float dotSmoothness;
uniform float dotIntensity;
uniform float audioBoost;
uniform vec3 dotColor;

float circle(vec2 uv, float r, float smoothness) {
    return smoothstep(r, r - smoothness, length(uv));
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Dot pattern
    vec2 dotUv = uv * dotGridSize;
    vec2 gv = fract(dotUv) - 0.5;
    
    float size = baseDotSize + audio * audioDotSize;
    float dot = circle(gv, size, dotSmoothness);
    
    vec3 dotCol = vec3(dot) * dotColor * dotIntensity * (1.0 + audio * audioBoost);
    
    // Additive blend
    vec3 col = videoCol + dotCol * 0.4;
    
    fragColor = vec4(col, 1.0);
}

