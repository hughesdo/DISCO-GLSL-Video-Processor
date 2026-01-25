#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Directional blur parameters
uniform float blurAngle;
uniform float angleSpeed;
uniform float baseBlurStrength;
uniform float audioBlurStrength;
uniform int blurSamples;
uniform float audioAngleModulation;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.15, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    
    // Blur direction (audio-controlled)
    float angle = blurAngle + iTime * angleSpeed + bass * audioAngleModulation;
    vec2 blurDir = vec2(cos(angle), sin(angle));
    
    // Blur intensity
    float blurStrength = baseBlurStrength + audio * audioBlurStrength;
    
    // Accumulate blur samples
    vec3 col = vec3(0.0);
    
    for(int i = 0; i < blurSamples; i++) {
        float t = (float(i) / float(blurSamples - 1)) - 0.5; // -0.5 to 0.5
        vec2 offset = blurDir * t * blurStrength;
        col += texture(iChannel0, uv + offset).rgb;
    }
    
    col /= float(blurSamples);
    
    fragColor = vec4(col, 1.0);
}

