# AmigaSinus Shader TODO List

This document tracks improvements made to AmigaSinus3.1 that should be applied to other AmigaSinus shaders.

## ✅ Completed in AmigaSinus3.1

### **1. Font Character Mapping Fixes**
- **Issue:** Wrong characters displaying (weird symbols instead of letters)
- **Fix:** Corrected texture coordinate calculation in `char()` function
- **Code:** `float y = float(ch/16);` instead of `float y = 15 - float(ch/16);`
- **Apply to:** AmigaSinus1, AmigaSinus2, AmigaSinus3

### **2. Upside-Down Text Fix**
- **Issue:** Characters rendering upside down
- **Fix:** Flip character rendering coordinates
- **Code:** `vec2 flipped_tp = vec2(tp.x, 1.0 - tp.y);`
- **Apply to:** AmigaSinus1, AmigaSinus2, AmigaSinus3

### **3. Dynamic Text Input System**
- **Issue:** Hardcoded text, no user input
- **Fix:** Backend text-to-macro conversion with regex replacement
- **Features:** User can enter custom text via web interface
- **Apply to:** AmigaSinus1, AmigaSinus2, AmigaSinus3

### **4. Text Length Limits Increased**
- **Issue:** Limited text input (200-400 characters)
- **Fix:** Increased maxLength to 2000-4000 characters in JSON
- **Apply to:** AmigaSinus1, AmigaSinus2, AmigaSinus3

### **5. GLSL Comment Quote Removal**
- **Issue:** Double quotes in comments causing compilation errors
- **Fix:** Removed quotes from text replacement comments
- **Code:** `// Text from user: {user_text}` instead of `// Text from user: "{user_text}"`
- **Apply to:** AmigaSinus1, AmigaSinus2, AmigaSinus3

### **6. Independent Scroll Speed Controls**
- **Issue:** Fixed scroll speed for all text layers
- **Fix:** Added `scrollSpeed1` and `scrollSpeed2` uniforms
- **Features:** Each text layer has independent speed control (0.1-3.0)
- **Apply to:** AmigaSinus1, AmigaSinus2, AmigaSinus3

### **7. Dynamic Scroll Length System**
- **Issue:** Text restarting before completion or long pauses
- **Fix:** Dynamic `textLength1` and `textLength2` based on actual text + 120 spaces
- **Features:** Text scrolls completely before restarting, no premature loops
- **Apply to:** AmigaSinus1, AmigaSinus2, AmigaSinus3

### **8. Patriotic Color Theme (AmigaSinus3.1 Specific)**
- **RGB Bars:** Changed from Red/Green/Blue to Red/White/Blue
- **Copper Bars:** Changed to alternating Red/Blue patriotic gradient
- **Plasma:** Red/White/Blue color palette, removed fade effects
- **Note:** This is AmigaSinus3.1 specific, may not apply to others

### **9. Video-Inside-Text Effect (AmigaSinus3.1 Specific)**
- **Feature:** Large text with user video displayed inside characters
- **Implementation:** Video masking through text shapes
- **Controls:** `fontSize` uniform for text size control
- **Note:** This is AmigaSinus3.1 specific, may not apply to others

### **10. Streaming Video Support (AmigaSinus3.1 Specific)**
- **Feature:** Real-time video streaming via iChannel0 instead of frame-based processing
- **Implementation:** `"streaming": true` flag in JSON config
- **Backend:** Automatic routing to `streaming_video_processor.py`
- **Benefits:** Real-time video-inside-text effect, reduced processing time
- **Fallback:** Frame-based processing if streaming fails
- **Memory Management:** Added garbage collection, frame validation, resource cleanup
- **Note:** This is AmigaSinus3.1 specific, may apply to future streaming-capable shaders

## 🔄 TODO: Apply to Other Shaders

### **Priority 1: Critical Fixes**
- [ ] **AmigaSinus1:** Apply font character mapping fix (#1)
- [ ] **AmigaSinus1:** Apply upside-down text fix (#2)
- [ ] **AmigaSinus2:** Apply font character mapping fix (#1)
- [ ] **AmigaSinus2:** Apply upside-down text fix (#2)
- [ ] **AmigaSinus3:** Apply font character mapping fix (#1)
- [ ] **AmigaSinus3:** Apply upside-down text fix (#2)

### **Priority 2: User Experience**
- [ ] **AmigaSinus1:** Apply dynamic scroll length system (#7)
- [ ] **AmigaSinus2:** Apply dynamic scroll length system (#7)
- [ ] **AmigaSinus3:** Apply dynamic scroll length system (#7)
- [ ] **AmigaSinus1:** Apply independent scroll speed controls (#6)
- [ ] **AmigaSinus2:** Apply independent scroll speed controls (#6)
- [ ] **AmigaSinus3:** Apply independent scroll speed controls (#6)

### **Priority 3: Text System**
- [ ] **AmigaSinus1:** Verify text length limits are increased (#4)
- [ ] **AmigaSinus2:** Verify text length limits are increased (#4)
- [ ] **AmigaSinus3:** Verify text length limits are increased (#4)
- [ ] **AmigaSinus1:** Verify GLSL comment quotes removed (#5)
- [ ] **AmigaSinus2:** Verify GLSL comment quotes removed (#5)
- [ ] **AmigaSinus3:** Verify GLSL comment quotes removed (#5)

### **Priority 4: Punctuation Support**
- [x] **AmigaSinus3.1:** Complete punctuation character macros added
- [ ] **AmigaSinus1, AmigaSinus2, AmigaSinus3:** Add complete punctuation character macros
- [x] **Characters added:** `"#$%&'()*[\]^_`{|}~·` (20 punctuation characters including middle dot)
- [ ] **Special characters:** Smart quotes, em-dash, etc.

## 📝 Implementation Notes

### **Font Character Mapping Fix**
```glsl
// BEFORE (wrong):
vec2 texCoord = 0.0625*(tp + vec2(ch - ch/16*16, 15 - ch/16));

// AFTER (correct):
float x = float(ch - ch/16*16);  // Column (0-15)
float y = float(ch/16);          // Row (0-15)
vec2 flipped_tp = vec2(tp.x, 1.0 - tp.y);
vec2 texCoord = 0.0625*(flipped_tp + vec2(x, y));
```

### **Dynamic Scroll Length**
```glsl
// Add uniforms:
uniform float textLength1;
uniform float textLength2;

// Update scroll calculations:
tp.x = 2.0*(tp.x -4.0 +mod(time*SCROLL_SPEED*scrollSpeed1, textLength1));
```

### **Backend Text Length Calculation**
```python
# In shader_video_processor.py:
text_len = len(user_text) + 120  # Add 120 spaces padding
self.extra_uniforms['textLength1'] = float(text_len)
```

## 🎯 Testing Checklist

When applying fixes to other shaders:
- [ ] Shader compiles without errors
- [ ] Characters display correctly (not weird symbols)
- [ ] Text is right-side up (not upside down)
- [ ] User text input works from web interface
- [ ] Text scrolls completely before restarting
- [ ] Scroll speed controls work independently
- [ ] Long text doesn't get cut off
- [ ] Short text doesn't have long pauses

## 📅 Last Updated
2025-06-29 - Added dynamic scroll length system and comprehensive TODO list
