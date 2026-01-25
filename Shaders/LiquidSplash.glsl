#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Liquid splash parameters
uniform float splashScale;
uniform float splashSpeed;
uniform float splashThreshold;
uniform float bassThreshold;
uniform float rippleFrequency;
uniform float rippleSpeed;
uniform float splashIntensity;
uniform float edgeIntensity;
uniform float blendAmount;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth noise function
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // Smoothstep
    
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for(int i = 0; i < 5; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get original video
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    float mid = texture(iChannel1, vec2(0.2, 0.25)).x;
    float high = texture(iChannel1, vec2(0.4, 0.25)).x;
    
    // Animated splash pattern
    vec2 splashUv = uv * splashScale;
    splashUv.x += iTime * splashSpeed * 0.1;
    
    // Create organic splash shapes using FBM
    float splash1 = fbm(splashUv + vec2(iTime * splashSpeed * 0.2, 0.0));
    float splash2 = fbm(splashUv * 1.5 - vec2(0.0, iTime * splashSpeed * 0.3));
    float splash3 = fbm(splashUv * 2.0 + vec2(iTime * splashSpeed * 0.15, -iTime * splashSpeed * 0.15));
    
    // Combine splashes
    float splashMask = splash1 * splash2 * splash3;
    
    // Threshold to create defined edges
    splashMask = smoothstep(splashThreshold - bass * bassThreshold, 0.7, splashMask);
    
    // Splash intensity based on audio
    float intensity = bass * 0.5 + mid * 0.3 + high * 0.2;
    
    // Splash color (audio-reactive)
    vec3 splashColor = vec3(
        0.3 + bass,
        0.5 + mid,
        0.8 + high
    );
    
    // Ripple effect in splash
    vec2 center = vec2(0.5);
    float dist = length(uv - center);
    float ripple = sin(dist * rippleFrequency - iTime * rippleSpeed) * 0.5 + 0.5;
    ripple *= intensity;
    
    splashMask = max(splashMask, ripple * 0.3);
    
    // Edge highlights
    vec2 gradUv = splashUv + vec2(0.01);
    float splash1_grad = fbm(gradUv + vec2(iTime * splashSpeed * 0.2, 0.0));
    float splash2_grad = fbm(gradUv * 1.5 - vec2(0.0, iTime * splashSpeed * 0.3));
    float splash3_grad = fbm(gradUv * 2.0 + vec2(iTime * splashSpeed * 0.15, -iTime * splashSpeed * 0.15));
    float splashMask_grad = smoothstep(splashThreshold - bass * bassThreshold, 0.7, splash1_grad * splash2_grad * splash3_grad);
    
    float edge = abs(splashMask - splashMask_grad) * 5.0;
    edge = smoothstep(0.5, 1.0, edge);
    
    vec3 edgeColor = splashColor * edgeIntensity;
    
    // Combine splash with edges
    vec3 finalSplash = splashColor * splashMask * splashIntensity + edgeColor * edge;
    
    // Alpha blending
    float alpha = (splashMask + edge) * intensity * blendAmount;
    
    // Blend splash over video
    vec3 col = mix(videoCol, finalSplash, alpha);
    
    fragColor = vec4(col, 1.0);
}

