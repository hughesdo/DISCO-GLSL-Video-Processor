#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Perspective tilt parameters
uniform float baseTiltAngle;
uniform float audioTiltAngle;
uniform float tiltCenter;
uniform float horizontalShift;
uniform float blurIntensity;
uniform float blurStart;
uniform float blurEnd;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.2, 0.25)).x;
    
    // Tilt angle (audio controls tilt intensity)
    float tiltAngle = baseTiltAngle + audio * audioTiltAngle;
    
    // Apply perspective transform
    float perspective = 1.0 + (uv.y - tiltCenter) * tiltAngle;
    vec2 tiltedUv = vec2(
        (uv.x - 0.5) / perspective + 0.5,
        uv.y
    );
    
    // Add horizontal shift based on vertical position
    float shift = (uv.y - tiltCenter) * tiltAngle * horizontalShift;
    tiltedUv.x += shift;
    
    vec3 col = texture(iChannel0, tiltedUv).rgb;
    
    // Add depth-of-field blur effect
    float blurAmount = abs(uv.y - tiltCenter) * 2.0;
    blurAmount = smoothstep(blurStart, blurEnd, blurAmount) * blurIntensity;
    
    if (blurAmount > 0.1) {
        vec3 blurredCol = vec3(0.0);
        float samples = 9.0;
        float radius = blurAmount * 0.01;
        
        for(float x = -1.0; x <= 1.0; x++) {
            for(float y = -1.0; y <= 1.0; y++) {
                vec2 offset = vec2(x, y) * radius;
                vec2 sampleUv = vec2(
                    (uv.x + offset.x - 0.5) / perspective + 0.5,
                    uv.y + offset.y
                );
                sampleUv.x += shift;
                blurredCol += texture(iChannel0, sampleUv).rgb;
            }
        }
        blurredCol /= samples;
        col = mix(col, blurredCol, blurAmount);
    }
    
    fragColor = vec4(col, 1.0);
}

