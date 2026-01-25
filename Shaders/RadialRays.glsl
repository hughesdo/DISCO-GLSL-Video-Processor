#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Radial rays parameters
uniform float rayCount;
uniform float raySpeed;
uniform float bassModulation;
uniform float rayIntensity;
uniform float centerFade;
uniform float audioBoost;
uniform vec3 rayColor;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    
    // Centered UV
    vec2 centeredUv = (uv * 2.0 - 1.0) * vec2(iResolution.x / iResolution.y, 1.0);
    
    float angle = atan(centeredUv.y, centeredUv.x);
    float rays = sin(angle * rayCount + iTime * raySpeed + bass * bassModulation) * 0.5 + 0.5;
    
    float dist = length(centeredUv);
    float fade = 1.0 / (1.0 + dist * dist * centerFade);
    
    vec3 rayCol = vec3(rays * fade) * rayIntensity * (1.0 + audio * audioBoost);
    rayCol *= rayColor;
    
    // Additive blend
    vec3 col = videoCol + rayCol * audio * 0.5;
    
    fragColor = vec4(col, 1.0);
}

