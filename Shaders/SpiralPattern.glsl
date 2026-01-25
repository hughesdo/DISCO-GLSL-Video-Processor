#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Spiral parameters
uniform float spiralArms;
uniform float spiralTightness;
uniform float spiralSpeed;
uniform float spiralIntensity;
uniform float audioBoost;
uniform float blendAmount;
uniform vec3 spiralColor;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    
    // Centered UV
    vec2 centeredUv = (uv * 2.0 - 1.0) * vec2(iResolution.x / iResolution.y, 1.0);
    
    float angle = atan(centeredUv.y, centeredUv.x);
    float radius = length(centeredUv);
    
    float spiral = sin(angle * spiralArms + radius * spiralTightness - iTime * spiralSpeed);
    spiral = spiral * 0.5 + 0.5;
    spiral *= spiralIntensity * (1.0 + audio * audioBoost);
    
    vec3 spiralCol = vec3(spiral) * spiralColor;
    
    // Blend with video
    float alpha = blendAmount + audio * 0.3;
    vec3 col = mix(videoCol, spiralCol, alpha);
    
    fragColor = vec4(col, 1.0);
}

