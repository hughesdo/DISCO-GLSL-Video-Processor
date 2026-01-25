#version 330
in vec2 v_text;
out vec4 fragColor;

uniform sampler2D iChannel0;  // Video input
uniform sampler2D iChannel1;  // Audio texture
uniform vec2 iResolution;
uniform float iTime;

// Particle burst parameters
uniform float burstFrequency;
uniform float numBursts;
uniform float numParticles;
uniform float particleSpeed;
uniform float particleSize;
uniform float beatThreshold;
uniform float particleIntensity;
uniform float blendAmount;

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.xx + p3.yz) * p3.zy);
}

void main() {
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);
    
    // Get original video
    vec3 col = texture(iChannel0, uv).rgb;
    
    // Sample audio
    float bass = texture(iChannel1, vec2(0.05, 0.25)).x;
    float mid = texture(iChannel1, vec2(0.2, 0.25)).x;
    float high = texture(iChannel1, vec2(0.4, 0.25)).x;
    
    // Detect bass hits
    float beat = smoothstep(beatThreshold, 1.0, bass);
    
    // Particle system
    vec3 particles = vec3(0.0);
    
    for(float i = 0.0; i < numBursts; i++) {
        // Time offset for each burst
        float burstTime = iTime - i * 0.3;
        float burstId = floor(burstTime * burstFrequency);
        
        // Random spawn position based on burst ID
        vec2 spawnPos = hash22(vec2(burstId, i));
        
        for(float j = 0.0; j < numParticles; j++) {
            // Unique ID for this particle
            vec2 particleId = vec2(burstId * numParticles + j, i);
            
            // Random velocity direction
            vec2 randomDir = hash22(particleId) * 2.0 - 1.0;
            randomDir = normalize(randomDir);
            
            // Random speed
            float speed = particleSpeed * (0.3 + hash21(particleId) * 0.3);
            
            // Particle lifetime
            float life = fract(burstTime * burstFrequency);
            
            // Particle position
            vec2 particlePos = spawnPos + randomDir * speed * life;
            
            // Particle size (shrinks over lifetime)
            float size = particleSize * (1.0 - life) * (1.0 + beat * 2.0);
            
            // Distance to particle
            float dist = length(uv - particlePos);
            
            // Particle brightness
            float brightness = smoothstep(size, 0.0, dist);
            
            // Particle color based on audio frequencies
            vec3 particleColor = vec3(
                bass * 2.0,
                mid * 2.0,
                high * 2.0
            );
            
            // Add particle with fade out
            particles += particleColor * brightness * particleIntensity * (1.0 - life);
        }
    }
    
    // Blend particles over video
    float particleAlpha = length(particles) * blendAmount;
    col = col * (1.0 - particleAlpha) + particles;
    
    fragColor = vec4(col, 1.0);
}

