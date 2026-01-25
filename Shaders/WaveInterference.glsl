#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Wave interference parameters
uniform float waveFrequency;
uniform float waveSpeed;
uniform float waveSource1X;
uniform float waveSource2X;
uniform float waveIntensity;
uniform float audioBoost;
uniform float blendAmount;
uniform vec3 waveColor;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Centered UV
    vec2 centeredUv = (uv * 2.0 - 1.0) * vec2(iResolution.x / iResolution.y, 1.0);
    
    float w1 = sin(length(centeredUv - vec2(waveSource1X, 0)) * waveFrequency - iTime * waveSpeed);
    float w2 = sin(length(centeredUv + vec2(waveSource2X, 0)) * waveFrequency - iTime * waveSpeed);
    
    float pattern = (w1 + w2) * 0.5;
    pattern = pattern * 0.5 + 0.5;
    pattern *= waveIntensity * (1.0 + audio * audioBoost);
    
    vec3 interferenceCol = vec3(pattern) * waveColor;
    
    // Blend with video
    float alpha = blendAmount + audio * 0.3;
    vec3 col = mix(videoCol, interferenceCol, alpha);
    
    fragColor = vec4(col, 1.0);
}

