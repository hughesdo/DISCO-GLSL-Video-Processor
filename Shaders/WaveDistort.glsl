#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Wave parameters
uniform float waveFrequency;
uniform float waveSpeed;
uniform float baseAmplitude;
uniform float audioAmplitude;
uniform float waveDirection;  // 0=horizontal, 1=vertical

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Calculate wave displacement
    float waveInput = mix(uv.y, uv.x, waveDirection);
    float wave = sin(waveInput * waveFrequency + iTime * waveSpeed) * (baseAmplitude + audio * audioAmplitude);
    
    // Apply wave to perpendicular axis
    if (waveDirection < 0.5) {
        uv.x += wave;
    } else {
        uv.y += wave;
    }
    
    fragColor = texture(iChannel0, uv);
}

