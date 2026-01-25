#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Checkerboard parameters
uniform float checkerSize;
uniform float rotationSpeed;
uniform float bassRotation;
uniform float blendAmount;
uniform vec3 color1;
uniform vec3 color2;

mat2 rot(float a) {
    return mat2(cos(a), -sin(a), sin(a), cos(a));
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    
    // Checkerboard pattern
    vec2 centered = (uv * 2.0 - 1.0) * vec2(iResolution.x / iResolution.y, 1.0);
    vec2 checkerUv = rot(iTime * rotationSpeed + bass * bassRotation) * centered;
    checkerUv *= checkerSize;
    
    float checker = mod(floor(checkerUv.x) + floor(checkerUv.y), 2.0);
    
    vec3 checkerCol = mix(color1, color2, checker);
    checkerCol *= audio;
    
    // Blend with video
    float alpha = audio * blendAmount;
    vec3 col = mix(videoCol, checkerCol, alpha);
    
    fragColor = vec4(col, 1.0);
}

