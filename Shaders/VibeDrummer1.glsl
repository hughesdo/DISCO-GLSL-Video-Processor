#version 330 core

// VibeDrummer1 - Beat-reactive video effect shader
// Combines video input with audio-reactive beat detection and visual effects

uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0; // Video input texture
uniform sampler2D iChannel1; // Audio texture

out vec4 fragColor;

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord/iResolution.xy;
    uv.y = 1.0 - uv.y; // Flip video vertically
    vec3 inColor = texture(iChannel0, uv).xyz;

    // Beat detection from audio (iChannel1)
    // Sample low frequency range for bass/kick detection
    float bassLevel = 0.0;
    for(float i = 0.0; i < 8.0; i++) {
        bassLevel += texture(iChannel1, vec2(i/512.0, 0.0)).x;
    }
    bassLevel /= 8.0;

    // Create beat threshold - adjust sensitivity here
    float beatThreshold = 0.15;
    float beatIntensity = smoothstep(beatThreshold, beatThreshold + 0.1, bassLevel);

    // Beat timing - creates pulses when beats are detected
    float beatPulse = beatIntensity * (1.0 + sin(iTime * 20.0) * 0.5);

    // Base animation always runs, beats add extra movement
    float baseTime = iTime * 0.3; // Slower base animation
    float beatTime = iTime * beatPulse;
    float animTime = baseTime + beatTime;

    uv.x *= iResolution.x/iResolution.y;

    // Scale effect based on beat intensity
    float scaleMultiplier = 20.0 + (5.0 * beatIntensity);
    uv *= scaleMultiplier;

    // Modified calculations with beat-reactive timing
    float r = distance(uv*sin(animTime*.2), inColor.xy*vec2(sin(animTime*2.0), sin(animTime)*.1));
    float g = distance(-uv, inColor.xz*vec2(inColor.x, inColor.y));
    float b = distance(uv, inColor.zy*vec2(r, sin(animTime)));

    // Beat-reactive value calculation
    float value = abs(sin(r+animTime) + sin(g+animTime) + sin(b+animTime) + sin(uv.x+animTime) + cos(uv.y+animTime));
    value *= 64.0 * (1.0 + beatIntensity);

    r /= value;
    g /= value/(sin(animTime)*.5+.5);
    b /= value;

    // Add beat flash effect
    vec3 beatColor = vec3(beatIntensity * 0.2);
    vec3 rgb = vec3(r,g,b) + (inColor/15.) + beatColor;

    fragColor = vec4(rgb, 1.0);
}

void main() {
    mainImage(fragColor, gl_FragCoord.xy);
}
