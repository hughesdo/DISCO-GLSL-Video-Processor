#version 330

uniform float iTime;
uniform vec2 iResolution;
uniform sampler2D iChannel0; // wood_texture.jpg
uniform sampler2D iChannel1; // tablet_texture.jpg
uniform sampler2D iChannel2; // Video input
uniform sampler2D iChannel3; // wood_texture.jpg (fallback)

// Animation uniforms
uniform float animationSpeed;
uniform float pauseDuration;
uniform float cameraHeight;
uniform float zoomIntensity;

// Video transparency uniforms (simple version)
uniform float enableVideoTransparency;  // 0.0 = off, 1.0 = on
uniform float transparencyThreshold;    // Darkness threshold for transparency (0.0-1.0)

in vec2 v_text;
out vec4 fragColor;

#define pi 3.141593

// Camera variables
vec3 campos;
vec3 camtarget = vec3(0.0, 2.3, 0.0);
vec3 camdir;
float fov = 4.0;

// Scene constants
const vec3 tabPos = vec3(0.0, 2.3, 0.0);
const float tabWidth = 3.0;
const float tabHeight = 2.0;
const float tabletRounding = 0.3;
const float picWidth = 0.93;
const float picHeight = 0.96;

// Object IDs
#define SKY_OBJ    0
#define FLOOR_OBJ  1
#define TABLET_OBJ 2
#define IMAGE_OBJ  3
#define SPHERES_OBJ 4

// Tracing constants
const float normdelta = 0.002;
const float maxdist = 50.0;

// 2D vector rotation function
vec2 rotateVec(vec2 vect, float angle) {
    vec2 rv;
    rv.x = vect.x * cos(angle) - vect.y * sin(angle);
    rv.y = vect.x * sin(angle) + vect.y * cos(angle);
    return rv;
}

// Bezier curve interpolation function
vec3 bezierCurve(vec3 p0, vec3 p1, vec3 p2, vec3 p3, float t) {
    float u = 1.0 - t;
    float tt = t * t;
    float uu = u * u;
    float uuu = uu * u;
    float ttt = tt * t;

    return uuu * p0 + 3.0 * uu * t * p1 + 3.0 * u * tt * p2 + ttt * p3;
}

// Smooth Bezier curve camera animation with rotation
void animateCamera() {
    float t = iTime * animationSpeed;
    float cycle = pauseDuration + 4.0; // 4 seconds for full in/out movement
    float phase = mod(t, cycle);

    // Define Bezier control points for cinematic camera path
    vec3 startPos = vec3(-18.0, 12.0 + cameraHeight, 18.0);  // High, angled down
    vec3 controlPoint1 = vec3(-12.0, 9.0 + cameraHeight, 12.0);   // Smooth descent curve
    vec3 controlPoint2 = vec3(-6.0, 6.0 + cameraHeight, 6.0);     // Continue smooth approach
    vec3 endPos = vec3(-4.0, 3.5 + cameraHeight, 4.0);           // Lower, closer, front-facing

    // Calculate animation phase with yo-yo behavior
    float animPhase = 0.0;
    bool movingIn = true;

    if (phase > pauseDuration) {
        float moveTime = phase - pauseDuration;
        float halfCycle = 2.0; // 2 seconds each direction

        if (moveTime < halfCycle) {
            // Moving in (start to end)
            animPhase = moveTime / halfCycle;
            movingIn = true;
        } else {
            // Moving out (end to start) - yo-yo back
            animPhase = 1.0 - ((moveTime - halfCycle) / halfCycle);
            movingIn = false;
        }

        // Apply smooth easing for cinematic feel
        animPhase = smoothstep(0.0, 1.0, animPhase);
        animPhase = smoothstep(0.0, 1.0, animPhase); // Double smoothstep for extra smoothness
    }

    // Calculate base camera position using Bezier curve
    vec3 baseCampos = bezierCurve(startPos, controlPoint1, controlPoint2, endPos, animPhase);

    // Calculate rotation around tablet (Y-axis rotation)
    vec3 tabletCenter = vec3(0.0, 2.3, 0.0);

    // Rotation amount: 45 degrees total rotation during movement
    float maxRotation = radians(45.0); // 45 degrees in radians
    float rotationPhase = animPhase;

    // Direction-dependent rotation
    float rotationAngle;
    if (movingIn) {
        // Forward zoom: counter-clockwise rotation (negative angle)
        // animPhase goes from 0.0 to 1.0, so rotation goes from 0° to -45°
        rotationAngle = -maxRotation * rotationPhase;
    } else {
        // Reverse zoom: clockwise rotation back to start
        // animPhase goes from 1.0 to 0.0, so rotation should go from -45° back to 0°
        rotationAngle = -maxRotation * rotationPhase;
    }

    // Apply rotation around tablet center
    vec3 offsetFromTablet = baseCampos - tabletCenter;

    // Rotate around Y-axis
    float cosAngle = cos(rotationAngle);
    float sinAngle = sin(rotationAngle);

    vec3 rotatedOffset = vec3(
        offsetFromTablet.x * cosAngle - offsetFromTablet.z * sinAngle,
        offsetFromTablet.y, // Y unchanged for vertical axis rotation
        offsetFromTablet.x * sinAngle + offsetFromTablet.z * cosAngle
    );

    // Final camera position with rotation applied
    campos = tabletCenter + rotatedOffset;

    // Smooth camera target adjustment for proper tablet framing
    vec3 baseTarget = vec3(0.0, 2.3, 0.0);
    vec3 closeTarget = vec3(0.0, 2.0, 0.0); // Slightly lower when close
    camtarget = mix(baseTarget, closeTarget, animPhase * 0.3); // Subtle target adjustment

    // Calculate smooth camera direction (always looking at tablet)
    camdir = normalize(camtarget - campos);
}

