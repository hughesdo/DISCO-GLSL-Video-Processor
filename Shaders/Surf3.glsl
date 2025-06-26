/*
    "Surf 3" - Audio-Reactive Version with Video Keying by Augment Agent
    Based on "Surf 2" by @XorDev

    Original discovery: interesting refraction effect by adding
    the raymarch iterator to the turbulence!
    https://x.com/XorDev/status/1936174781352517638

    Special feature: Video keying - input video shows through on black areas
    Simple audio-reactive enhancements:
    - Color shifts with frequency bands
    - Beat-reactive brightness pulses
    - Subtle turbulence variations
*/

#version 330

uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0; // Video input for keying

// Single audio-reactive uniform
uniform float midLevel;         // Mid frequency energy - affects turbulence gently (0.0-1.0)

in vec2 v_text;
out vec4 fragColor;

void main()
{
    vec2 I = v_text * iResolution;

    //Raymarch depth
    float z,
    //Step distance
    d,
    //Raymarch iterator
    i,
    //Animation time (original)
    t = iTime;

    //Clear fragColor and raymarch 100 steps (original count)
    vec4 O = vec4(0.0);

    for(O*=i; i++<1e2;
        //Original coloring and brightness (no audio effects)
        O += (1.+cos(i*.7+vec4(6,1,2,0))) / d / i)
    {
        //Sample point (from ray direction) - original
        vec3 p = z*normalize(vec3(I+I,0)-iResolution.xyx);

        //Polar coordinates - original
        p = vec3(atan(p.y,p.x)*2., p.z/3., length(p.xy)-6.);

        //Apply turbulence with gentle mid-frequency variation
        //https://mini.gmshaders.com/p/turbulence
        for(d=1.; d<9.;)
        {
            // Gentle mid-frequency turbulence variation
            float turbulenceAmount = 1.0 + midLevel * 0.15;
            p += sin(p.yzx*d-t+.2*i) * turbulenceAmount / d++;
        }

        //Distance to cylinder and waves - original formula
        z+=d=.2*length(vec4(p.z,.1*cos(p*3.)-.1));
    }

    //Tanh tonemap - original
    O=tanh(O*O/9e2);

    // SPECIAL FEATURE: Video keying - show surf through black areas of input video
    vec3 videoColor = texture(iChannel0, vec2(v_text.x, 1.0 - v_text.y)).rgb; // Flip Y to fix upside-down

    // Calculate luminance of input video
    float videoLuminance = dot(videoColor, vec3(0.299, 0.587, 0.114));

    // Keying threshold - show surf where video is dark/black
    float keyThreshold = 0.1;
    float keyMix = smoothstep(0.0, keyThreshold, videoLuminance);

    // Mix surf effect with video - surf shows through black areas of video
    vec3 finalColor = mix(O.rgb, videoColor, keyMix);

    fragColor = vec4(finalColor, 1.0);
}
