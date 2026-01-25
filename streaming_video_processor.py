# streaming_video_processor.py
import cv2
import numpy as np
from pathlib import Path
import moderngl
import tempfile
import logging
import json
import librosa
import ffmpeg
from PIL import Image
import gc

logger = logging.getLogger(__name__)

class StreamingVideoProcessor:
    def __init__(self, video_path, audio_path, shader_path, output_path,
                 extra_uniforms={}, progress_tracker=None, audio_settings=None,
                 max_frames=None, text_inputs={}):
        """
        Streamlined video processor that streams video directly to shaders without frame extraction.
        
        Args:
            video_path: Path to input video file
            audio_path: Path to main audio file
            shader_path: Path to GLSL shader file
            output_path: Path for output video
            extra_uniforms: Dict of uniform name -> value for shader
            progress_tracker: Optional progress tracker for real-time updates
            audio_settings: Dict with audio reactivity settings
            max_frames: Optional limit on number of frames to process (for preview mode)
        """
        self.video_path = Path(video_path)
        self.audio_path = Path(audio_path)
        self.shader_path = Path(shader_path)
        self.output_path = Path(output_path)
        self.extra_uniforms = extra_uniforms
        self.text_inputs = text_inputs
        self.progress_tracker = progress_tracker
        self.max_frames = max_frames

        # Get input video dimensions to match output
        self.base_resolution = self._get_video_dimensions()
        self.frame_rate = self._get_video_fps()

        # Screen shake settings
        self.enable_screen_shake = True
        self.shake_oversample = 1.2

        # Audio reactivity settings
        self.audio_settings = audio_settings or {
            'beat_sensitivity': 1.0,
            'bass_response': 1.0,
            'mid_response': 1.0,
            'treble_response': 1.0,
            'reactivity_preset': 'moderate'
        }

        # Load shader configuration
        self.shader_config = self._load_shader_config()
        self.texture_cache = {}

        # Merge shader config uniforms with extra_uniforms (extra_uniforms takes precedence)
        if 'uniforms' in self.shader_config:
            config_uniforms = self.shader_config['uniforms']
            for key, value in config_uniforms.items():
                if key not in self.extra_uniforms:
                    # Handle object format {value: X, min: Y, max: Z, step: W}
                    if isinstance(value, dict) and 'value' in value:
                        actual_value = value['value']
                    else:
                        actual_value = value
                    self.extra_uniforms[key] = actual_value
                    logger.info(f"Applied config uniform: {key} = {actual_value}")

        # Feedback buffer system for temporal effects (single-file shaders)
        self.needs_feedback_buffer = self.shader_config.get('needsFeedbackBuffer', False)
        self.feedback_textures = [None, None]  # Double-buffered feedback textures
        self.feedback_fbos = [None, None]      # Framebuffers for feedback rendering
        self.current_feedback_index = 0        # Tracks which buffer to read/write

        # Multi-buffer shader system (Shadertoy-style BufferA, BufferB, Image)
        self.is_multi_buffer = self.shader_config.get('multiBuffer', False)
        self.multi_buffer_programs = {}       # buffer_name -> compiled shader program
        self.multi_buffer_fbos = {}           # buffer_name -> framebuffer
        self.multi_buffer_textures = {}       # buffer_name -> [tex0, tex1] for double-buffering
        self.multi_buffer_indices = {}        # buffer_name -> current index (0 or 1)
        self.multi_buffer_vaos = {}           # buffer_name -> vertex array object

        # Check if shader needs oversized rendering for screen shake
        self.needs_oversized_rendering = self._check_if_shake_shader()
        if self.needs_oversized_rendering:
            self.resolution = (int(self.base_resolution[0] * self.shake_oversample),
                             int(self.base_resolution[1] * self.shake_oversample))
            logger.info(f"Using oversized rendering for screen shake: {self.resolution}")
        else:
            self.resolution = self.base_resolution

        # Initialize video capture
        self.cap = None
        self.total_frames = 0
        self.video_fps = 30  # Will be updated from actual video

    def _get_video_dimensions(self):
        """Get input video dimensions (width, height)"""
        try:
            cap = cv2.VideoCapture(str(self.video_path))
            if cap.isOpened():
                width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
                height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
                cap.release()

                if width > 0 and height > 0:
                    logger.info(f"Input video dimensions: {width}x{height}")
                    return (width, height)
                else:
                    logger.warning(f"Invalid video dimensions: {width}x{height}, using default 1280x720")
                    return (1280, 720)
            else:
                logger.warning(f"Could not open video file: {self.video_path}, using default 1280x720")
                return (1280, 720)
        except Exception as e:
            logger.warning(f"Failed to get video dimensions: {e}, using default 1280x720")
            return (1280, 720)

    def _get_video_fps(self):
        """Get input video frame rate"""
        try:
            cap = cv2.VideoCapture(str(self.video_path))
            if cap.isOpened():
                fps = cap.get(cv2.CAP_PROP_FPS)
                cap.release()

                if fps > 0 and fps <= 120:
                    logger.info(f"Input video FPS: {fps}")
                    return fps
                else:
                    logger.warning(f"Invalid video FPS: {fps}, using default 30")
                    return 30
            else:
                logger.warning(f"Could not open video file: {self.video_path}, using default 30 FPS")
                return 30
        except Exception as e:
            logger.warning(f"Failed to get video FPS: {e}, using default 30")
            return 30

    def _load_shader_config(self):
        """Load shader configuration for texture and uniform information"""
        try:
            config_path = Path("Shaders/shader_config.json")
            if config_path.exists():
                with open(config_path, 'r') as f:
                    config = json.load(f)

                # Try shader filename first (e.g., "MyShader.glsl")
                shader_name = self.shader_path.name
                if shader_name in config:
                    logger.info(f"Loaded configuration for shader: {shader_name}")
                    return config[shader_name]

                # For multi-buffer shaders, the path might be a folder name without extension
                # or the folder might be the parent of the shader files
                shader_name_no_ext = self.shader_path.stem  # Remove .glsl extension if present
                if shader_name_no_ext in config:
                    logger.info(f"Loaded configuration for shader (no ext): {shader_name_no_ext}")
                    return config[shader_name_no_ext]

                # Check if shader_path IS a folder (multi-buffer shader)
                if self.shader_path.is_dir() and self.shader_path.name in config:
                    logger.info(f"Loaded configuration for multi-buffer shader folder: {self.shader_path.name}")
                    return config[self.shader_path.name]

                logger.info(f"No specific configuration found for shader: {shader_name}")
            else:
                logger.warning("Shader configuration file not found")
        except Exception as e:
            logger.warning(f"Failed to load shader configuration: {e}")
        return {}

    def _check_if_shake_shader(self):
        """Check if the current shader needs oversized rendering for screen shake"""
        shader_name = self.shader_path.name
        shake_shaders = ['EasyBeats.glsl', 'BeatDropShake.glsl', 'CameraShake.glsl']
        return shader_name in shake_shaders

    def _init_video_capture(self):
        """Initialize video capture with OpenCV"""
        try:
            self.cap = cv2.VideoCapture(str(self.video_path))
            if not self.cap.isOpened():
                raise Exception(f"Could not open video file: {self.video_path}")

            # Get video properties
            self.total_frames = int(self.cap.get(cv2.CAP_PROP_FRAME_COUNT))
            self.video_fps = self.cap.get(cv2.CAP_PROP_FPS)

            # Validate frame rate
            if self.video_fps <= 0 or self.video_fps > 120:
                logger.warning(f"Invalid video FPS: {self.video_fps}, defaulting to 30")
                self.video_fps = 30

            # Update frame_rate for output to match input
            self.frame_rate = self.video_fps

            # Apply frame limit for preview mode
            if self.max_frames:
                self.total_frames = min(self.total_frames, self.max_frames)
                logger.info(f"Preview mode: limiting to {self.total_frames} frames")

            logger.info(f"Video: {self.total_frames} frames at {self.video_fps} FPS")

        except Exception as e:
            logger.error(f"Failed to initialize video capture: {e}")
            raise

    def _process_amiga_sinus_text(self, shader_source):
        """Process text replacement for AmigaSinus shaders"""
        from text_to_sinus_converter import text_to_spaced_sinus, text_to_glsl_macros
        import re

        # For AmigaSinus1: replace scrollText
        if 'AmigaSinus1' in str(self.shader_path) and 'scrollText' in self.text_inputs:
            user_text = self.text_inputs['scrollText']
            logger.info(f"Converting AmigaSinus1 text: '{user_text}'")

            # Convert user text to spaced format
            spaced_text = text_to_spaced_sinus(user_text)
            logger.info(f"Spaced text: '{spaced_text}'")

            # Convert to GLSL macros
            macro_string = text_to_glsl_macros(spaced_text)
            logger.info(f"GLSL macros: {macro_string}")

            # Replace the hardcoded text in shader
            old_pattern = r'// Dynamic text from user input.*?\n.*?_[A-Za-z0-9_ ]*'
            new_text = f'// Dynamic text from user input: {user_text}\n    {macro_string}'

            shader_source = re.sub(old_pattern, new_text, shader_source, flags=re.DOTALL)
            logger.info("AmigaSinus1 text replacement completed")

        # For AmigaSinus2: replace 3 text layers
        elif 'AmigaSinus2' in str(self.shader_path):
            logger.info("Processing AmigaSinus2 text replacement")

            # Replace scrollText1 (header)
            if 'scrollText1' in self.text_inputs:
                user_text = self.text_inputs['scrollText1']
                spaced_text = text_to_spaced_sinus(user_text)
                macro_string = text_to_glsl_macros(spaced_text)

                # Simple placeholder pattern that should definitely match
                old_pattern = r'// PLACEHOLDER_TEXT_1\n  _T _E _S _T'
                new_text = f'// Header text from user: {user_text}\n  {macro_string}'
                shader_source = re.sub(old_pattern, new_text, shader_source, flags=re.DOTALL)
                logger.info(f"AmigaSinus2 scrollText1 replaced: '{user_text}'")

            # Replace scrollText2 (main)
            if 'scrollText2' in self.text_inputs:
                user_text = self.text_inputs['scrollText2']
                spaced_text = text_to_spaced_sinus(user_text)
                macro_string = text_to_glsl_macros(spaced_text)

                old_pattern = r'// Main scroll text - using macro system.*?\n.*?_H _e _l _l _o.*?_exc'
                new_text = f'// Main text from user: {user_text}\n  {macro_string}'
                shader_source = re.sub(old_pattern, new_text, shader_source, flags=re.DOTALL)
                logger.info(f"AmigaSinus2 scrollText2 replaced: '{user_text}'")

            # Replace scrollText3 (bottom)
            if 'scrollText3' in self.text_inputs:
                user_text = self.text_inputs['scrollText3']
                spaced_text = text_to_spaced_sinus(user_text)
                macro_string = text_to_glsl_macros(spaced_text)

                old_pattern = r'// Bottom text - using macro system.*?\n.*?_D _I _S _C _O.*?_s'
                new_text = f'// Bottom text from user: {user_text}\n  {macro_string}'
                shader_source = re.sub(old_pattern, new_text, shader_source, flags=re.DOTALL)
                logger.info(f"AmigaSinus2 scrollText3 replaced: '{user_text}'")

        # For AmigaSinus3 and AmigaSinus3.1: replace 2 text layers
        elif 'AmigaSinus3' in str(self.shader_path):
            logger.info("Processing AmigaSinus3 text replacement")

            # For AmigaSinus3.1, calculate dynamic text lengths (total of all chunks)
            if 'AmigaSinus3.1' in str(self.shader_path):
                if 'scrollText1' in self.text_inputs:
                    total_text_len = len(self.text_inputs['scrollText1']) #+ 120  # Add 120 spaces padding
                    self.extra_uniforms['textLength1'] = float(total_text_len)
                    logger.info(f"AmigaSinus3.1 textLength1 (total) set to: {total_text_len}")

                if 'scrollText2' in self.text_inputs:
                    total_text_len = len(self.text_inputs['scrollText2']) #+ 120  # Add 120 spaces padding
                    self.extra_uniforms['textLength2'] = float(total_text_len)
                    logger.info(f"AmigaSinus3.1 textLength2 (total) set to: {total_text_len}")

            # Replace scrollText1 (main scroll) with chunking support
            if 'scrollText1' in self.text_inputs:
                user_text = self.text_inputs['scrollText1']
                logger.info(f"Processing scrollText1: {len(user_text)} characters")

                # Split text into chunks of 400 characters each
                chunk_size = 400
                chunks = []
                for i in range(0, len(user_text), chunk_size):
                    chunk = user_text[i:i + chunk_size]
                    chunks.append(chunk)

                logger.info(f"Split scrollText1 into {len(chunks)} chunks")

                # Process each chunk (up to 5 chunks supported)
                for chunk_num in range(1, 6):  # 1 to 5
                    if chunk_num <= len(chunks):
                        # Process this chunk
                        chunk_text = chunks[chunk_num - 1]

                        # Add padding spaces only to the final chunk
                        #if chunk_num == len(chunks):
                        #    chunk_text += " " * 120  # Add 120 spaces only to final chunk

                        spaced_text = text_to_spaced_sinus(chunk_text)
                        macro_string = text_to_glsl_macros(spaced_text)

                        # Set chunk length uniform (actual length including final padding if applicable)
                        chunk_length = len(chunk_text)
                        self.extra_uniforms[f'textLength1_{chunk_num}'] = float(chunk_length)

                        # Replace placeholder in shader
                        old_pattern = f'  // PLACEHOLDER_TEXT_1_{chunk_num}\n  _D _I _S _C _O _ _R _u _l _e _s' if chunk_num == 1 else f'  // PLACEHOLDER_TEXT_1_{chunk_num}'
                        new_text = f'  // Main scroll chunk {chunk_num}: {chunk_text[:50]}...\n  {macro_string}'
                        shader_source = re.sub(old_pattern, new_text, shader_source, flags=re.DOTALL)

                        logger.info(f"Processed scrollText1 chunk {chunk_num}: {len(chunk_text)} chars")
                    else:
                        # Empty chunk - set length to 0
                        self.extra_uniforms[f'textLength1_{chunk_num}'] = 0.0

                        # Replace with empty content
                        old_pattern = f'  // PLACEHOLDER_TEXT_1_{chunk_num}'
                        new_text = f'  // Empty chunk {chunk_num}'
                        shader_source = re.sub(old_pattern, new_text, shader_source, flags=re.DOTALL)

                logger.info(f"AmigaSinus3.1 scrollText1 chunking complete: {len(user_text)} chars in {len(chunks)} chunks")

            # Replace scrollText2 (bottom) with chunking support
            if 'scrollText2' in self.text_inputs:
                user_text = self.text_inputs['scrollText2']
                logger.info(f"Processing scrollText2: {len(user_text)} characters")

                # Split text into chunks of 400 characters each
                chunk_size = 400
                chunks = []
                for i in range(0, len(user_text), chunk_size):
                    chunk = user_text[i:i + chunk_size]
                    chunks.append(chunk)

                logger.info(f"Split scrollText2 into {len(chunks)} chunks")

                # Process each chunk (up to 5 chunks supported)
                for chunk_num in range(1, 6):  # 1 to 5
                    if chunk_num <= len(chunks):
                        # Process this chunk
                        chunk_text = chunks[chunk_num - 1]

                        # Add padding spaces only to the final chunk
                        if chunk_num == len(chunks):
                            chunk_text += " " * 120  # Add 120 spaces only to final chunk

                        spaced_text = text_to_spaced_sinus(chunk_text)
                        macro_string = text_to_glsl_macros(spaced_text)

                        # Set chunk length uniform (actual length including final padding if applicable)
                        chunk_length = len(chunk_text)
                        self.extra_uniforms[f'textLength2_{chunk_num}'] = float(chunk_length)

                        # Replace placeholder in shader
                        old_pattern = f'  // PLACEHOLDER_TEXT_2_{chunk_num}\n  _A _u _d _i _o _ _V _i _b _e _s' if chunk_num == 1 else f'  // PLACEHOLDER_TEXT_2_{chunk_num}'
                        new_text = f'  // Bottom scroll chunk {chunk_num}: {chunk_text[:50]}...\n  {macro_string}'
                        shader_source = re.sub(old_pattern, new_text, shader_source, flags=re.DOTALL)

                        logger.info(f"Processed scrollText2 chunk {chunk_num}: {len(chunk_text)} chars")
                    else:
                        # Empty chunk - set length to 0
                        self.extra_uniforms[f'textLength2_{chunk_num}'] = 0.0

                        # Replace with empty content
                        old_pattern = f'  // PLACEHOLDER_TEXT_2_{chunk_num}'
                        new_text = f'  // Empty chunk {chunk_num}'
                        shader_source = re.sub(old_pattern, new_text, shader_source, flags=re.DOTALL)

                logger.info(f"AmigaSinus3.1 scrollText2 chunking complete: {len(user_text)} chars in {len(chunks)} chunks")

        return shader_source

    def _init_opengl_context(self):
        """Initialize OpenGL context"""
        try:
            self.ctx = moderngl.create_standalone_context()
            logger.info("Created OpenGL context successfully")
        except Exception as e:
            logger.error(f"Failed to create OpenGL context: {e}")
            raise

    def _init_feedback_buffers(self):
        """
        Initialize double-buffered feedback system for temporal effects.

        This creates two framebuffers with attached textures that alternate
        each frame. The output of frame N becomes the input (iChannel1) for
        frame N+1, enabling effects like motion trails, feedback loops, etc.
        """
        if not self.needs_feedback_buffer:
            logger.info("Feedback buffers not needed for this shader")
            return

        try:
            logger.info("Initializing feedback buffer system for temporal effects...")

            # Create two framebuffers with RGBA textures for double-buffering
            for i in range(2):
                # Create texture to hold rendered output (RGBA for proper blending)
                feedback_tex = self.ctx.texture(self.resolution, 4)
                feedback_tex.filter = (moderngl.LINEAR, moderngl.LINEAR)
                feedback_tex.repeat_x = False
                feedback_tex.repeat_y = False

                # Create framebuffer with this texture as color attachment
                feedback_fbo = self.ctx.framebuffer(color_attachments=[feedback_tex])

                # Clear the framebuffer to black initially
                feedback_fbo.use()
                self.ctx.clear(0.0, 0.0, 0.0, 1.0)

                self.feedback_textures[i] = feedback_tex
                self.feedback_fbos[i] = feedback_fbo

            logger.info(f"Created feedback buffers: 2x {self.resolution[0]}x{self.resolution[1]} RGBA textures")

        except Exception as e:
            logger.error(f"Failed to initialize feedback buffers: {e}")
            self.needs_feedback_buffer = False
            raise

    def _get_previous_frame_texture(self):
        """
        Get the texture containing the previous frame's rendered output.
        Returns the texture from the buffer that was written to last frame.
        """
        if not self.needs_feedback_buffer or self.feedback_textures[0] is None:
            return None
        # The previous frame is in the OTHER buffer (not the one we're about to write to)
        prev_index = 1 - self.current_feedback_index
        return self.feedback_textures[prev_index]

    def _get_current_feedback_fbo(self):
        """
        Get the framebuffer to render the current frame into.
        Returns the buffer that will become the 'previous frame' for the next iteration.
        """
        if not self.needs_feedback_buffer or self.feedback_fbos[0] is None:
            return None
        return self.feedback_fbos[self.current_feedback_index]

    def _swap_feedback_buffers(self):
        """Swap the double buffer index after rendering a frame."""
        self.current_feedback_index = 1 - self.current_feedback_index

    def _cleanup_feedback_buffers(self):
        """Release feedback buffer resources."""
        for i in range(2):
            if self.feedback_textures[i]:
                self.feedback_textures[i].release()
                self.feedback_textures[i] = None
            if self.feedback_fbos[i]:
                self.feedback_fbos[i].release()
                self.feedback_fbos[i] = None
        logger.info("Cleaned up feedback buffers")

    # ===================================================================================
    # MULTI-BUFFER SHADER SYSTEM (Shadertoy-style BufferA, BufferB, Image)
    # ===================================================================================

    def _init_multi_buffer_system(self, vbo):
        """
        Initialize the multi-buffer rendering system for Shadertoy-style effects.
        Creates separate shader programs, framebuffers, and textures for each buffer.
        """
        if not self.is_multi_buffer:
            return

        logger.info("Initializing multi-buffer shader system...")

        buffers_config = self.shader_config.get('buffers', {})
        render_order = self.shader_config.get('renderOrder', [])

        vertex_shader = '''
        #version 330
        in vec2 in_vert;
        out vec2 v_text;
        void main() {
            gl_Position = vec4(in_vert, 0.0, 1.0);
            v_text = in_vert * 0.5 + 0.5;
        }
        '''

        # For multi-buffer shaders, shader_path is a FOLDER, so parent is Shaders/
        # Buffer files are relative to Shaders/ (e.g., "PsychedelicTrails/BufferA.glsl")
        if self.shader_path.is_dir():
            shader_base_path = self.shader_path.parent  # e.g., Shaders/
        else:
            shader_base_path = self.shader_path.parent  # Same for .glsl files

        logger.info(f"Multi-buffer base path: {shader_base_path}")

        for buffer_name in render_order:
            buffer_config = buffers_config.get(buffer_name, {})
            shader_file = buffer_config.get('file', '')
            shader_path = shader_base_path / shader_file

            if not shader_path.exists():
                logger.error(f"Multi-buffer shader file not found: {shader_path}")
                raise FileNotFoundError(f"Shader file not found: {shader_path}")

            logger.info(f"Compiling buffer shader: {buffer_name} ({shader_file})")

            # Load and compile shader
            shader_code = shader_path.read_text()
            try:
                prog = self.ctx.program(
                    vertex_shader=vertex_shader,
                    fragment_shader=shader_code
                )
                self.multi_buffer_programs[buffer_name] = prog
                logger.info(f"  {buffer_name}: Compiled successfully")
            except Exception as e:
                logger.error(f"Failed to compile {buffer_name}: {e}")
                raise

            # Create VAO for this buffer
            vao = self.ctx.simple_vertex_array(prog, vbo, 'in_vert')
            self.multi_buffer_vaos[buffer_name] = vao

            # Create double-buffered textures and framebuffers (needed for self-reference)
            textures = []
            fbos = []
            for i in range(2):
                tex = self.ctx.texture(self.resolution, 4)  # RGBA
                tex.filter = (moderngl.LINEAR, moderngl.LINEAR)
                tex.repeat_x = False
                tex.repeat_y = False
                textures.append(tex)

                fbo = self.ctx.framebuffer(color_attachments=[tex])
                fbo.use()
                self.ctx.clear(0.0, 0.0, 0.0, 1.0)
                fbos.append(fbo)

            self.multi_buffer_textures[buffer_name] = textures
            self.multi_buffer_fbos[buffer_name] = fbos
            self.multi_buffer_indices[buffer_name] = 0

            logger.info(f"  {buffer_name}: Created 2x framebuffers for double-buffering")

        logger.info(f"Multi-buffer system initialized: {len(render_order)} buffers")

    def _render_multi_buffer_frame(self, video_tex, frame_count, audio_features):
        """
        Render one frame using the multi-buffer pipeline.
        Returns the final output texture.

        IMPORTANT: Buffer indices track which texture was LAST WRITTEN TO.
        - For self-reference: read from current index (last frame's output)
        - For other buffers: read from current index (this frame's output, already rendered)
        - After rendering: update index to the one we just wrote to
        """
        buffers_config = self.shader_config.get('buffers', {})
        render_order = self.shader_config.get('renderOrder', [])

        # Track which index each buffer rendered to THIS frame
        # (before we update the indices)
        rendered_to = {}

        if frame_count == 0 or frame_count == 1:
            logger.info(f"=== MULTI-BUFFER FRAME {frame_count} DEBUG ===")
            logger.info(f"Render order: {render_order}")
            logger.info(f"Buffer configs: {list(buffers_config.keys())}")

        for buffer_name in render_order:
            buffer_config = buffers_config.get(buffer_name, {})
            channels = buffer_config.get('channels', {})
            prog = self.multi_buffer_programs[buffer_name]
            vao = self.multi_buffer_vaos[buffer_name]

            # For this buffer: write to the OPPOSITE of what we last wrote to
            # So we preserve the previous frame's output for self-reference
            last_written_idx = self.multi_buffer_indices[buffer_name]
            write_idx = 1 - last_written_idx
            target_fbo = self.multi_buffer_fbos[buffer_name][write_idx]

            if frame_count == 0 or frame_count == 1:
                logger.info(f"  {buffer_name}: last_written={last_written_idx}, write_to={write_idx}")
                logger.info(f"  {buffer_name}: channels={channels}")

            # Bind textures to channels
            for channel_name, source in channels.items():
                channel_num = int(channel_name.replace('iChannel', ''))

                if source == 'video':
                    # Bind video texture
                    video_tex.use(channel_num)
                    if frame_count == 0 or frame_count == 1:
                        logger.info(f"    {channel_name} <- video texture")
                elif source in self.multi_buffer_textures:
                    if source == buffer_name:
                        # SELF-REFERENCE: read from last frame's output (last_written_idx)
                        source_tex = self.multi_buffer_textures[source][last_written_idx]
                        if frame_count == 0 or frame_count == 1:
                            logger.info(f"    {channel_name} <- {source}[{last_written_idx}] (SELF)")
                    elif source in rendered_to:
                        # Another buffer that was rendered THIS frame: use what it just wrote to
                        source_tex = self.multi_buffer_textures[source][rendered_to[source]]
                        if frame_count == 0 or frame_count == 1:
                            logger.info(f"    {channel_name} <- {source}[{rendered_to[source]}] (this frame)")
                    else:
                        # Another buffer not yet rendered this frame (shouldn't happen with correct order)
                        # Fall back to its last written index
                        source_tex = self.multi_buffer_textures[source][self.multi_buffer_indices[source]]
                        if frame_count == 0 or frame_count == 1:
                            logger.info(f"    {channel_name} <- {source}[{self.multi_buffer_indices[source]}] (fallback)")
                    source_tex.use(channel_num)
                else:
                    if frame_count == 0 or frame_count == 1:
                        logger.warning(f"    {channel_name} <- {source} NOT FOUND in multi_buffer_textures!")

                # Set uniform
                if channel_name in prog:
                    prog[channel_name].value = channel_num

            # Set standard uniforms
            self._set_shader_uniforms(prog, frame_count, audio_features)

            # Render to this buffer's FBO
            target_fbo.use()
            # CRITICAL: Clear the FBO before rendering to it!
            # Without this, we'd be blending with stale data from 2 frames ago
            self.ctx.clear(0.0, 0.0, 0.0, 1.0)
            vao.render()

            # Track that we rendered to write_idx
            rendered_to[buffer_name] = write_idx

        # Update all buffer indices to reflect what was rendered this frame
        for buffer_name, idx in rendered_to.items():
            self.multi_buffer_indices[buffer_name] = idx

        # Return the final "Image" buffer's texture
        final_buffer = render_order[-1]
        final_idx = rendered_to[final_buffer]
        return self.multi_buffer_textures[final_buffer][final_idx]

    def _get_multi_buffer_final_fbo(self):
        """Get the framebuffer containing the final rendered output."""
        if not self.is_multi_buffer:
            return None
        render_order = self.shader_config.get('renderOrder', [])
        final_buffer = render_order[-1]
        # multi_buffer_indices now stores what was LAST WRITTEN TO
        final_idx = self.multi_buffer_indices[final_buffer]
        return self.multi_buffer_fbos[final_buffer][final_idx]

    def _cleanup_multi_buffer_system(self):
        """Release all multi-buffer resources."""
        for buffer_name in self.multi_buffer_programs:
            # Release textures
            if buffer_name in self.multi_buffer_textures:
                for tex in self.multi_buffer_textures[buffer_name]:
                    if tex:
                        tex.release()
            # Release FBOs
            if buffer_name in self.multi_buffer_fbos:
                for fbo in self.multi_buffer_fbos[buffer_name]:
                    if fbo:
                        fbo.release()

        self.multi_buffer_programs.clear()
        self.multi_buffer_fbos.clear()
        self.multi_buffer_textures.clear()
        self.multi_buffer_vaos.clear()
        self.multi_buffer_indices.clear()
        logger.info("Cleaned up multi-buffer system")

    def get_advanced_audio_analysis(self, audio_path, total_frames):
        """
        Perform advanced audio analysis for audio-reactive shaders.
        This is the same as the original but optimized for streaming.
        """
        try:
            logger.info("Loading audio for analysis...")
            y, sr = librosa.load(str(audio_path), sr=None)
            
            # Calculate hop length for frame alignment
            duration = len(y) / sr
            hop_length = int(len(y) / total_frames)

            # Ensure hop_length is reasonable for audio analysis
            min_hop_length = 512  # Minimum for good frequency resolution
            max_hop_length = 4096  # Maximum for reasonable time resolution

            if hop_length < min_hop_length:
                hop_length = min_hop_length
                logger.warning(f"Hop length too small, using minimum: {hop_length}")
            elif hop_length > max_hop_length:
                hop_length = max_hop_length
                logger.warning(f"Hop length too large, using maximum: {hop_length}")

            logger.info(f"Audio: {duration:.2f}s, {sr}Hz, hop_length={hop_length}")

            # Extract frequency bands
            def extract_frequency_band(y, sr, freq_range, hop_length):
                stft = librosa.stft(y, hop_length=hop_length)
                freqs = librosa.fft_frequencies(sr=sr)
                
                freq_mask = (freqs >= freq_range[0]) & (freqs <= freq_range[1])
                band_stft = stft[freq_mask, :]
                
                magnitude = np.abs(band_stft)
                energy = np.mean(magnitude, axis=0)
                
                # Normalize to 0-1 range
                if np.max(energy) > 0:
                    energy = energy / np.max(energy)
                
                return energy

            # Define frequency ranges
            bass_freq = (20, 250)
            mid_freq = (250, 4000)
            treble_freq = (4000, 20000)

            # Extract frequency bands
            bass_energy = extract_frequency_band(y, sr, bass_freq, hop_length)
            mid_energy = extract_frequency_band(y, sr, mid_freq, hop_length)
            treble_energy = extract_frequency_band(y, sr, treble_freq, hop_length)

            # Beat detection with fallback
            try:
                onset_frames = librosa.onset.onset_detect(
                    y=y, sr=sr, hop_length=hop_length,
                    units='frames', backtrack=True
                )

                # If no beats detected, try with more sensitive parameters
                if len(onset_frames) == 0:
                    logger.warning("No beats detected with default parameters, trying more sensitive detection...")
                    onset_frames = librosa.onset.onset_detect(
                        y=y, sr=sr, hop_length=hop_length//2,
                        units='frames', backtrack=True,
                        delta=0.01, wait=1
                    )

                # If still no beats, create artificial beat pattern based on tempo
                if len(onset_frames) == 0:
                    logger.warning("No beats detected, creating artificial beat pattern...")
                    try:
                        tempo, _ = librosa.beat.beat_track(y=y, sr=sr)
                        beat_interval = int(60 * sr / tempo / hop_length) if tempo > 0 else len(bass_energy) // 4
                    except:
                        # Fallback to simple pattern if tempo detection fails
                        beat_interval = len(bass_energy) // 4
                    onset_frames = np.arange(0, len(bass_energy), max(1, beat_interval))

                logger.info(f"Beat detection: {len(onset_frames)} beats found")

            except Exception as beat_error:
                logger.warning(f"Beat detection failed: {beat_error}, using artificial pattern")
                # Create simple artificial beat pattern
                onset_frames = np.arange(0, len(bass_energy), len(bass_energy) // 8)

            # Create beat strength array
            beat_strength = np.zeros(len(bass_energy))
            for onset_frame in onset_frames:
                if onset_frame < len(beat_strength):
                    for i in range(min(10, len(beat_strength) - onset_frame)):
                        decay = np.exp(-i * 0.3)
                        beat_strength[onset_frame + i] = max(
                            beat_strength[onset_frame + i], decay
                        )

            # Additional audio features
            rms_energy = librosa.feature.rms(y=y, hop_length=hop_length)[0]
            spectral_centroid = librosa.feature.spectral_centroid(y=y, sr=sr, hop_length=hop_length)[0]
            
            # Normalize features
            rms_energy = rms_energy / np.max(rms_energy) if np.max(rms_energy) > 0 else rms_energy
            spectral_centroid = spectral_centroid / np.max(spectral_centroid) if np.max(spectral_centroid) > 0 else spectral_centroid

            # Ensure all arrays are the same length as total_frames
            def resize_array(arr, target_length):
                if len(arr) != target_length:
                    indices = np.linspace(0, len(arr) - 1, target_length)
                    return np.interp(indices, np.arange(len(arr)), arr)
                return arr

            return {
                'bassLevel': resize_array(bass_energy, total_frames),
                'midLevel': resize_array(mid_energy, total_frames),
                'trebleLevel': resize_array(treble_energy, total_frames),
                'beatLevel': resize_array(beat_strength, total_frames),
                'kickLevel': resize_array(beat_strength, total_frames),  # Same as beat for simplicity
                'rmsLevel': resize_array(rms_energy, total_frames),
                'brightnessLevel': resize_array(spectral_centroid, total_frames),
                'energyLevel': resize_array(bass_energy + mid_energy + treble_energy, total_frames),
                'percussiveLevel': resize_array(beat_strength, total_frames),
                'tempoBeatLevel': resize_array(beat_strength, total_frames),
            }

        except Exception as e:
            logger.error(f"Audio analysis failed: {e}")
            # Return zero arrays if analysis fails
            return {
                'bassLevel': np.zeros(total_frames),
                'midLevel': np.zeros(total_frames),
                'trebleLevel': np.zeros(total_frames),
                'beatLevel': np.zeros(total_frames),
                'kickLevel': np.zeros(total_frames),
                'rmsLevel': np.zeros(total_frames),
                'brightnessLevel': np.zeros(total_frames),
                'energyLevel': np.zeros(total_frames),
                'percussiveLevel': np.zeros(total_frames),
                'tempoBeatLevel': np.zeros(total_frames),
            }

    def stream_process_video(self):
        """
        Main streaming video processing method - no frame extraction needed!
        """
        try:
            logger.info("Starting streamlined video processing pipeline")

            # Initialize video capture and OpenGL
            self._init_video_capture()
            self._init_opengl_context()

            if self.progress_tracker:
                self.progress_tracker.update(progress=10, stage="initializing",
                                           message="Initializing video stream...",
                                           details="Setting up direct video streaming")

            # Check if shader is audio-reactive
            is_audio_reactive = self.shader_config.get('audioReactive', True)

            # Perform audio analysis if needed
            if is_audio_reactive:
                logger.info("Performing audio analysis for audio-reactive shader...")
                if self.progress_tracker:
                    self.progress_tracker.update(progress=20, stage="analyzing",
                                               message="Analyzing audio frequencies...",
                                               details="Extracting bass, mid, treble, and beat information")
                audio_features = self.get_advanced_audio_analysis(self.audio_path, self.total_frames)
            else:
                logger.info("Skipping audio analysis for non-audio-reactive shader")
                audio_features = {}

            # Create vertex buffer for full-screen quad (shared by all shaders)
            vbo = self.ctx.buffer(np.array([
                -1.0, -1.0,
                 1.0, -1.0,
                -1.0,  1.0,
                -1.0,  1.0,
                 1.0, -1.0,
                 1.0,  1.0,
            ], dtype='f4'))

            # Create output framebuffer
            fbo = self.ctx.simple_framebuffer(self.resolution)
            fbo.use()

            # Initialize shader system based on type
            prog = None
            vao = None

            if self.is_multi_buffer:
                # MULTI-BUFFER SHADER SYSTEM
                logger.info("Initializing multi-buffer shader system...")
                self._init_multi_buffer_system(vbo)
            else:
                # SINGLE-FILE SHADER (traditional)
                logger.info(f"Loading shader: {self.shader_path}")
                shader_code = self.shader_path.read_text()

                # Process text replacement for AmigaSinus shaders
                if self.text_inputs:
                    logger.info("Text replacement requested for: " + str(list(self.text_inputs.keys())))
                    logger.info("Starting text replacement...")
                    shader_code = self._process_amiga_sinus_text(shader_code)
                    logger.info(f"Text replacement complete. Shader size: {len(shader_code)} characters")

                # Compile shader
                vertex_shader = '''
                #version 330
                in vec2 in_vert;
                out vec2 v_text;
                void main() {
                    gl_Position = vec4(in_vert, 0.0, 1.0);
                    v_text = in_vert * 0.5 + 0.5;
                }
                '''

                try:
                    logger.info("Starting shader compilation...")
                    prog = self.ctx.program(
                        vertex_shader=vertex_shader,
                        fragment_shader=shader_code
                    )
                    logger.info("Shader compiled successfully")

                except Exception as e:
                    logger.error(f"Shader compilation error: {e}")
                    raise

                vao = self.ctx.simple_vertex_array(prog, vbo, 'in_vert')

                # Load static textures (cached)
                self._load_static_textures(prog)

                # Initialize feedback buffers for temporal effects (if needed)
                if self.needs_feedback_buffer:
                    self._init_feedback_buffers()
                    logger.info("Feedback buffer system initialized for temporal effects")

            # Initialize FFmpeg output stream
            output_stream = self._init_output_stream()

            if self.progress_tracker:
                self.progress_tracker.update(progress=30, stage="processing",
                                           message="Processing video stream...",
                                           details="Applying shader effects in real-time",
                                           total_frames=self.total_frames)

            # Main processing loop - stream frames directly with proper timing
            frame_count = 0
            frames_written = 0

            while frame_count < self.total_frames:
                ret, frame = self.cap.read()
                if not ret:
                    logger.warning(f"Failed to read frame {frame_count}, stopping")
                    break

                try:
                    # Convert OpenCV frame (BGR) to RGB and resize
                    frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                    frame_resized = cv2.resize(frame_rgb, self.resolution)

                    # Create OpenGL texture from frame
                    tex = self.ctx.texture(self.resolution, 3, frame_resized.tobytes())
                    tex.filter = (moderngl.LINEAR, moderngl.LINEAR)

                    if self.is_multi_buffer:
                        # ========== MULTI-BUFFER RENDERING ==========
                        # Render through the buffer pipeline
                        self._render_multi_buffer_frame(tex, frame_count, audio_features)

                        # Read from final buffer's FBO
                        final_fbo = self._get_multi_buffer_final_fbo()
                        if final_fbo:
                            final_fbo.use()
                            data = final_fbo.read(components=3)
                        else:
                            # Fallback
                            data = fbo.read(components=3)
                    else:
                        # ========== SINGLE-FILE SHADER RENDERING ==========
                        tex.use(0)  # Bind to iChannel0

                        # Bind feedback buffer (previous frame) to iChannel1 if needed
                        if self.needs_feedback_buffer:
                            prev_tex = self._get_previous_frame_texture()
                            if prev_tex:
                                prev_tex.use(1)  # Bind previous frame to iChannel1
                                if 'iChannel1' in prog:
                                    prog['iChannel1'].value = 1

                        # Ensure static textures are bound (rebind each frame for safety)
                        for channel, tex_obj in self.texture_cache.items():
                            channel_num = int(channel.replace('iChannel', ''))
                            # Don't overwrite iChannel1 if we're using it for feedback
                            if self.needs_feedback_buffer and channel_num == 1:
                                continue
                            tex_obj.use(channel_num)

                        # Set shader uniforms (includes iFrame for temporal effects)
                        self._set_shader_uniforms(prog, frame_count, audio_features)

                        # Determine which framebuffer to render to
                        if self.needs_feedback_buffer:
                            # Render to feedback buffer for temporal accumulation
                            current_fbo = self._get_current_feedback_fbo()
                            current_fbo.use()
                            vao.render()

                            # Copy feedback buffer content to main FBO for output
                            # Use blit for efficient GPU-side copy
                            self.ctx.copy_framebuffer(fbo, current_fbo)

                            # Swap feedback buffers for next frame
                            self._swap_feedback_buffers()
                        else:
                            # Standard single-pass rendering
                            fbo.use()
                            vao.render()

                        # Read back rendered frame from main FBO
                        data = fbo.read(components=3)
                    rendered_frame = np.frombuffer(data, dtype=np.uint8).reshape(
                        self.resolution[1], self.resolution[0], 3
                    )

                    # Flip vertically (OpenGL origin is bottom-left)
                    rendered_frame = np.flipud(rendered_frame)

                    # Scale back if using oversized rendering
                    if self.needs_oversized_rendering:
                        rendered_frame = cv2.resize(rendered_frame, self.base_resolution)

                    # Write frame to output stream - CRITICAL: ensure every frame is written
                    try:
                        output_stream.stdin.write(rendered_frame.tobytes())
                        output_stream.stdin.flush()  # Ensure frame is sent immediately
                        frames_written += 1
                    except BrokenPipeError:
                        logger.error("FFmpeg pipe broken - stopping processing")
                        break

                    # Update progress
                    if self.progress_tracker and frame_count % 10 == 0:
                        progress = 30 + (60 * frame_count / self.total_frames)
                        self.progress_tracker.update(
                            progress=progress,
                            frame_count=frame_count + 1,
                            total_frames=self.total_frames,
                            details=f"Processing frame {frame_count+1} of {self.total_frames} (written: {frames_written})"
                        )

                    if frame_count % 30 == 0:
                        logger.info(f"Processed frame {frame_count+1}/{self.total_frames} (written: {frames_written})")

                    # Clean up frame texture
                    tex.release()
                    frame_count += 1

                except Exception as e:
                    logger.error(f"Error processing frame {frame_count}: {e}")
                    # Still increment to avoid infinite loop
                    frame_count += 1
                    continue

            logger.info(f"Processing complete: {frame_count} frames processed, {frames_written} frames written")

            # Finalize output
            output_stream.stdin.close()
            output_stream.wait()

            if self.progress_tracker:
                self.progress_tracker.update(progress=100, stage="complete",
                                           message="Processing complete!",
                                           details="Your trippy video is ready!")

            logger.info(f"Streaming processing complete! Output: {self.output_path}")

        except Exception as e:
            logger.error(f"Error in stream processing: {e}")
            raise
        finally:
            # Cleanup
            if self.cap:
                self.cap.release()
            # Clean up feedback buffers
            if self.needs_feedback_buffer:
                self._cleanup_feedback_buffers()
            # Clean up multi-buffer system
            if self.is_multi_buffer:
                self._cleanup_multi_buffer_system()

    def _load_static_textures(self, prog):
        """Load static textures specified in shader config"""
        if 'textures' in self.shader_config:
            for channel, filename in self.shader_config['textures'].items():
                if channel != 'iChannel0':  # Skip video channel
                    channel_num = int(channel.replace('iChannel', ''))
                    texture_path = Path("Textures") / filename

                    if texture_path.exists():
                        try:
                            from PIL import Image
                            tex_img = Image.open(texture_path).convert("RGB")
                            tex_obj = self.ctx.texture(tex_img.size, 3, tex_img.tobytes())
                            tex_obj.use(channel_num)
                            self.texture_cache[channel] = tex_obj
                            logger.info(f"Loaded static texture {filename} for {channel}")
                        except Exception as e:
                            logger.warning(f"Failed to load texture {filename}: {e}")
                    else:
                        logger.warning(f"Texture file not found: {texture_path}")

    def _init_output_stream(self):
        """Initialize FFmpeg output stream for direct video encoding with proper sync"""
        try:
            import ffmpeg
            target_w, target_h = self.base_resolution

            # Create FFmpeg input from pipe with exact frame rate matching
            input_stream = ffmpeg.input('pipe:', format='rawvideo', pix_fmt='rgb24',
                                      s=f'{target_w}x{target_h}', r=self.frame_rate)

            # Add audio input
            audio_stream = ffmpeg.input(str(self.audio_path))

            # Create output with video and audio - simple working version
            output_stream = ffmpeg.output(
                input_stream, audio_stream, str(self.output_path),
                vcodec='libx264', crf=18, pix_fmt='yuv420p',
                acodec='aac'
            ).overwrite_output().run_async(pipe_stdin=True)


            logger.info(f"Initialized output stream: {target_w}x{target_h} @ {self.frame_rate}fps with audio sync")
            return output_stream

        except Exception as e:
            logger.error(f"Failed to initialize output stream: {e}")
            raise

    def _set_shader_uniforms(self, prog, frame_index, audio_features):
        """Set shader uniforms for current frame"""
        try:
            # Time-based uniforms
            time_seconds = frame_index / self.frame_rate
            if 'iTime' in prog:
                prog['iTime'].value = time_seconds
            if 'iResolution' in prog:
                prog['iResolution'].value = self.resolution

            # Frame counter for temporal effects (Shadertoy-compatible)
            if 'iFrame' in prog:
                prog['iFrame'].value = frame_index

            # For multi-buffer shaders, channel uniforms are already set in _render_multi_buffer_frame
            # Don't overwrite them here!
            if not self.is_multi_buffer:
                # Set texture channel uniforms - CRITICAL for texture access
                # iChannel0 = video texture (always bound to unit 0)
                if 'iChannel0' in prog:
                    prog['iChannel0'].value = 0

                # iChannel1 = feedback buffer (previous frame) when using temporal effects
                if self.needs_feedback_buffer and 'iChannel1' in prog:
                    prog['iChannel1'].value = 1

                # Set static texture channel uniforms
                for channel, tex_obj in self.texture_cache.items():
                    channel_num = int(channel.replace('iChannel', ''))
                    channel_name = f'iChannel{channel_num}'
                    # Don't overwrite iChannel1 if we're using it for feedback
                    if self.needs_feedback_buffer and channel_num == 1:
                        continue
                    if channel_name in prog:
                        prog[channel_name].value = channel_num

            # Audio-reactive uniforms
            if audio_features:
                for uniform_name, values in audio_features.items():
                    if uniform_name in prog and frame_index < len(values):
                        prog[uniform_name].value = float(values[frame_index])

            # User-defined uniforms
            for uniform_name, value in self.extra_uniforms.items():
                if uniform_name in prog:
                    if isinstance(value, (list, tuple)):
                        prog[uniform_name].value = tuple(value)
                    else:
                        prog[uniform_name].value = float(value)

        except Exception as e:
            logger.warning(f"Error setting uniforms for frame {frame_index}: {e}")

    def run(self):
        """Main entry point - replaces the old frame-based pipeline"""
        return self.stream_process_video()
