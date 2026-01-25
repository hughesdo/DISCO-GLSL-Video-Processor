#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Concentric rings parameters
uniform float ringFrequency;
uniform float ringSpeed;
uniform float bassModulation;
uniform float ringSharpness;
uniform float ringIntensity;
uniform float audioBoost;
uniform vec3 ringColor;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    
    // Centered UV
    vec2 centeredUv = (uv * 2.0 - 1.0) * vec2(iResolution.x / iResolution.y, 1.0);
    
    float dist = length(centeredUv);
    float rings = sin(dist * ringFrequency - iTime * ringSpeed - bass * bassModulation) * 0.5 + 0.5;
    rings = pow(rings, ringSharpness);
    
    vec3 ringCol = vec3(rings) * ringIntensity * (1.0 + audio * audioBoost);
    ringCol *= ringColor;
    
    // Additive blend
    vec3 col = videoCol + ringCol * audio * 0.5;
    
    fragColor = vec4(col, 1.0);
}

