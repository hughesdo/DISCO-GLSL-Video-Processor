#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Triangle overlay parameters
uniform float triangleSize;
uniform float triangleIntensity;
uniform float audioBoost;
uniform float blendAmount;
uniform vec3 triangleColor;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Triangle pattern
    vec2 triUv = uv * triangleSize;
    vec2 id = floor(triUv);
    vec2 gv = fract(triUv) - 0.5;
    
    float triangle = step(abs(gv.x) + abs(gv.y), 0.5);
    triangle *= triangleIntensity * (1.0 + audio * audioBoost);
    
    vec3 triCol = vec3(triangle) * triangleColor;
    
    // Additive blend
    vec3 col = videoCol + triCol * audio * blendAmount;
    
    fragColor = vec4(col, 1.0);
}

