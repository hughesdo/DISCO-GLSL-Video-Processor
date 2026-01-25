#version 330

// ColorTrails - RADICAL NEW APPROACH
// Apply color effect AFTER blending current + trail
// This way trails are visible in the raw video, THEN we colorize everything

uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;    // Current video frame (RAW)
uniform sampler2D iChannel1;    // Previous shader OUTPUT (already colorized)
uniform int iFrame;

uniform float trailDecay;
uniform float trailStrength;
uniform float colorIntensity;
uniform float greenScreen;
uniform float greenThreshold;
uniform float debugMode;

in vec2 v_text;
out vec4 fragColor;

void main()
{
    vec2 uv = vec2(v_text.x, 1.0 - v_text.y);

    vec4 current = texture(iChannel0, uv);
    vec4 previous = texture(iChannel1, uv);

    // DEBUG MODES
    if (debugMode > 0.5 && debugMode < 1.5) {
        fragColor = vec4(previous.rgb, 1.0);
        return;
    }
    if (debugMode > 1.5) {
        float hasData = step(0.01, length(previous.rgb));
        fragColor = vec4(hasData, 0.0, 0.0, 1.0);
        return;
    }

    float decay = trailDecay > 0.01 ? trailDecay : 0.90;
    float strength = trailStrength > 0.01 ? trailStrength : 0.7;
    float colorMix = colorIntensity;
    float greenTh = greenThreshold > 0.01 ? greenThreshold : 0.9;

    // === KEY INSIGHT ===
    // previous.rgb is ALREADY colorized (from last frame's output)
    // current.rgb is RAW video
    //
    // Strategy: Blend RAW current with colorized previous, THEN colorize result
    // This creates temporal continuity in the trails

    // Fade the previous colorized output
    vec3 fadedPrevious = previous.rgb * decay;

    // Blend raw current frame with faded previous
    // strength controls how much trail persists
    vec3 blended = mix(current.rgb, fadedPrevious, strength);

    // Green screen check (on RAW current frame)
    float greenDist = length(current.rgb - vec3(0.0, 1.0, 0.0));
    bool isGreen = (greenScreen > 0.5) && (greenDist < greenTh);

    vec3 result;

    if (isGreen) {
        // Green area: show only the faded trail
        result = fadedPrevious;
    } else {
        // NOW apply psychedelic effect to the blended result
        vec3 psychedelic = normalize(vec3(1e-5) + fract(blended + blended));
        result = mix(psychedelic, blended, colorMix);
    }

    fragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}

