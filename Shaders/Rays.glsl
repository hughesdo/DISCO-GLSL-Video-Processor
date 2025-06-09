#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// User-configurable uniforms (kept for compatibility, even if unused)
uniform float progress;
uniform float raySamples;
uniform float saturation;
uniform float baseIntensity;
uniform float colorShift;
uniform float waveAmplitude;
uniform float pulseSpeed;

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

void main()
{
    // Fix coordinate system – flip Y (same as before)
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;

    // Normalize to [0..1]
    vec2 uv = fragCoord / iResolution.xy;
    float RayScale = 1.0;

    // Use the uniform raySamples for iteration count
    float actualRaySamples = raySamples;

    // Start with a single texture lookup at the base UV
    vec4 col = texture(iChannel0, uv);

    // Ray-sampling loop only (no displacement, no vignette, no lighting changes)
    for(float i = 0.0; i < actualRaySamples; i++)
    {
        RayScale -= 0.0002;

        // Simple pulsing offset based on time
        uv -= abs(cos(iTime));
        uv *= RayScale;
        uv += abs(cos(iTime));

        // Accumulate a softened sample from the texture
        col += smoothstep(0.0, 0.8, texture(iChannel0, uv) * 0.2);
    }

    fragColor = col;
}
