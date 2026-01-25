// Bass Wobble Screen Shake
// Creates a wobble/shake effect that reacts to bass frequencies
// Perfect for hard bass hits in music videos
// Converted for DISCO from New Categorized Video Effects

#version 330

in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Tunable parameters
uniform float shakeIntensity;
uniform float wobbleIntensity;
uniform float wobbleFrequency;
uniform float wobbleSpeed;
uniform float chromaticAberration;
uniform float bassThreshold;
uniform float kickThreshold;
uniform float shakeUpdateRate;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);

    // Sample bass frequencies (lower frequencies)
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    float kick = texture(iChannel1, vec2(0.02, 0.25)).x;

    // Create threshold for bass hits
    float bassHit = smoothstep(bassThreshold, bassThreshold + 0.5, bass);
    float kickHit = smoothstep(kickThreshold, 1.0, kick);

    // Screen shake with random direction
    vec2 shake = vec2(0.0);
    if (bassHit > 0.1) {
        float shakeTime = floor(iTime * shakeUpdateRate);
        vec2 randomDir = vec2(
            hash21(vec2(shakeTime, 1.0)) * 2.0 - 1.0,
            hash21(vec2(shakeTime, 2.0)) * 2.0 - 1.0
        );
        shake = randomDir * bassHit * shakeIntensity * (1.0 + kickHit * 2.0);
    }

    // Wobble distortion (circular wave emanating from center)
    vec2 center = vec2(0.5);
    vec2 delta = uv - center;
    float dist = length(delta);

    // Bass-reactive wobble waves
    float wobbleFreq = wobbleFrequency + bass * 30.0;
    float wobblePhase = iTime * wobbleSpeed + kickHit * 10.0;
    float wobble = sin(dist * wobbleFreq - wobblePhase) * bassHit * wobbleIntensity;

    // Apply wobble in radial direction
    vec2 wobbleOffset = normalize(delta) * wobble;

    // Combine shake and wobble
    vec2 finalUv = uv + shake + wobbleOffset;

    // Add slight chromatic aberration on heavy bass
    vec3 col;
    if (kickHit > 0.5) {
        float aberration = kickHit * chromaticAberration;
        col.r = texture(iChannel0, finalUv + vec2(aberration, 0.0)).r;
        col.g = texture(iChannel0, finalUv).g;
        col.b = texture(iChannel0, finalUv - vec2(aberration, 0.0)).b;
    } else {
        col = texture(iChannel0, finalUv).rgb;
    }

    fragColor = vec4(col, 1.0);
}

