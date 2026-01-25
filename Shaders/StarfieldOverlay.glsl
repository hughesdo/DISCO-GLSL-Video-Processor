#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Starfield parameters
uniform float starDensity;
uniform float starSpeed;
uniform float starSize;
uniform float audioStarSize;
uniform float starIntensity;
uniform float audioBoost;
uniform float blendAmount;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    vec3 stars = vec3(0);
    
    // Multiple star layers
    for(float layer = 0.0; layer < 3.0; layer++) {
        vec2 st = uv * (starDensity + layer * 50.0);
        st.x += iTime * starSpeed * (0.1 + layer * 0.05);
        
        vec2 id = floor(st);
        vec2 gv = fract(st) - 0.5;
        
        float n = hash(id + layer);
        if(n > 0.95) {
            float size = starSize * (1.0 + audio * audioStarSize);
            float star = smoothstep(size, 0.0, length(gv));
            stars += vec3(star) * starIntensity * (1.0 + audio * audioBoost);
        }
    }
    
    // Additive blend
    vec3 col = videoCol + stars * blendAmount;
    
    fragColor = vec4(col, 1.0);
}

