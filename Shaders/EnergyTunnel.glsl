#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Energy tunnel parameters
uniform float tunnelSpeed;
uniform float bassTunnelSpeed;
uniform float ringSharpness;
uniform float segmentCount;
uniform float segmentSpeed;
uniform float pulseSpeed;
uniform float bassPulse;
uniform float tunnelIntensity;
uniform float centerFade;
uniform float blendAmount;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get original video
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    float mid = texture(iChannel1, vec2(0.2, 0.25)).x;
    float audio = texture(iChannel1, vec2(0.15, 0.25)).x;
    
    // Center coordinates
    vec2 center = vec2(0.5);
    vec2 delta = uv - center;
    
    // Polar coordinates
    float radius = length(delta);
    float angle = atan(delta.y, delta.x);
    
    // Tunnel effect
    float depth = 1.0 / (radius + 0.1);
    float tunnel = depth + iTime * (tunnelSpeed + bass * bassTunnelSpeed);
    
    // Create rings
    float rings = fract(tunnel);
    rings = smoothstep(0.3, 0.5, rings) - smoothstep(0.5, 0.7, rings);
    rings = pow(rings, ringSharpness);
    
    // Rotating segments
    float segmentPattern = sin(angle * segmentCount + iTime * segmentSpeed);
    segmentPattern = smoothstep(0.0, 0.3, segmentPattern);
    
    // Combine patterns
    float pattern = rings * segmentPattern;
    
    // Pulsing energy
    float pulse = 0.5 + 0.5 * sin(iTime * pulseSpeed + bass * bassPulse);
    
    // Audio-reactive color
    vec3 tunnelColor = vec3(
        0.2 + bass * 0.8,
        0.5 + mid * 0.5,
        0.8 + audio * 0.2
    );
    
    // Energy glow
    vec3 energy = pattern * tunnelColor * tunnelIntensity * (1.0 + pulse * bass * 2.0);
    
    // Distance fade (stronger in center)
    float fade = 1.0 - smoothstep(0.0, centerFade, radius);
    energy *= fade;
    
    // Additive blend
    vec3 col = videoCol + energy * blendAmount;
    
    fragColor = vec4(col, 1.0);
}

