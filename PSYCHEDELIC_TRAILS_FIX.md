# PsychedelicTrails Shader Fix - Trail Effect Not Working

## Problem
The PsychedelicTrails multi-buffer shader was showing edge detection and colors but **no motion trails**. The feedback buffer system was not accumulating previous frames.

## Root Cause
**Critical Bug Found:** The multi-buffer rendering system was NOT clearing the framebuffer before rendering to it each frame.

### Technical Explanation
In a double-buffered feedback system:
- Buffer has 2 textures: `texture[0]` and `texture[1]`
- Each frame, we alternate which texture we write to
- We read from the texture we wrote to LAST frame (for feedback)

**The Bug:**
```python
# streaming_video_processor.py, line ~596 (BEFORE FIX)
target_fbo.use()
vao.render()  # ❌ Rendering without clearing first!
```

**What was happening:**
- Frame 0: Write to texture[1], texture[0] is cleared (from init)
- Frame 1: Write to texture[0], but it still contains OLD data from init
- Frame 2: Write to texture[1], but it still contains data from Frame 0
- Frame 3: Write to texture[0], but it still contains data from Frame 1
- Result: Each texture accumulates every OTHER frame, creating a mess

**The Fix:**
```python
# streaming_video_processor.py, line ~596 (AFTER FIX)
target_fbo.use()
self.ctx.clear(0.0, 0.0, 0.0, 1.0)  # ✅ Clear before rendering!
vao.render()
```

Now each frame starts with a clean slate, and the feedback comes ONLY from the shader's texture sampling of the previous frame (via iChannel0 in BufferB).

## Additional Fixes Applied

### 1. Fixed Uniform Overwriting (streaming_video_processor.py)
**Problem:** `_set_shader_uniforms()` was overwriting iChannel0 and iChannel1 uniforms even for multi-buffer shaders, breaking the carefully configured channel bindings.

**Fix:** Added check to skip channel uniform setting for multi-buffer shaders:
```python
if not self.is_multi_buffer:
    # Only set channel uniforms for single-file shaders
    if 'iChannel0' in prog:
        prog['iChannel0'].value = 0
```

### 2. Added Texture Filtering
Added LINEAR filtering to video textures for smoother sampling:
```python
tex.filter = (moderngl.LINEAR, moderngl.LINEAR)
```

### 3. Enhanced Debug Logging
Added detailed logging for frames 0 and 1 to trace texture bindings and verify correct operation.

## How to Test

### Option 1: Use the Test Script
```bash
python test_psychedelic_trails.py
```
This creates a test video with a moving white square. Process it with PsychedelicTrails shader in Preview Mode to verify trails appear.

### Option 2: Manual Testing
1. Open http://localhost:8000
2. Upload any video and audio file
3. Select "PsychedelicTrails" from shader dropdown
4. Enable Preview Mode (30-60 frames for quick test)
5. Click "Process Video"

### Expected Results
✅ **With Fix (Trails Working):**
- Colorful trails follow moving edges
- Trails persist for several frames before fading
- Psychedelic rainbow colors swirl and accumulate
- Audio reactivity affects trail colors and brightness

❌ **Without Fix (Trails Broken):**
- Only edge detection colors visible
- No persistence or accumulation
- Colors appear only on current frame edges
- No motion blur or trailing effect

## Technical Details: Multi-Buffer System

### Buffer Configuration (shader_config.json)
```json
"PsychedelicTrails": {
  "multiBuffer": true,
  "buffers": {
    "BufferA": {
      "file": "PsychedelicTrails/BufferA.glsl",
      "channels": {"iChannel0": "video"}
    },
    "BufferB": {
      "file": "PsychedelicTrails/BufferB.glsl",
      "channels": {
        "iChannel0": "BufferB",  // Self-feedback!
        "iChannel1": "BufferA"
      }
    },
    "Image": {
      "file": "PsychedelicTrails/Image.glsl",
      "channels": {
        "iChannel0": "BufferA",
        "iChannel1": "BufferB"
      }
    }
  },
  "renderOrder": ["BufferA", "BufferB", "Image"]
}
```

### Render Flow
1. **BufferA**: Passes through video → writes to BufferA texture
2. **BufferB**: 
   - Reads video from BufferA (iChannel1)
   - Reads own previous frame (iChannel0 = BufferB)
   - Detects edges, applies psychedelic colors
   - Combines with decayed feedback: `result = feedback * 0.96 + newColors`
   - Writes to BufferB texture
3. **Image**: Composites BufferA and BufferB → final output

## Files Modified
- `streaming_video_processor.py` - Added FBO clear, fixed uniform handling
- `main.py` - Updated shader listing for multi-buffer folders
- `test_psychedelic_trails.py` - Created test utility (NEW)

## Server Auto-Reload
The server runs with `--reload` flag, so changes are automatically applied. Just refresh your browser and try processing a video again.

