#version 330

// Standard uniforms that your processor provides
uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0;

// User-configurable uniforms for 3D control
uniform float cameraSpeed;      // Speed of camera animation
uniform float rotationAmount;   // Amount of rotation movement
uniform float fovVariation;     // Field of view variation
uniform float colorIntensity;   // Color brightness multiplier
uniform float glowStrength;     // Glow effect strength
uniform float timeSpeed;        // Overall animation speed
uniform float starDensity;      // Star field density
uniform float boxSize;          // Size of the video display box

// Input/output for fragment shader
in vec2 v_text;
out vec4 fragColor;

const float PI = 3.1415926;

// Distance function for a box (from Shadertoy)
float sdBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

// Union operation for combining shapes
vec2 opU(vec2 a, vec2 b) {
    return a.x < b.x ? a : b;
}

// Camera setup function
mat3 setCamera(in vec3 ro, in vec3 ta, float cr) {
    vec3 cw = normalize(ta - ro);
    vec3 cp = vec3(sin(cr), cos(cr), 0.0);
    vec3 cu = normalize(cross(cw, cp));
    vec3 cv = cross(cu, cw);
    return mat3(cu, cv, cw);
}

// Easing functions from easings.net
float outPow(float x, float p) {
    x = clamp(x, 0.0, 1.0);
    return 1.0 - pow(1.0 - x, p);
}

float inPow(float x, float p) {
    x = clamp(x, 0.0, 1.0);
    return pow(x, p);
}

float outElastic(float x) {
    const float c4 = (2.0 * PI) / 3.0;
    return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * c4) + 1.0;
}

// Star field generation
float stars(vec3 p, float t) {
    float d = 9999.9;
    for (float i = 0.0; i < 4.0; i++) {
        vec3 offset = vec3(i * 1.4, i * 1.2, i * -0.5) * starDensity;
        float grid = length(mod(p + offset, 4.0) - 2.0);
        d = min(grid - 0.08, d);
    }
    return d;
}

// Scene mapping function - defines the 3D geometry
vec2 map(vec3 p, float t) {
    // Video display box
    vec2 res = vec2(sdBox(p + vec3(0.0, 0.0, 0.1), vec3(boxSize, boxSize, 0.05)), 1.5);
    // Star field
    res = opU(res, vec2(stars(p, t), 0.5));
    return res;
}

void main()
{
    // Fix coordinate system - flip Y coordinate
    vec2 correctedUV = vec2(v_text.x, 1.0 - v_text.y);
    vec2 fragCoord = correctedUV * iResolution;
    
    vec2 uv = fragCoord / iResolution.xy;
    vec2 q = (fragCoord.xy - 0.5 * iResolution.xy) / iResolution.y;
    
    // Apply time speed multiplier
    float animTime = iTime * timeSpeed;
    
    float mod2 = mod(animTime, 2.0);
    float mod4 = mod(animTime, 4.0);
    
    // Main camera animation with user controls
    float xrot = (4.0 - outElastic(0.3 * mod4) * 4.0) * rotationAmount;
    float yrot = (16.0 - outPow(mod4 * 2.0, 3.0) * 16.0 - inPow(mod2 - 1.0, 5.0) * 16.0) * rotationAmount;
    float zrot = mod4 > 2.0
        ? (8.0 - outPow(mod2, 4.0) * 8.0) * rotationAmount
        : sin(animTime * PI) * 0.5 * rotationAmount;
    
    // Flip motion every 2 iterations
    if (mod(animTime, 8.0) > 4.0) {
        xrot *= -1.0;
        yrot *= -1.0;
        zrot *= -1.0;
    }
    
    // Apply camera speed and FOV variation
    xrot *= cameraSpeed;
    yrot *= cameraSpeed;
    zrot *= cameraSpeed;
    
    float fov = (sin(animTime * PI) * fovVariation + 0.7);
    vec3 ro = vec3(xrot, yrot, fov);
    mat3 ca = setCamera(ro, vec3(0.0), zrot);
    vec3 rd = ca * normalize(vec3(q, fov));

    // Raymarching with configurable glow
    vec2 h; 
    vec3 p;
    float t = 0.1;
    const int iters = 20;
    const float tmax = 22.0;
    
    for (int i = 0; i < iters && t < tmax; i++) {
        p = ro + rd * t;
        h = map(p, animTime);
        if (abs(h.x) < 0.001) {
            break;
        }
        t += h.x;
    }
    
    // Color generation with user controls
    vec4 red = vec4(1.0, uv.y, 0.5, 1.0) * colorIntensity;
    vec4 blu = vec4(0.0, uv.y, 1.0, 1.0) * colorIntensity;
    float fog = min(10.0, (2.0 + 6.0 * mod2) * glowStrength) / t;
    vec4 color = (mod4 > 2.0 ? blu : red) * fog;
    
    if (h.y > 1.0) {
        // Video display on the 3D box
        vec2 size = vec2(textureSize(iChannel0, 0));
        vec2 videoUV = vec2(p.x * size.y / size.x, p.y);
        fragColor = texture(iChannel0, 0.5 + videoUV);
    } else {
        // Background and stars
        fragColor = color;
    }
}
