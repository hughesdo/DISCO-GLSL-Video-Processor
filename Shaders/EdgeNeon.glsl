// Neon Edge Effect
// Creates neon-style outlines around edges
// Audio-reactive neon colors - perfect for synthwave aesthetic
// Converted for DISCO from New Categorized Video Effects

#version 330

in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Tunable parameters
uniform float edgeThresholdLow;
uniform float edgeThresholdHigh;
uniform float neonIntensity;
uniform float glowLayers;
uniform float glowRadius;
uniform float videoDarken;
uniform float bassNeonR;
uniform float midNeonG;
uniform float highNeonB;
uniform float neonBaseR;
uniform float neonBaseG;
uniform float neonBaseB;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    vec2 pixel = 1.0 / iResolution;

    // Sample audio
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    float mid = texture(iChannel1, vec2(0.2, 0.25)).x;
    float high = texture(iChannel1, vec2(0.4, 0.25)).x;

    // Get original video
    vec3 col = texture(iChannel0, uv).rgb;

    // Sobel edge detection
    vec3 tl = texture(iChannel0, uv + vec2(-pixel.x, pixel.y)).rgb;
    vec3 tr = texture(iChannel0, uv + vec2(pixel.x, pixel.y)).rgb;
    vec3 bl = texture(iChannel0, uv + vec2(-pixel.x, -pixel.y)).rgb;
    vec3 br = texture(iChannel0, uv + vec2(pixel.x, -pixel.y)).rgb;

    vec3 sobelX = -tl + tr - bl + br;
    vec3 sobelY = -tl - tr + bl + br;

    float edge = length(sobelX) + length(sobelY);
    edge = smoothstep(edgeThresholdLow, edgeThresholdHigh, edge);

    // Neon glow color (audio-reactive)
    vec3 neonColor = vec3(
        neonBaseR + bass * bassNeonR,
        neonBaseG + mid * midNeonG,
        neonBaseB + high * highNeonB
    );

    // Multi-layer glow
    vec3 glow = vec3(0.0);
    int layers = int(glowLayers);
    for(int i = 1; i <= layers; i++) {
        float radius = float(i) * glowRadius;
        vec3 layer = vec3(0.0);
        float samples = 0.0;

        for(float x = -2.0; x <= 2.0; x++) {
            for(float y = -2.0; y <= 2.0; y++) {
                vec2 offset = vec2(x, y) * pixel * radius;
                vec3 s = texture(iChannel0, uv + offset).rgb;

                // Edge detect at offset
                vec3 e = abs(s - col);
                float edgeSample = length(e);
                layer += edgeSample * neonColor;
                samples += 1.0;
            }
        }

        layer /= samples;
        glow += layer / float(i);
    }

    // Combine - darken original video and add bright neon edges
    vec3 finalCol = col * videoDarken + edge * neonColor * neonIntensity + glow;

    fragColor = vec4(finalCol, 1.0);
}

