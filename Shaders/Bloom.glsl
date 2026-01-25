#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Bloom parameters
uniform float baseRadius;
uniform float audioRadius;
uniform float bloomIntensity;
uniform float audioBoost;
uniform float threshold;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    vec3 col = texture(iChannel0, uv).rgb;
    
    // Simple bloom by sampling around
    vec3 bloom = vec3(0);
    float samples = 9.0;
    float radius = baseRadius + audio * audioRadius;
    
    for(float x = -1.0; x <= 1.0; x++) {
        for(float y = -1.0; y <= 1.0; y++) {
            vec2 offset = vec2(x, y) * radius;
            vec3 sample = texture(iChannel0, uv + offset).rgb;
            
            // Only bloom bright areas
            float brightness = dot(sample, vec3(0.299, 0.587, 0.114));
            if (brightness > threshold) {
                bloom += sample;
            }
        }
    }
    
    bloom /= samples;
    col = col + bloom * bloomIntensity * (1.0 + audio * audioBoost);
    
    fragColor = vec4(col, 1.0);
}