// Distance mapping functions
float map_floor(vec3 pos) {
    return pos.y;
}

float map_tablet(vec3 pos, vec3 orig, vec3 size, float flatn, float r) {
    pos.z *= flatn;
    return length(max(abs(pos - orig) - size, 0.0)) - r;
}

// Distance mapping of spheres orbiting around the TV/tablet in elliptical paths
float map_spheres(vec3 pos) {
    // Center orbit around the tablet position
    vec3 tabletCenter = vec3(0.0, 2.3, 0.0);
    pos -= tabletCenter;

    // Create multiple spheres at different orbital positions
    float minDist = 1000.0;

    // Sphere 1: Elliptical orbit around tablet
    vec3 pos1 = pos;
    float angle1 = iTime * 0.3; // Slower rotation for cinematic effect
    pos1.x = pos.x * cos(angle1) - pos.z * sin(angle1);
    pos1.z = pos.x * sin(angle1) + pos.z * cos(angle1);
    // Elliptical orbit: wider horizontally, narrower in depth
    pos1.x -= 4.5; // Horizontal radius
    pos1.z *= 1.5; // Compress Z for elliptical shape
    float dist1 = length(pos1) - 0.3; // Smaller sphere radius
    minDist = min(minDist, dist1);

    // Sphere 2: Opposite side of orbit
    vec3 pos2 = pos;
    float angle2 = iTime * 0.3 + 3.14159; // 180 degrees offset
    pos2.x = pos.x * cos(angle2) - pos.z * sin(angle2);
    pos2.z = pos.x * sin(angle2) + pos.z * cos(angle2);
    pos2.x -= 4.5;
    pos2.z *= 1.5;
    float dist2 = length(pos2) - 0.3;
    minDist = min(minDist, dist2);

    // Sphere 3: Different orbital plane (vertical ellipse)
    vec3 pos3 = pos;
    float angle3 = iTime * 0.4; // Slightly different speed
    pos3.y = pos.y * cos(angle3) - pos.z * sin(angle3);
    pos3.z = pos.y * sin(angle3) + pos.z * cos(angle3);
    pos3.y -= 2.0; // Vertical radius
    pos3.z -= 3.0; // Forward offset
    float dist3 = length(pos3) - 0.25;
    minDist = min(minDist, dist3);

    return minDist;
}

vec2 map(vec3 pos) {
    vec2 res = vec2(map_floor(pos), FLOOR_OBJ);
    res = res.x < map_tablet(pos, tabPos, vec3(tabWidth, tabHeight, 0.1), 5.0, tabletRounding) ?
          res : vec2(map_tablet(pos, tabPos, vec3(tabWidth, tabHeight, 0.1), 5.0, tabletRounding), TABLET_OBJ);

    // Add rotating spheres orbiting around the TV/tablet
    float sphereDist = map_spheres(pos);
    res = res.x < sphereDist ? res : vec2(sphereDist, SPHERES_OBJ);

    return res;
}

// Ray tracing
vec2 trace(vec3 cam, vec3 ray, float maxdist) {
    float t = 0.15;
    float objnr = 0.0;
    for (int i = 0; i < 300; ++i) {
        vec3 pos = cam + t * ray;
        vec2 res = map(pos);
        float dist = res.x;
        if (dist > maxdist || abs(dist) < 0.0001) break;
        t += dist * 0.1;
        objnr = res.y;
    }
    return vec2(t, objnr);
}

// Normal calculation
vec3 getNormal(vec3 pos, float e) {
    vec2 q = vec2(0.0, e);
    return normalize(vec3(
        map(pos + q.yxx).x - map(pos - q.yxx).x,
        map(pos + q.xyx).x - map(pos - q.xyx).x,
        map(pos + q.xxy).x - map(pos - q.xxy).x
    ));
}

// Colors with texture support
vec3 floor_color(vec3 pos) {
    vec3 texColor = texture(iChannel0, pos.xz * 0.1).rgb;
    if (length(texColor) < 0.1) {
        texColor = vec3(0.6, 0.4, 0.2);
    }
    return texColor;
}

vec3 tablet_color(vec3 pos) {
    vec3 texColor = texture(iChannel1, pos.xy * 0.1).rgb;
    if (length(texColor) < 0.1) {
        texColor = vec3(0.15);
    }
    return texColor;
}

