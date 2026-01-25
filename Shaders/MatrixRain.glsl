#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Matrix rain parameters
uniform float columnDensity;
uniform float fallSpeed;
uniform float characterDensity;
uniform float brightness;
uniform float audioBoost;
uniform float videoDarken;
uniform float rainIntensity;

float hash(float p) {
    return fract(sin(p) * 43758.5453);
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    vec2 matrixUv = uv;
    matrixUv.x *= iResolution.x / iResolution.y;
    matrixUv *= columnDensity;
    
    vec2 id = floor(matrixUv);
    float speed = hash(id.x) * fallSpeed + 1.0;
    float offset = hash(id.x + 1.0) * 100.0;
    
    float y = fract(matrixUv.y - iTime * speed + offset);
    float bright = y * y * brightness;
    
    float cell = step(characterDensity, hash(id.x + id.y + floor(iTime * speed)));
    
    // Matrix rain color (green)
    vec3 matrixCol = vec3(0, bright * cell * rainIntensity * (1.0 + audio * audioBoost), 0);
    
    // Darken video and add matrix rain
    vec3 col = videoCol * videoDarken + matrixCol;
    
    fragColor = vec4(col, 1.0);
}

