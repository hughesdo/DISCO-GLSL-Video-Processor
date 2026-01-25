#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Zoom blur parameters
uniform float baseStrength;
uniform float audioStrength;
uniform int blurSamples;
uniform float centerX;
uniform float centerY;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    vec2 center = vec2(centerX, centerY);
    vec3 col = vec3(0);
    
    float strength = baseStrength + audio * audioStrength;
    
    for(int i = 0; i < blurSamples; i++) {
        float scale = 1.0 + (float(i) / float(blurSamples)) * strength;
        vec2 sampleUv = center + (uv - center) * scale;
        col += texture(iChannel0, sampleUv).rgb;
    }
    
    fragColor = vec4(col / float(blurSamples), 1.0);
}

