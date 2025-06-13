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

logger = logging.getLogger(__name__)

class StreamingVideoProcessor:
    def __init__(self, video_path, audio_path, shader_path, output_path,
                 extra_uniforms={}, progress_tracker=None, audio_settings=None,
                 max_frames=None):
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
        self.progress_tracker = progress_tracker
        self.max_frames = max_frames
        self.base_resolution = (1280, 720)
        self.frame_rate = 30

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

    def _load_shader_config(self):
        """Load shader configuration for texture and uniform information"""
        try:
            config_path = Path("Shaders/shader_config.json")
            if config_path.exists():
                with open(config_path, 'r') as f:
                    config = json.load(f)
                shader_name = self.shader_path.name
                if shader_name in config:
                    logger.info(f"Loaded configuration for shader: {shader_name}")
                    return config[shader_name]
                else:
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

    def _init_opengl_context(self):
        """Initialize OpenGL context"""
        try:
            self.ctx = moderngl.create_standalone_context()
            logger.info("Created OpenGL context successfully")
        except Exception as e:
            logger.error(f"Failed to create OpenGL context: {e}")
            raise

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

            # Beat detection
            onset_frames = librosa.onset.onset_detect(
                y=y, sr=sr, hop_length=hop_length,
                units='frames', backtrack=True
            )

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

            # Load and compile shader
            logger.info(f"Loading shader: {self.shader_path}")
            shader_code = self.shader_path.read_text()

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
                prog = self.ctx.program(
                    vertex_shader=vertex_shader,
                    fragment_shader=shader_code
                )
                logger.info("Shader compiled successfully")
            except Exception as e:
                logger.error(f"Shader compilation error: {e}")
                raise

            # Create vertex buffer for full-screen quad
            vbo = self.ctx.buffer(np.array([
                -1.0, -1.0,
                 1.0, -1.0,
                -1.0,  1.0,
                -1.0,  1.0,
                 1.0, -1.0,
                 1.0,  1.0,
            ], dtype='f4'))

            vao = self.ctx.simple_vertex_array(prog, vbo, 'in_vert')
            fbo = self.ctx.simple_framebuffer(self.resolution)
            fbo.use()

            # Load static textures (cached)
            self._load_static_textures(prog)

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
                    tex.use(0)  # Bind to iChannel0

                    # Set shader uniforms
                    self._set_shader_uniforms(prog, frame_count, audio_features)

                    # Render frame
                    vao.render()

                    # Read back rendered frame
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

            # Create output with video and audio - ensure proper sync
            output_stream = ffmpeg.output(
                input_stream, audio_stream, str(self.output_path),
                vcodec='libx264', crf=18, pix_fmt='yuv420p',
                acodec='aac',
                # Critical sync options
                vsync='cfr',  # Constant frame rate
                async_=1,     # Audio sync
                # Additional sync options
                **{'avoid_negative_ts': 'make_zero'}
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
