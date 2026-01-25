// Color Waves Effect
// Applies animated color waves across the video
// Audio-reactive wave speed and intensity
// Converted for DISCO from New Categorized Video Effects

#version 330

in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Tunable parameters
uniform float wave1Frequency;
uniform float wave1Speed;
uniform float wave2Frequency;
uniform float wave2Speed;
uniform float wave3Frequency;
uniform float wave3Speed;
uniform float hueIntensity;
uniform float mixAmount;
uniform float colorOverlay;

vec3 hueShift(vec3 color, float shift) {
    const vec3 k = vec3(0.57735, 0.57735, 0.57735);
    float cosAngle = cos(shift);
    return vec3(color * cosAngle + cross(k, color) * sin(shift) + k * dot(k, color) * (1.0 - cosAngle));
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);

    // Sample audio
    float audio = texture(iChannel1, vec2(0.15, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    float mid = texture(iChannel1, vec2(0.2, 0.25)).x;
    float high = texture(iChannel1, vec2(0.4, 0.25)).x;

    // Get original video
    vec3 col = texture(iChannel0, uv).rgb;

    // Create color wave patterns
    float wave1 = sin(uv.x * wave1Frequency + iTime * wave1Speed + bass * 5.0);
    float wave2 = cos(uv.y * wave2Frequency - iTime * wave2Speed + mid * 5.0);
    float wave3 = sin((uv.x + uv.y) * wave3Frequency + iTime * wave3Speed + high * 5.0);

    // Combine waves
    float combinedWave = (wave1 + wave2 + wave3) / 3.0;

    // Map wave to hue shift
    float hueShiftAmount = combinedWave * 3.14159 * audio * hueIntensity;

    // Apply hue shift
    vec3 shiftedCol = hueShift(col, hueShiftAmount);

    // Mix based on audio intensity
    float dynamicMix = mixAmount + audio * 0.7;
    col = mix(col, shiftedCol, dynamicMix);

    // Add color overlay based on frequency bands
    vec3 freqColor = vec3(bass, mid, high);
    col = mix(col, col * (1.0 + freqColor), audio * colorOverlay);

    fragColor = vec4(col, 1.0);
}

