#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Stripe parameters
uniform float stripeFrequency;
uniform float stripeSpeed;
uniform float bassModulation;
uniform float stripeIntensity;
uniform float audioBoost;
uniform vec3 stripeColor;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get video background
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.1, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    
    // Animated stripes
    float stripes = sin((uv.x + uv.y) * stripeFrequency + iTime * stripeSpeed + bass * bassModulation);
    stripes = stripes * 0.5 + 0.5;
    stripes = pow(stripes, 2.0);
    stripes *= stripeIntensity * (1.0 + audio * audioBoost);
    
    vec3 stripeCol = vec3(stripes) * stripeColor;
    
    // Additive blend
    vec3 col = videoCol + stripeCol * 0.5;
    
    fragColor = vec4(col, 1.0);
}

