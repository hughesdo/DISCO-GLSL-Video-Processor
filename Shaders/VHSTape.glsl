#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// VHS parameters
uniform float trackingErrorIntensity;
uniform float colorBleedAmount;
uniform float noiseIntensity;
uniform float desaturation;
uniform float bandIntensity;
uniform float dropoutThreshold;
uniform float chromaNoiseIntensity;
uniform float bassGlitchThreshold;
uniform float glitchIntensity;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.15, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    
    vec2 workUv = uv;
    
    // Tracking errors (horizontal displacement)
    float trackingNoise = hash21(vec2(floor(iTime * 5.0), floor(uv.y * 50.0)));
    if(trackingNoise > 0.95) {
        workUv.x += (trackingNoise - 0.95) * 2.0 * trackingErrorIntensity;
    }
    
    // Bass-reactive tracking glitches
    if(bass > bassGlitchThreshold) {
        float glitchLine = floor(uv.y * 20.0 + iTime * 10.0);
        float glitch = hash21(vec2(glitchLine, floor(iTime * 20.0)));
        if(glitch > 0.7) {
            workUv.x += (glitch - 0.5) * glitchIntensity * bass;
        }
    }
    
    // VHS color bleeding
    vec3 col;
    float bleed = colorBleedAmount + audio * 0.004;
    col.r = texture(iChannel0, workUv).r;
    col.g = texture(iChannel0, workUv - vec2(bleed, 0.0)).g;
    col.b = texture(iChannel0, workUv - vec2(bleed * 2.0, 0.0)).b;
    
    // Tape noise
    float noise = hash21(uv * iTime) * noiseIntensity;
    col += noise;
    
    // Color desaturation (VHS degrades color)
    float luma = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(col, vec3(luma), desaturation);
    
    // Temporal noise (rolling bands)
    float band = sin(uv.y * 10.0 - iTime * 5.0);
    band = smoothstep(0.5, 0.8, band);
    col += band * bandIntensity;
    
    // Head switching noise at top of frame
    if(uv.y > 0.95) {
        float headNoise = hash21(vec2(uv.x, iTime * 10.0)) * 0.5;
        col = mix(col, vec3(headNoise), 0.7);
    }
    
    // Random dropout lines
    float dropout = hash21(vec2(floor(uv.y * 200.0), floor(iTime * 10.0)));
    if(dropout > dropoutThreshold) {
        col *= 0.3;
    }
    
    // Chroma noise
    float chromaNoise = hash21(uv * 100.0 + iTime) * chromaNoiseIntensity;
    col.r += chromaNoise * sin(iTime * 10.0);
    col.b += chromaNoise * cos(iTime * 10.0);
    
    // Contrast reduction
    col = col * 0.9 + 0.05;
    
    // Audio-reactive major glitch
    if(bass > bassGlitchThreshold + 0.2) {
        float majorGlitch = hash21(vec2(uv.y * 5.0, floor(iTime * 30.0)));
        if(majorGlitch > 0.5) {
            col = mix(col, vec3(hash21(uv + iTime)), (bass - bassGlitchThreshold - 0.2) * 5.0);
        }
    }
    
    fragColor = vec4(col, 1.0);
}

