#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Plasma parameters
uniform float plasmaScale;
uniform float plasmaSpeed;
uniform float bassModulation;
uniform float plasmaIntensity;
uniform float colorShift;
uniform float blendAmount;
uniform float audioBlend;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    
    // Plasma calculation
    vec2 plasmaUv = (uv * 2.0 - 1.0) * vec2(iResolution.x / iResolution.y, 1.0);
    
    float v = 0.0;
    v += sin(plasmaUv.x * plasmaScale + iTime * plasmaSpeed);
    v += sin(plasmaUv.y * plasmaScale + iTime * plasmaSpeed);
    v += sin((plasmaUv.x + plasmaUv.y) * plasmaScale + iTime * plasmaSpeed);
    v += sin(length(plasmaUv) * plasmaScale + iTime * plasmaSpeed + bass * bassModulation);
    v *= 0.25;
    
    v = v * 0.5 + 0.5;
    v *= plasmaIntensity;
    
    vec3 plasmaCol = vec3(
        sin(v * 6.28 + colorShift),
        sin(v * 6.28 + colorShift + 2.09),
        sin(v * 6.28 + colorShift + 4.18)
    ) * 0.5 + 0.5;
    
    // Blend with video
    float alpha = blendAmount + audio * audioBlend;
    vec3 col = mix(videoCol, plasmaCol, alpha);
    
    fragColor = vec4(col, 1.0);
}

