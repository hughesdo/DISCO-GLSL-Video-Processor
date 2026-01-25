#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Light rays parameters
uniform float lightPosX;
uniform float lightPosY;
uniform float lightMovement;
uniform float rayLength;
uniform float audioRayLength;
uniform float numSamples;
uniform float rayDecay;
uniform float brightnessThreshold;
uniform float rayIntensity;
uniform float audioBoost;
uniform vec3 rayColor;

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get original video
    vec3 videoCol = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float audio = texture(iChannel1, vec2(0.15, 0.25)).x;
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    
    // Light source position (animated)
    vec2 lightPos = vec2(lightPosX, lightPosY);
    lightPos.x += sin(iTime + bass * 5.0) * lightMovement;
    lightPos.y += cos(iTime * 0.7) * lightMovement * 0.5;
    
    // Calculate ray direction
    vec2 deltaUv = uv - lightPos;
    float dist = length(deltaUv);
    
    // Radial blur to create god rays
    vec3 rays = vec3(0.0);
    float weight = 1.0;
    float effectiveRayLength = rayLength + audio * audioRayLength;
    
    for(float i = 0.0; i < numSamples; i++) {
        float t = i / numSamples;
        vec2 sampleUv = uv - deltaUv * t * effectiveRayLength;
        
        // Sample the video
        vec3 sampleCol = texture(iChannel0, sampleUv).rgb;
        
        // Extract bright areas
        float brightness = dot(sampleCol, vec3(0.299, 0.587, 0.114));
        brightness = smoothstep(brightnessThreshold, 1.0, brightness);
        
        rays += sampleCol * brightness * weight;
        weight *= rayDecay;
    }
    
    rays /= numSamples;
    
    // Distance falloff
    float falloff = 1.0 - smoothstep(0.0, 1.0, dist);
    rays *= falloff;
    
    // Audio-reactive intensity
    float intensity = rayIntensity + audio * audioBoost;
    rays *= intensity;
    
    // Apply color tint
    vec3 tintedRays = rays * rayColor;
    
    // Additive blend
    vec3 col = videoCol + tintedRays * 0.6;
    
    fragColor = vec4(col, 1.0);
}

