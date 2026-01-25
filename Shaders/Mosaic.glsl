#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Mosaic parameters
uniform float baseTileSize;
uniform float audioTileSize;
uniform float colorIntensity;
uniform float audioBoost;
uniform float videoBlend;
uniform float animationSpeed;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Get video color
    vec4 video = texture(iChannel0, uv);
    
    // Calculate tile size
    float size = baseTileSize + audio * audioTileSize;
    vec2 id = floor(uv * size);
    
    // Generate random color per tile
    float h = hash(id + floor(iTime * animationSpeed));
    vec3 mosaicCol = vec3(
        fract(h),
        fract(h * 2.0),
        fract(h * 3.0)
    );
    
    mosaicCol *= colorIntensity * (0.7 + audio * audioBoost);
    
    // Blend mosaic with video
    vec3 result = mix(mosaicCol, video.rgb * mosaicCol, videoBlend);
    
    fragColor = vec4(result, 1.0);
}

