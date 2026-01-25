// Edge Glow Effect
// Detects edges in video and adds colorful audio-reactive glow
// Uses Sobel edge detection with multi-pass blur
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
uniform float glowIntensity;
uniform float blurKernelBase;
uniform float blurKernelAudio;
uniform float bassColorMult;
uniform float midColorMult;
uniform float highColorMult;
uniform float pulseMult;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    vec2 pixel = 1.0 / iResolution;

    // Sample audio for glow intensity and color
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    float mid = texture(iChannel1, vec2(0.2, 0.25)).x;
    float high = texture(iChannel1, vec2(0.4, 0.25)).x;

    // Sobel edge detection
    vec3 c = texture(iChannel0, uv).rgb;

    // Sample surrounding pixels
    vec3 tl = texture(iChannel0, uv + vec2(-pixel.x, pixel.y)).rgb;
    vec3 t  = texture(iChannel0, uv + vec2(0.0, pixel.y)).rgb;
    vec3 tr = texture(iChannel0, uv + vec2(pixel.x, pixel.y)).rgb;
    vec3 l  = texture(iChannel0, uv + vec2(-pixel.x, 0.0)).rgb;
    vec3 r  = texture(iChannel0, uv + vec2(pixel.x, 0.0)).rgb;
    vec3 bl = texture(iChannel0, uv + vec2(-pixel.x, -pixel.y)).rgb;
    vec3 b  = texture(iChannel0, uv + vec2(0.0, -pixel.y)).rgb;
    vec3 br = texture(iChannel0, uv + vec2(pixel.x, -pixel.y)).rgb;

    // Sobel operator
    vec3 sobelX = -tl - 2.0*l - bl + tr + 2.0*r + br;
    vec3 sobelY = -tl - 2.0*t - tr + bl + 2.0*b + br;

    // Calculate edge strength
    float edgeX = length(sobelX);
    float edgeY = length(sobelY);
    float edge = sqrt(edgeX * edgeX + edgeY * edgeY);

    // Threshold for edge detection
    edge = smoothstep(edgeThresholdLow, edgeThresholdHigh, edge);

    // Create audio-reactive glow color
    vec3 glowColor = vec3(
        bass * bassColorMult,
        mid * midColorMult,
        high * highColorMult
    );

    // Pulsing glow based on overall audio
    float pulse = 1.0 + audio * pulseMult;

    // Apply glow to edges
    vec3 glow = edge * glowColor * pulse * glowIntensity;

    // Multi-pass blur for softer glow
    vec3 blurredGlow = vec3(0.0);
    float kernelSize = blurKernelBase + audio * blurKernelAudio;
    float samples = 0.0;

    for(float x = -2.0; x <= 2.0; x += 1.0) {
        for(float y = -2.0; y <= 2.0; y += 1.0) {
            vec2 offset = vec2(x, y) * pixel * kernelSize;

            // Edge detection at offset
            vec3 offsetC = texture(iChannel0, uv + offset).rgb;
            vec3 offsetTL = texture(iChannel0, uv + offset + vec2(-pixel.x, pixel.y)).rgb;
            vec3 offsetBR = texture(iChannel0, uv + offset + vec2(pixel.x, -pixel.y)).rgb;

            float offsetEdge = length(offsetTL - offsetBR);
            offsetEdge = smoothstep(edgeThresholdLow, edgeThresholdHigh, offsetEdge);

            blurredGlow += offsetEdge * glowColor;
            samples += 1.0;
        }
    }

    blurredGlow /= samples;
    blurredGlow *= pulse * 0.5;

    // Combine original video with glow
    vec3 finalColor = c + glow + blurredGlow;

    fragColor = vec4(finalColor, 1.0);
}

