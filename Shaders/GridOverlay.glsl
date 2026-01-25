#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Grid overlay parameters
uniform float gridSize;
uniform float lineThickness;
uniform float gridIntensity;
uniform float audioBoost;
uniform vec3 gridColor;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Grid pattern
    vec2 grid = fract(uv * gridSize);
    float pattern = step(1.0 - lineThickness, grid.x) + step(1.0 - lineThickness, grid.y);
    
    vec3 gridCol = vec3(pattern) * gridIntensity * (0.5 + audio * audioBoost);
    gridCol *= gridColor;
    
    // Additive blend
    vec3 col = videoCol + gridCol * 0.5;
    
    fragColor = vec4(col, 1.0);
}

