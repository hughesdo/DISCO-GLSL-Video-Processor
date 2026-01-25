// ============================================
// BUFFER A - Video Input (unchanged from original)
// ============================================
// CHANNEL SETUP:
//   iChannel0 = Input Video (green screen footage)
//   iChannel1 = Buffer B (feedback)
// ============================================

// This buffer just passes through the video
// The original shader had this as the video input layer
void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord.xy / iResolution.xy;
    fragColor = texture(iChannel0, uv);
}
