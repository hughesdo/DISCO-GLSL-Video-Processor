#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Pulsing waves parameters
uniform float waveFrequency;
uniform float waveSpeed;
uniform float audioModulation;
uniform float waveSharpness;
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
    
    float dist = length(centeredUv);
    float pulse = sin(dist * waveFrequency - iTime * waveSpeed - audio * audioModulation);
    pulse = pulse * 0.5 + 0.5;
    pulse = pow(pulse, waveSharpness);
    pulse *= waveIntensity;
    
    vec3 pulseCol = vec3(pulse) * waveColor;
    
    // Blend with video
    float alpha = blendAmount + audio * audioBoost;
    vec3 col = mix(videoCol, pulseCol, alpha);
    
    fragColor = vec4(col, 1.0);
}

