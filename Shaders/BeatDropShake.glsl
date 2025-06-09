#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// Audio-reactive uniforms for beat detection
uniform float bassLevel;        // 0.0 to 1.0, bass frequency energy (main trigger)
uniform float kickLevel;        // 0.0 to 1.0, kick drum energy (deepest frequencies)
uniform float subBassLevel;     // 0.0 to 1.0, sub-bass energy (ultra-low frequencies)

// Beat drop shake control uniforms
uniform float beatThreshold;    // Minimum beat strength to trigger shake (0.0-1.0)
uniform float explosionStrength; // Magnitude of screen jolt (0.0-5.0+)
uniform float dampenRate;       // How fast shaking settles (1.0=slow, 10.0=fast)
uniform float randomSeed;       // Seed for shake randomization
uniform float shakeDecay;       // Exponential decay rate for shake
uniform float oversizeAmount;   // Video oversize factor (auto-calculated from explosion strength)
uniform float timeSpeed;        // Overall animation speed multiplier

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

// High-quality random function for shake directions
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

// Generate 2D random vector for shake direction
vec2 randomDirection(float seed, float time) {
    vec2 st = vec2(seed, time);
    float angle = random(st) * 6.28318; // 0 to 2*PI
    float magnitude = random(st + vec2(1.0, 0.0));
    return vec2(cos(angle), sin(angle)) * magnitude;
}

// Beat detection function - creates sharp impulses from deep bass
float detectBeatDrop(float bassEnergy, float kickEnergy, float subBassEnergy, float time) {
    // Combine all low-frequency sources with weighting
    float deepBass = bassEnergy * 0.4 + kickEnergy * 0.4 + subBassEnergy * 0.2;
    
    // Only trigger if above threshold
    if (deepBass < beatThreshold) {
        return 0.0;
    }
    
    // Create sharp beat impulse - instant hit, exponential decay
    float beatTime = mod(time * 10.0, 1.0); // 10Hz beat detection rate
    float beatImpulse = (deepBass - beatThreshold) * exp(-shakeDecay * beatTime);
    
    return beatImpulse;
}

// Generate chaotic shake offset
vec2 generateShakeOffset(float beatStrength, float time, float seed) {
    if (beatStrength <= 0.0) {
        return vec2(0.0);
    }
    
    // Multiple random shake layers for chaotic movement
    vec2 shake1 = randomDirection(seed + 1.0, time * 50.0) * beatStrength;
    vec2 shake2 = randomDirection(seed + 2.0, time * 75.0) * beatStrength * 0.7;
    vec2 shake3 = randomDirection(seed + 3.0, time * 100.0) * beatStrength * 0.5;
    vec2 shake4 = randomDirection(seed + 4.0, time * 125.0) * beatStrength * 0.3;
    
    // Combine all shake layers
    vec2 totalShake = shake1 + shake2 + shake3 + shake4;
    
    // Apply explosion strength and dampen over time
    float dampening = exp(-dampenRate * mod(time, 1.0));
    totalShake *= explosionStrength * dampening;
    
    // Clamp to prevent extreme displacement
    float maxDisplacement = 0.1; // 10% of screen max
    totalShake = clamp(totalShake, -maxDisplacement, maxDisplacement);
    
    return totalShake;
}

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    // Normalize to [0..1]
    vec2 uv = fragCoord / iResolution.xy;
    
    // Apply time speed multiplier
    float animTime = iTime * timeSpeed;
    
    // BEAT DROP DETECTION
    // Detect deep bass beats that should trigger shake
    float beatStrength = detectBeatDrop(bassLevel, kickLevel, subBassLevel, animTime);
    
    // SHAKE GENERATION
    // Generate chaotic shake offset based on beat strength
    vec2 shakeOffset = generateShakeOffset(beatStrength, animTime, randomSeed);
    
    // AUTO-CALCULATE OVERSIZE AMOUNT
    // Video needs to be larger to accommodate shake without showing black edges
    float autoOversizeAmount = 1.0 + (explosionStrength * 0.15); // 15% oversize per explosion strength unit
    
    // APPLY SHAKE TO UV COORDINATES
    // Center the UV coordinates
    vec2 centeredUV = uv - 0.5;
    
    // Apply shake offset
    vec2 shakenUV = centeredUV + shakeOffset;
    
    // Scale down by oversize amount to prevent black edges
    vec2 oversizedUV = shakenUV / autoOversizeAmount;
    
    // Re-center and ensure we stay within bounds
    vec2 finalUV = oversizedUV + 0.5;
    finalUV = clamp(finalUV, 0.0, 1.0);
    
    // SAMPLE THE VIDEO TEXTURE
    vec4 videoColor = texture(iChannel0, finalUV);
    
    // BEAT DROP VISUAL ENHANCEMENTS
    // Add slight brightness flash on beat drops
    float beatFlash = beatStrength * 0.2;
    videoColor.rgb *= (1.0 + beatFlash);
    
    // Add subtle desaturation during intense shakes for impact effect
    float shakeIntensity = length(shakeOffset) * 10.0; // Normalize shake intensity
    float desaturation = shakeIntensity * 0.3;
    vec3 gray = vec3(dot(videoColor.rgb, vec3(0.299, 0.587, 0.114)));
    videoColor.rgb = mix(videoColor.rgb, gray, desaturation);
    
    // Add slight red tint during extreme shakes (impact effect)
    if (shakeIntensity > 0.5) {
        videoColor.r += shakeIntensity * 0.1;
    }
    
    // Ensure colors don't blow out
    videoColor.rgb = clamp(videoColor.rgb, 0.0, 1.2);
    
    fragColor = videoColor;
}
