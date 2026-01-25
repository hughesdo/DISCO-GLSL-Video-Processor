// Datamosh / Digital Corruption Effect
// Simulates video compression artifacts and datamoshing
// Audio-reactive glitch intensity
// Converted for DISCO from New Categorized Video Effects

#version 330

in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Tunable parameters
uniform float glitchThreshold;
uniform float blockSizeMin;
uniform float blockSizeMax;
uniform float displacementH;
uniform float displacementV;
uniform float smearAmount;
uniform float smearSamples;
uniform float colorShift;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);

    // Sample audio
    float audio = texture(iChannel1, vec2(0.15, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;

    // Glitch trigger
    float glitchTrigger = step(glitchThreshold, bass);
    float glitchIntensity = audio * glitchTrigger;

    // Block displacement (like I-frame corruption)
    vec2 blockUv = uv;
    float blockSize = blockSizeMin + hash21(floor(iTime * 5.0) * vec2(1.0)) * (blockSizeMax - blockSizeMin);

    if(glitchIntensity > 0.3) {
        vec2 blockId = floor(uv / blockSize);
        float blockRand = hash21(blockId + floor(iTime * 10.0));

        if(blockRand > 0.7) {
            // Horizontal displacement
            blockUv.x += (blockRand - 0.5) * displacementH * glitchIntensity;
        }

        if(blockRand > 0.85) {
            // Vertical displacement
            blockUv.y += (blockRand - 0.5) * displacementV * glitchIntensity;
        }
    }

    // Sample with displaced UVs
    vec3 col = texture(iChannel0, blockUv).rgb;

    // Motion vector-like smearing
    if(glitchIntensity > 0.4) {
        vec2 smearDir = vec2(1.0, 0.0);
        float smearAmt = glitchIntensity * smearAmount;

        vec3 smear = vec3(0.0);
        int samples = int(smearSamples);
        for(int i = 0; i < samples; i++) {
            smear += texture(iChannel0, blockUv + smearDir * smearAmt * float(i)).rgb;
        }
        smear /= float(samples);

        col = mix(col, smear, glitchIntensity * 0.6);
    }

    // Color channel shift (compression artifacts)
    if(glitchIntensity > 0.5) {
        float shift = glitchIntensity * colorShift;
        col.r = texture(iChannel0, blockUv + vec2(shift, 0.0)).r;
        col.b = texture(iChannel0, blockUv - vec2(shift, 0.0)).b;
    }

    // Color quantization (compression)
    if(glitchIntensity > 0.6) {
        float levels = 8.0 - glitchIntensity * 4.0;
        col = floor(col * levels) / levels;
    }

    fragColor = vec4(col, 1.0);
}