vec3 image_color(vec3 pos) {
    // WORKING video sampling (restored)
    vec2 videoUV = vec2(
        (pos.x - tabPos.x) / (tabWidth * picWidth) * 0.5 + 0.5,
        (pos.y - tabPos.y) / (tabHeight * picHeight) * 0.5 + 0.5
    );

    // Flip Y for correct video orientation
    videoUV.y = 1.0 - videoUV.y;
    
    // Sample video texture
    vec3 videoColor = texture(iChannel2, videoUV).rgb;
    
    // SIMPLE transparency feature
    if (enableVideoTransparency > 0.5) {
        // Dark areas become transparent (blend with blue)
        float brightness = length(videoColor);
        if (brightness < transparencyThreshold) {
            float alpha = brightness / transparencyThreshold;
            videoColor = mix(vec3(0.2, 0.4, 0.8), videoColor, alpha);
        }
    } else {
        // Original behavior - fallback for failed video
        if (length(videoColor) < 0.1) {
            videoColor = vec3(0.2, 0.4, 0.8);
        }
    }
    
    return videoColor;
}

vec3 spheres_color(vec3 pos, vec3 norm, vec3 rayDir) {
    // Chrome/mirror material - highly reflective
    vec3 baseColor = vec3(0.8, 0.85, 0.9); // Slight blue tint for chrome

    // Calculate reflection
    vec3 reflected = reflect(rayDir, norm);

    // Simple environment reflection (sky color based on reflection direction)
    vec3 envColor = vec3(0.1, 0.35, 0.7); // Sky color

    // Vary environment color based on reflection direction
    if (reflected.y > 0.5) {
        envColor = vec3(0.2, 0.5, 0.9); // Brighter sky for upward reflections
    } else if (reflected.y < -0.2) {
        envColor = vec3(0.3, 0.3, 0.4); // Darker for downward reflections
    }

    // High reflectivity - 80% reflection, 20% base color
    return mix(baseColor, envColor, 0.8);
}

vec3 sky_color(vec3 ray) {
    return vec3(0.1, 0.35, 0.7);
}

vec3 getColor(vec3 norm, vec3 pos, int objnr, vec3 rayDir) {
    if (objnr == FLOOR_OBJ) return floor_color(pos);
    if (objnr == TABLET_OBJ) return tablet_color(pos);
    if (objnr == IMAGE_OBJ) return image_color(pos);
    if (objnr == SPHERES_OBJ) return spheres_color(pos, norm, rayDir);
    return sky_color(rayDir);
}

// Simple lighting
vec3 lampsShading(vec3 norm, vec3 pos, vec3 ocol, int objnr) {
    vec3 lampPos = vec3(0.0, 5.0, 5.0);
    vec3 lampColor = vec3(1.0);
    vec3 pl = normalize(lampPos - pos);
    vec3 col = ocol * lampColor * max(0.0, dot(norm, pl));
    col += vec3(0.2);
    return col;
}

// Camera ray direction
vec3 GetCameraRayDir(vec2 vWindow, vec3 vCameraDir, float fov) {
    vec3 vForward = normalize(vCameraDir);
    vec3 vRight = normalize(cross(vec3(0.0, 1.0, 0.0), vForward));
    vec3 vUp = normalize(cross(vForward, vRight));
    return normalize(vWindow.x * vRight + vWindow.y * vUp + vForward * fov);
}

// Render function
vec4 render(vec2 fragCoord) {
    vec2 uv = fragCoord.xy / iResolution.xy;
    uv = uv * 2.0 - 1.0;
    uv.x *= iResolution.x / iResolution.y;
    vec3 ray = GetCameraRayDir(uv, camdir, fov);

    vec2 tr = trace(campos, ray, maxdist);
    float tx = tr.x;
    int objnr = int(tr.y);
    vec3 col;
    vec3 pos = campos + tx * ray;

    if (tx < maxdist) {
        // CRITICAL: Video area detection (this determines where video appears)
        if (objnr == TABLET_OBJ && abs(pos.x - tabPos.x) < tabWidth * picWidth && abs(pos.y - tabPos.y) < tabHeight * picHeight) {
            objnr = IMAGE_OBJ;
        }
        vec3 norm = getNormal(pos, normdelta);
        col = getColor(norm, pos, objnr, ray);
        col = lampsShading(norm, pos, col, objnr);
    } else {
        objnr = SKY_OBJ;
        col = sky_color(ray);
    }

    return vec4(col, 1.0);
}

void main() {
    // Use original coordinates (correct scene orientation)
    vec2 fragCoord = vec2(v_text.x * iResolution.x, v_text.y * iResolution.y);
    animateCamera();
    vec4 finalColor = render(fragCoord);

    // Debug fallback
    if (length(finalColor.rgb) < 0.1) {
        vec2 uv = v_text;
        finalColor.rgb = vec3(uv, 0.5);
        finalColor.a = 1.0;
    }

    fragColor = finalColor;
}
