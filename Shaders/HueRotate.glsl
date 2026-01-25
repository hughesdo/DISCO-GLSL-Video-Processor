// Hue Rotation
// Smooth color cycling effect with audio reactivity
// Converted for DISCO from New Categorized Video Effects

#version 330

in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform vec2 iResolution;
uniform float iTime;

// Audio uniforms
uniform float bassLevel;
uniform float midLevel;
uniform float trebleLevel;

// Tunable parameters
uniform float rotationSpeed;
uniform float audioIntensity;

vec3 hueShift(vec3 color, float hue) {
    const vec3 k = vec3(0.57735, 0.57735, 0.57735);
    float cosAngle = cos(hue);
    return vec3(color * cosAngle + cross(k, color) * sin(hue) + k * dot(k, color) * (1.0 - cosAngle));
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Audio-reactive hue rotation
    float audio = (bassLevel + midLevel + trebleLevel) / 3.0;
    float hueAmount = iTime * rotationSpeed + audio * audioIntensity * 6.28318;
    
    vec3 col = texture(iChannel0, uv).rgb;
    col = hueShift(col, hueAmount);
    
    fragColor = vec4(col, 1.0);
}

