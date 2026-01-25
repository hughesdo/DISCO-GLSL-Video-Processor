#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Voronoi parameters
uniform float cellScale;
uniform float audioCellScale;
uniform float cellAnimation;
uniform float bassAnimation;
uniform float cellIntensity;
uniform float audioBoost;
uniform float blendAmount;
uniform vec3 cellColor;

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    
    // Voronoi pattern
    vec2 voronoiUv = uv * (cellScale + audio * audioCellScale);
    
    vec2 i_uv = floor(voronoiUv);
    vec2 f_uv = fract(voronoiUv);
    
    float minDist = 1.0;
    for(int y = -1; y <= 1; y++) {
        for(int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = hash2(i_uv + neighbor);
            point = 0.5 + 0.5 * sin(iTime * cellAnimation + bass * bassAnimation + 6.28 * point);
            
            float dist = length(neighbor + point - f_uv);
            minDist = min(minDist, dist);
        }
    }
    
    // Create colored cells
    vec3 cellCol = vec3(minDist) * cellIntensity * (1.0 + audio * audioBoost);
    cellCol *= cellColor;
    
    // Blend with video
    float alpha = blendAmount + audio * 0.4;
    vec3 col = mix(videoCol, cellCol, alpha);
    
    fragColor = vec4(col, 1.0);
}

