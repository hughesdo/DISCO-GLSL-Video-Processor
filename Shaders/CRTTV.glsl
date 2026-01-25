#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// CRT parameters
uniform float curvatureAmount;
uniform float chromaticAberration;
uniform float audioAberration;
uniform float scanlineIntensity;
uniform float scanlineCount;
uniform float flickerSpeed;
uniform float flickerIntensity;
uniform float vignetteStrength;
uniform float staticThreshold;
uniform float staticIntensity;
uniform float ghostingAmount;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.15, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    
    // CRT curvature
    vec2 crtUv = uv * 2.0 - 1.0;
    crtUv *= 1.0 + curvatureAmount * length(crtUv);
    crtUv = crtUv * 0.5 + 0.5;
    
    // Screen bounds (black bars outside curved screen)
    if(crtUv.x < 0.0 || crtUv.x > 1.0 || crtUv.y < 0.0 || crtUv.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    // Chromatic aberration
    float aberration = chromaticAberration + audio * audioAberration;
    vec3 col;
    col.r = texture(iChannel0, crtUv + vec2(aberration, 0.0)).r;
    col.g = texture(iChannel0, crtUv).g;
    col.b = texture(iChannel0, crtUv - vec2(aberration, 0.0)).b;
    
    // Scanlines
    float scanline = sin(crtUv.y * iResolution.y * scanlineCount) * 0.5 + 0.5;
    scanline = scanline * scanlineIntensity + (1.0 - scanlineIntensity);
    col *= scanline;
    
    // Horizontal scanline flicker
    float flicker = sin(iTime * flickerSpeed + crtUv.y * 10.0) * flickerIntensity + (1.0 - flickerIntensity);
    col *= flicker;
    
    // RGB phosphor dots (subtle)
    float phosphor = sin(crtUv.x * iResolution.x * 3.0) * 0.05 + 0.95;
    col *= phosphor;
    
    // Vignette
    vec2 vignetteUv = uv * (1.0 - uv);
    float vignette = vignetteUv.x * vignetteUv.y * 15.0;
    vignette = pow(vignette, 0.3);
    col *= mix(1.0, vignette, vignetteStrength);
    
    // Static/noise on audio
    if(bass > staticThreshold) {
        float noise = hash21(crtUv * iTime) * bass * staticIntensity;
        col += noise;
    }
    
    // Screen flicker
    float globalFlicker = 1.0 + sin(iTime * 100.0) * 0.01;
    col *= globalFlicker;
    
    // Color bleed/ghosting
    vec3 ghost = texture(iChannel0, crtUv + vec2(ghostingAmount, 0.0)).rgb * 0.1;
    col += ghost;
    
    fragColor = vec4(col, 1.0);
}

