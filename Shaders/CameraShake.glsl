#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// Beat detection uniforms for camera shake
uniform float beatIntensity;    // 0.0 to 2.0, detected beat strength (drum hits)
uniform float kickLevel;        // 0.0 to 1.0, kick drum energy (low freq beats)
uniform float snareLevel;       // 0.0 to 1.0, snare drum energy (mid freq beats)

// User-configurable uniforms
uniform float shakeIntensity;   // Overall shake strength multiplier (auto-oversamples)
uniform float beatDecay;        // How fast beat impacts decay (higher = snappier)
uniform float beatThreshold;    // Minimum beat strength to trigger shake
uniform float maxShakeRadius;   // Maximum shake distance from center

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

// Random function for shake direction variation
float random(float x) {
    return fract(sin(x * 12.9898) * 43758.5453);
}

// Drum beat detection and shake generation
float drumBeatShake(float beatStrength, float time, float randomSeed) {
    // Only trigger shake if beat is above threshold
    if (beatStrength < beatThreshold) return 0.0;

    // Create sharp beat impulse - instant hit, exponential decay
    float timeSinceBeat = mod(time, 1.0);
    float beatImpulse = beatStrength * exp(-beatDecay * timeSinceBeat);

    // Random direction for each beat
    float randomDir = (random(floor(time) + randomSeed) - 0.5) * 2.0;

    // Scale by shake intensity and clamp to max radius
    float shake = beatImpulse * randomDir * shakeIntensity;
    return clamp(shake, -maxShakeRadius, maxShakeRadius);
}

// Detect if we're currently in a beat moment
float getBeatMoment(float beatStrength, float time) {
    float timeSinceBeat = mod(time, 1.0);
    // Beat moment is strongest at the start, fades quickly
    return beatStrength * exp(-beatDecay * timeSinceBeat);
}

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;

    // Normalize to [0..1]
    vec2 uv = fragCoord / iResolution.xy;

    // DRUM BEAT DETECTION - Only shake on actual drum hits
    float drumTime = iTime * 2.5;  // Drum beat timing (2.5 beats per second)

    // Combine kick and snare for total drum energy
    float totalDrumEnergy = max(kickLevel, snareLevel) * beatIntensity;

    // Generate shake only when drums hit
    float drumShakeX = drumBeatShake(totalDrumEnergy, drumTime, 1.0);
    float drumShakeY = drumBeatShake(totalDrumEnergy, drumTime, 2.0);

    // Additional shake for kick vs snare distinction
    float kickTime = iTime * 1.8;   // Kick drum timing (slower)
    float snareTime = iTime * 3.2;  // Snare timing (faster)

    float kickShakeX = drumBeatShake(kickLevel * beatIntensity, kickTime, 3.0) * 0.8;
    float kickShakeY = drumBeatShake(kickLevel * beatIntensity, kickTime, 4.0) * 0.8;

    float snareShakeX = drumBeatShake(snareLevel * beatIntensity, snareTime, 5.0) * 0.6;
    float snareShakeY = drumBeatShake(snareLevel * beatIntensity, snareTime, 6.0) * 0.6;

    // Total shake = main drum beats + kick emphasis + snare emphasis
    float xShake = drumShakeX + kickShakeX + snareShakeX;
    float yShake = drumShakeY + kickShakeY + snareShakeY;

    // Apply shake to UV coordinates
    vec2 shakenUV = uv + vec2(xShake, yShake);

    // Auto-oversample based on shake intensity to prevent black edges
    // Higher shake intensity = more oversampling needed
    float autoOversample = 1.0 + (shakeIntensity * 0.1); // 10% per intensity unit
    vec2 center = vec2(0.5);
    vec2 oversampledUV = (shakenUV - center) / autoOversample + center;

    // Sample the texture with oversampled coordinates
    vec3 color = texture(iChannel0, oversampledUV).rgb;

    // Add drum-reactive color flash (bright flash on drum hits)
    float drumFlash = getBeatMoment(totalDrumEnergy, drumTime);
    float kickFlash = getBeatMoment(kickLevel * beatIntensity, kickTime);
    float snareFlash = getBeatMoment(snareLevel * beatIntensity, snareTime);

    float totalFlash = 1.0 + (drumFlash + kickFlash * 0.8 + snareFlash * 0.6) * 0.3;
    color *= totalFlash;

    // Subtle vignette to enhance the effect
    vec2 vignetteCenter = uv - 0.5;
    float vignette = 1.0 - dot(vignetteCenter, vignetteCenter) * 0.2;
    color *= vignette;

    fragColor = vec4(color, 1.0);
}
