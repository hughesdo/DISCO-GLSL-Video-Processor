#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Radial blur parameters
uniform float baseBlurStrength;
uniform float audioBlurStrength;
uniform int blurSamples;
uniform float colorShift;
uniform float vignetteStrength;
uniform float centerX;
uniform float centerY;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    float mid = texture(iChannel1, vec2(0.15, 0.25)).x;
    
    // Center point
    vec2 center = vec2(centerX, centerY);
    
    // Direction from center
    vec2 dir = uv - center;
    float dist = length(dir);
    
    // Audio-reactive blur strength
    float blurStrength = baseBlurStrength + bass * audioBlurStrength;
    
    // Radial blur
    vec3 col = vec3(0);
    
    for(int i = 0; i < blurSamples; i++) {
        float t = float(i) / float(blurSamples);
        vec2 offset = dir * t * blurStrength;
        col += texture(iChannel0, uv - offset).rgb;
    }
    
    col /= float(blurSamples);
    
    // Color shift with audio
    col.rgb = mix(col.rgb, col.gbr, mid * colorShift);
    
    // Vignette
    col *= 1.0 - dist * vignetteStrength;
    
    fragColor = vec4(col, 1.0);
}

