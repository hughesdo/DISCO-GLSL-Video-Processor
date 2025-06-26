# shader_video_processor.py
import librosa
import numpy as np
from pathlib import Path
import moderngl
from PIL import Image
import tempfile
import subprocess
import shutil
import logging
import json
from scipy.interpolate import interp1d

logger = logging.getLogger(__name__)

class ShaderVideoProcessor:
    def __init__(self, video_path, audio_path, shader_path, output_path,
                 extra_uniforms={}, progress_tracker=None, audio_settings=None,
                 max_frames=None):
        """
        Initialize the shader video processor.

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
        self.max_frames = max_frames  # For preview mode
        self.base_resolution = (1280, 720)
        self.frame_rate = 30

        # Screen shake settings for EasyBeats shader (define first)
        self.enable_screen_shake = True
        self.shake_oversample = 1.2  # Render 20% larger to compensate for shake

        # Audio reactivity settings with defaults
        self.audio_settings = audio_settings or {
            'beat_sensitivity': 1.0,
            'bass_response': 1.0,
            'mid_response': 1.0,
            'treble_response': 1.0,
            'reactivity_preset': 'moderate'
        }

        # Load shader configuration for texture support
        self.shader_config = self._load_shader_config()

        # Initialize texture cache for static textures
        self.texture_cache = {}

        # Check if this is a screen shake shader that needs oversized rendering
        self.needs_oversized_rendering = self._check_if_shake_shader()
        if self.needs_oversized_rendering:
            # Render 20% larger to compensate for shake displacement
            self.resolution = (int(self.base_resolution[0] * self.shake_oversample),
                             int(self.base_resolution[1] * self.shake_oversample))
            logger.info(f"Using oversized rendering for screen shake: {self.resolution}")
        else:
            self.resolution = self.base_resolution

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

    def _init_opengl_context(self):
        """Initialize OpenGL context"""
        try:
            self.ctx = moderngl.create_standalone_context()
            logger.info("Created OpenGL context successfully")
        except Exception as e:
            logger.error(f"Failed to create OpenGL context: {e}")
            raise

    def get_advanced_audio_analysis(self, audio_file, total_frames):
        """Extract comprehensive audio features for each frame"""
        try:
            logger.info(f"Performing advanced audio analysis: {audio_file}")
            y, sr = librosa.load(str(audio_file), sr=None)

            # Calculate hop length to match video frame rate
            hop_length = int(sr / self.frame_rate)

            # 1. FREQUENCY BAND SEPARATION
            # Define frequency bands (in Hz)
            bass_freq = (20, 250)      # Bass frequencies
            mid_freq = (250, 4000)     # Mid frequencies
            treble_freq = (4000, sr//2) # Treble frequencies (up to Nyquist)

            # Create bandpass filters for each frequency range
            def extract_frequency_band(audio, sr, freq_range, hop_length):
                # Use librosa's bandpass filter
                filtered = librosa.effects.preemphasis(audio)

                # Get spectral centroid and RMS for the band
                stft = librosa.stft(filtered, hop_length=hop_length)
                freqs = librosa.fft_frequencies(sr=sr)

                # Find frequency bin indices for our band
                freq_mask = (freqs >= freq_range[0]) & (freqs <= freq_range[1])

                # Extract energy in this frequency band
                band_stft = stft[freq_mask, :]
                band_energy = np.mean(np.abs(band_stft) ** 2, axis=0)

                return band_energy

            # Extract frequency bands
            bass_energy = extract_frequency_band(y, sr, bass_freq, hop_length)
            mid_energy = extract_frequency_band(y, sr, mid_freq, hop_length)
            treble_energy = extract_frequency_band(y, sr, treble_freq, hop_length)

            # 2. BEAT DETECTION
            # Use onset detection for beat/kick detection
            onset_frames = librosa.onset.onset_detect(
                y=y, sr=sr, hop_length=hop_length,
                units='frames', backtrack=True
            )

            # Create beat strength array
            beat_strength = np.zeros(len(bass_energy))
            for onset_frame in onset_frames:
                if onset_frame < len(beat_strength):
                    # Create beat pulse with decay
                    for i in range(min(10, len(beat_strength) - onset_frame)):
                        decay = np.exp(-i * 0.3)  # Exponential decay
                        beat_strength[onset_frame + i] = max(
                            beat_strength[onset_frame + i],
                            decay
                        )

            # 3. ENHANCED BEAT DETECTION FOR LOW FREQUENCIES
            # Focus on bass frequencies for kick detection
            bass_onset_frames = librosa.onset.onset_detect(
                y=librosa.effects.preemphasis(y), sr=sr,
                hop_length=hop_length, units='frames',
                pre_max=3, post_max=3, pre_avg=3, post_avg=5, delta=0.1, wait=10
            )

            kick_strength = np.zeros(len(bass_energy))
            for kick_frame in bass_onset_frames:
                if kick_frame < len(kick_strength):
                    # Stronger, shorter kick pulses
                    for i in range(min(5, len(kick_strength) - kick_frame)):
                        decay = np.exp(-i * 0.5)  # Faster decay for kicks
                        kick_strength[kick_frame + i] = max(
                            kick_strength[kick_frame + i],
                            decay
                        )

            # 4. NORMALIZE ALL FEATURES
            def safe_normalize(arr):
                if arr.max() > arr.min():
                    return np.interp(arr, (arr.min(), arr.max()), (0, 1))
                else:
                    return np.zeros_like(arr)

            bass_levels = safe_normalize(bass_energy)
            mid_levels = safe_normalize(mid_energy)
            treble_levels = safe_normalize(treble_energy)
            beat_levels = safe_normalize(beat_strength)
            kick_levels = safe_normalize(kick_strength)

            # 5. APPLY USER AUDIO REACTIVITY SETTINGS
            # Scale audio levels based on user preferences
            bass_response = self.audio_settings.get('bass_response', 1.0)
            mid_response = self.audio_settings.get('mid_response', 1.0)
            treble_response = self.audio_settings.get('treble_response', 1.0)
            beat_sensitivity = self.audio_settings.get('beat_sensitivity', 1.0)

            # Apply scaling (clamp to reasonable ranges)
            bass_levels = np.clip(bass_levels * bass_response, 0, 2.0)
            mid_levels = np.clip(mid_levels * mid_response, 0, 2.0)
            treble_levels = np.clip(treble_levels * treble_response, 0, 2.0)
            beat_levels = np.clip(beat_levels * beat_sensitivity, 0, 2.0)
            kick_levels = np.clip(kick_levels * beat_sensitivity, 0, 2.0)

            # 6. ADDITIONAL SPECTRAL FEATURES
            # Spectral centroid (brightness)
            spectral_centroids = librosa.feature.spectral_centroid(y=y, sr=sr, hop_length=hop_length)[0]
            brightness_levels = safe_normalize(spectral_centroids)

            # Spectral rolloff (energy distribution)
            spectral_rolloff = librosa.feature.spectral_rolloff(y=y, sr=sr, hop_length=hop_length)[0]
            energy_levels = safe_normalize(spectral_rolloff)

            # Zero crossing rate (percussiveness)
            zcr = librosa.feature.zero_crossing_rate(y, hop_length=hop_length)[0]
            percussive_levels = safe_normalize(zcr)

            # 7. OVERALL RMS FOR COMPATIBILITY
            rms = librosa.feature.rms(y=y, hop_length=hop_length)[0]
            rms_levels = safe_normalize(rms)

            # 8. ENHANCED BEAT FEATURES
            # Tempo and beat tracking
            tempo, beat_frames = librosa.beat.beat_track(y=y, sr=sr, hop_length=hop_length, units='frames')

            # Create tempo-synced beat array
            tempo_beats = np.zeros(len(bass_energy))
            for beat_frame in beat_frames:
                if beat_frame < len(tempo_beats):
                    # Create beat pulse with decay
                    for i in range(min(8, len(tempo_beats) - beat_frame)):
                        decay = np.exp(-i * 0.4)
                        tempo_beats[beat_frame + i] = max(tempo_beats[beat_frame + i], decay)

            tempo_beat_levels = safe_normalize(tempo_beats)

            # 9. PAD OR TRIM TO MATCH VIDEO LENGTH
            def match_video_length(arr, target_frames):
                if len(arr) < target_frames:
                    return np.pad(arr, (0, target_frames - len(arr)), constant_values=0)
                elif len(arr) > target_frames:
                    return arr[:target_frames]
                return arr

            audio_features = {
                'bassLevel': match_video_length(bass_levels, total_frames),
                'midLevel': match_video_length(mid_levels, total_frames),
                'trebleLevel': match_video_length(treble_levels, total_frames),
                'beatLevel': match_video_length(beat_levels, total_frames),
                'kickLevel': match_video_length(kick_levels, total_frames),
                'rmsLevel': match_video_length(rms_levels, total_frames),
                'brightnessLevel': match_video_length(brightness_levels, total_frames),
                'energyLevel': match_video_length(energy_levels, total_frames),
                'percussiveLevel': match_video_length(percussive_levels, total_frames),
                'tempoBeatLevel': match_video_length(tempo_beat_levels, total_frames),
            }

            logger.info(f"Extracted advanced audio features: {list(audio_features.keys())}")
            logger.info(f"Bass range: {float(bass_levels.min()):.3f} - {float(bass_levels.max()):.3f}")
            logger.info(f"Mid range: {float(mid_levels.min()):.3f} - {float(mid_levels.max()):.3f}")
            logger.info(f"Treble range: {float(treble_levels.min()):.3f} - {float(treble_levels.max()):.3f}")
            logger.info(f"Detected {len(onset_frames)} beats, {len(bass_onset_frames)} kicks")
            logger.info(f"Estimated tempo: {float(tempo):.1f} BPM, {len(beat_frames)} tempo beats")
            logger.info(f"Audio reactivity settings: {self.audio_settings}")

            return audio_features

        except Exception as e:
            logger.error(f"Error in advanced audio analysis {audio_file}: {str(e)}")
            logger.info("Falling back to basic audio analysis...")

            # Try basic RMS analysis as fallback
            try:
                y, sr = librosa.load(str(audio_file), sr=None)
                hop_length = int(sr / self.frame_rate)
                rms = librosa.feature.rms(y=y, hop_length=hop_length)[0]

                # Normalize and pad/trim
                if rms.max() > rms.min():
                    rms_normalized = np.interp(rms, (rms.min(), rms.max()), (0, 1))
                else:
                    rms_normalized = np.zeros_like(rms)

                if len(rms_normalized) < total_frames:
                    rms_normalized = np.pad(rms_normalized, (0, total_frames - len(rms_normalized)), constant_values=0)
                elif len(rms_normalized) > total_frames:
                    rms_normalized = rms_normalized[:total_frames]

                logger.info("Basic RMS analysis successful - using as fallback for all audio features")

                # Use RMS for all features as fallback
                return {
                    'bassLevel': rms_normalized,
                    'midLevel': rms_normalized,
                    'trebleLevel': rms_normalized,
                    'beatLevel': rms_normalized,
                    'kickLevel': rms_normalized,
                    'rmsLevel': rms_normalized,
                    'brightnessLevel': rms_normalized,
                    'energyLevel': rms_normalized,
                    'percussiveLevel': rms_normalized,
                    'tempoBeatLevel': rms_normalized,
                }

            except Exception as fallback_error:
                logger.error(f"Fallback audio analysis also failed: {str(fallback_error)}")
                # Return zero arrays if everything fails
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

    def extract_frames(self):
        """Extract frames from input video using FFmpeg"""
        temp_dir = Path(tempfile.mkdtemp(prefix="disco_frames_"))
        output_pattern = temp_dir / "frame_%05d.png"

        try:
            logger.info(f"Extracting frames to: {temp_dir}")

            cmd = [
                "ffmpeg", "-y", "-i", str(self.video_path),
                "-vf", f"scale={self.resolution[0]}:{self.resolution[1]}",
                "-r", str(self.frame_rate),  # Set output frame rate
            ]

            # Add frame limit for preview mode
            if self.max_frames:
                cmd.extend(["-frames:v", str(self.max_frames)])
                logger.info(f"Preview mode: limiting to {self.max_frames} frames")

            cmd.append(str(output_pattern))
            
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            
            frames = sorted(temp_dir.glob("frame_*.png"))
            logger.info(f"Extracted {len(frames)} frames")
            
            if len(frames) == 0:
                raise Exception("No frames were extracted from video")
                
            return frames, temp_dir
            
        except subprocess.CalledProcessError as e:
            logger.error(f"FFmpeg error: {e.stderr}")
            raise Exception(f"Failed to extract frames: {e.stderr}")

    def render_frames(self, input_frames):
        """Render frames with shader effects and audio-reactive features"""
        temp_out = Path(tempfile.mkdtemp(prefix="disco_render_"))

        try:
            # Initialize OpenGL context if not already done
            if not hasattr(self, 'ctx'):
                self._init_opengl_context()

            logger.info(f"Loading shader: {self.shader_path}")
            shader_code = self.shader_path.read_text()

            # Perform advanced audio analysis only if shader is audio-reactive
            total_frames = len(input_frames)
            is_audio_reactive = self.shader_config.get('audioReactive', True)  # Default to True for backward compatibility

            if is_audio_reactive:
                logger.info("Performing advanced audio analysis for audio-reactive shader...")
                if self.progress_tracker:
                    self.progress_tracker.update(
                        progress=20, stage="analyzing",
                        message="Analyzing audio frequencies...",
                        details="Extracting bass, mid, treble, and beat information"
                    )
                audio_features = self.get_advanced_audio_analysis(self.audio_path, total_frames)
            else:
                logger.info("Skipping audio analysis for non-audio-reactive shader")
                if self.progress_tracker:
                    self.progress_tracker.update(
                        progress=20, stage="analyzing",
                        message="Skipping audio analysis...",
                        details="Shader is not audio-reactive"
                    )
                # Create minimal audio features for non-reactive shaders
                audio_features = {
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

            # Create shader program
            vertex_shader = """#version 330
in vec2 in_vert;
out vec2 v_text;
void main() {
    v_text = in_vert * 0.5 + 0.5;
    gl_Position = vec4(in_vert, 0.0, 1.0);
}"""

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

            # Check if shader needs audio texture instead of video texture
            needs_audio_texture = self.shader_config.get('needsAudioTexture', False)

            # Create audio texture if needed
            audio_texture = None
            fft_data = None
            if needs_audio_texture:
                # For RayBalls5, get real FFT data
                if 'RayBalls5' in str(self.shader_path):
                    logger.info(f"Creating real FFT data for {self.shader_path.name}")
                    fft_data = self.get_real_fft_audio_analysis(self.audio_path, total_frames)
                elif audio_features:
                    audio_texture = self._create_audio_texture(audio_features, total_frames)

            # Render each frame with audio-reactive features
            for i, frame_path in enumerate(input_frames):
                try:
                    # Load user input video frame
                    img = Image.open(frame_path).convert("RGB")

                    # Special handling for shaders that use different video channels
                    if 'VagasDome' in str(self.shader_path):
                        # VagasDome: user video goes to iChannel2 (Y-flipped)
                        img_flipped = img.transpose(Image.FLIP_TOP_BOTTOM)
                        user_video_tex = self.ctx.texture(self.resolution, 3, img_flipped.tobytes())
                        user_video_tex.use(2)
                        texture_units = {2: user_video_tex}
                        if i == 0:
                            logger.info(f"VagasDome: User input video (Y-flipped) assigned to iChannel2 ({img.size})")
                    elif 'TVZoom' in str(self.shader_path):
                        # TVZoom: user video goes to iChannel2 (no flip)
                        user_video_tex = self.ctx.texture(self.resolution, 3, img.tobytes())
                        user_video_tex.use(2)
                        texture_units = {2: user_video_tex}
                        if i == 0:
                            logger.info(f"TVZoom: User input video assigned to iChannel2 ({img.size})")
                    else:
                        # For other shaders: user video goes to iChannel0 as usual (no flip)
                        user_video_tex = self.ctx.texture(self.resolution, 3, img.tobytes())
                        user_video_tex.use(0)
                        texture_units = {0: user_video_tex}
                        if i == 0:
                            logger.info(f"Texture assignment for {self.shader_path.name}: iChannel0 = video ({img.size})")

                    # Add audio texture to iChannel1 if needed
                    if needs_audio_texture:
                        if fft_data is not None:
                            # For RayBalls5 shader: FFT data goes to iChannel1
                            audio_tex = self._create_fft_texture(fft_data, i)
                            audio_tex.use(1)
                            texture_units[1] = audio_tex  # iChannel1 is FFT audio data
                            if i == 0:  # Log on first frame
                                logger.info(f"Texture assignment: iChannel1 = FFT audio data ({fft_data.shape[0]}x1)")
                        elif audio_texture:
                            # For other audio shaders: simplified audio data in iChannel1
                            audio_data = self._get_audio_frame_data(audio_features, i)
                            audio_tex = self._create_frame_audio_texture(audio_data)
                            audio_tex.use(1)
                            texture_units[1] = audio_tex  # iChannel1 is audio data
                            logger.debug(f"Frame {i}: Video in iChannel0, simple audio in iChannel1")

                    # Load additional textures if specified in shader config (with caching)
                    if hasattr(self, 'shader_config') and 'textures' in self.shader_config:
                        for channel, filename in self.shader_config['textures'].items():
                            channel_num = int(channel.replace('iChannel', ''))

                            # Special handling for VagasDome ping-pong video
                            if 'VagasDome' in str(self.shader_path) and channel == 'iChannel0':
                                # Load ping-pong video texture
                                video_tex = self._load_pingpong_video_texture(filename, i)
                                if video_tex:
                                    video_tex.use(channel_num)
                                    texture_units[channel_num] = video_tex
                                    if i == 0:
                                        logger.info(f"Loaded ping-pong video texture {filename} for {channel}")
                            elif channel != 'iChannel0' or 'VagasDome' not in str(self.shader_path):
                                # Regular texture loading for non-video channels or non-VagasDome shaders
                                texture_path = Path("Textures") / filename

                                # Check cache first
                                cache_key = f"{channel}_{filename}"
                                if cache_key in self.texture_cache:
                                    tex_obj = self.texture_cache[cache_key]
                                    tex_obj.use(channel_num)
                                    texture_units[channel_num] = tex_obj
                                elif texture_path.exists():
                                    try:
                                        tex_img = Image.open(texture_path).convert("RGB")
                                        tex_obj = self.ctx.texture(tex_img.size, 3, tex_img.tobytes())
                                        tex_obj.use(channel_num)
                                        texture_units[channel_num] = tex_obj
                                        # Cache the texture for future frames
                                        self.texture_cache[cache_key] = tex_obj
                                        logger.info(f"Loaded and cached texture {filename} for {channel}")
                                    except Exception as e:
                                        logger.warning(f"Failed to load texture {filename}: {e}")
                                else:
                                    logger.warning(f"Texture file not found: {texture_path}")





                    # Set standard uniforms
                    if 'iResolution' in prog:
                        prog['iResolution'].value = tuple(self.resolution)
                    if 'iTime' in prog:
                        prog['iTime'].value = i / self.frame_rate

                    # Set texture channel uniforms
                    for channel_num in texture_units.keys():
                        channel_name = f'iChannel{channel_num}'
                        if channel_name in prog:
                            prog[channel_name].value = channel_num

                    # Set audio-reactive uniforms (automatically provide audio data)
                    for audio_name, audio_data in audio_features.items():
                        if audio_name in prog and i < len(audio_data):
                            prog[audio_name].value = float(audio_data[i])

                    # Set extra uniforms from config (these can override audio uniforms)
                    for name, val in self.extra_uniforms.items():
                        if name in prog:
                            if isinstance(val, (list, tuple)):
                                prog[name].value = tuple(val)
                            else:
                                prog[name].value = float(val)

                    # Render the frame
                    vao.render()

                    # Read back the rendered frame
                    data = fbo.read(components=3)
                    rendered_img = Image.frombytes('RGB', self.resolution, data)
                    # Flip vertically because OpenGL has origin at bottom-left
                    rendered_img = rendered_img.transpose(Image.FLIP_TOP_BOTTOM)
                    rendered_img.save(temp_out / f"frame_{i:05d}.png")

                    # Update progress tracker
                    if self.progress_tracker and i % 10 == 0:  # Update every 10 frames
                        # Progress from 25% to 85% during rendering
                        render_progress = 25 + (60 * (i + 1) / total_frames)
                        self.progress_tracker.update(
                            progress=render_progress,
                            frame_count=i + 1,
                            total_frames=total_frames,
                            details=f"Rendering frame {i+1} of {total_frames}"
                        )

                    if i % 30 == 0:  # Log progress every second
                        logger.info(f"Rendered frame {i+1}/{total_frames}")

                except Exception as e:
                    logger.error(f"Error rendering frame {i}: {e}")
                    # Copy original frame if rendering fails
                    shutil.copy2(frame_path, temp_out / f"frame_{i:05d}.png")

            logger.info(f"Rendering complete: {len(input_frames)} frames")
            return temp_out
            
        except Exception as e:
            logger.error(f"Error in render_frames: {e}")
            raise

    def _create_audio_texture(self, audio_features, total_frames):
        """Create a texture containing audio frequency data for shaders that need it"""
        try:
            # Create a 1D texture with audio frequency data
            # Use a simple approach: create a texture with frequency bins
            freq_bins = 256  # Standard FFT size
            audio_data = []

            # Extract frequency data from audio features (use RMS as a simple approach)
            rms_data = audio_features.get('rmsLevel', [0.0] * total_frames)

            # Create frequency-like data from available audio features
            for i in range(total_frames):
                frame_data = []
                for bin_idx in range(freq_bins):
                    # Simple mapping: distribute audio energy across frequency bins
                    if i < len(rms_data):
                        # Create a simple frequency distribution
                        freq_val = rms_data[i] * (1.0 - abs(bin_idx - freq_bins//2) / (freq_bins//2))
                        frame_data.append(int(freq_val * 255))
                    else:
                        frame_data.append(0)
                audio_data.extend(frame_data)

            # Create texture
            audio_bytes = bytes(audio_data)
            texture = self.ctx.texture((freq_bins, total_frames), 1, audio_bytes)
            return texture

        except Exception as e:
            logger.warning(f"Failed to create audio texture: {e}")
            return None

    def _get_audio_frame_data(self, audio_features, frame_index):
        """Get audio data for a specific frame"""
        frame_data = {}
        for feature_name, feature_data in audio_features.items():
            if frame_index < len(feature_data):
                frame_data[feature_name] = feature_data[frame_index]
            else:
                frame_data[feature_name] = 0.0
        return frame_data

    def _create_frame_audio_texture(self, audio_data):
        """Create a simple audio texture for a single frame"""
        try:
            # Create a simple 1D texture with audio frequency data
            freq_bins = 256
            texture_data = []

            # Use audio levels to create a simple frequency distribution
            bass = audio_data.get('bassLevel', 0.0)
            mid = audio_data.get('midLevel', 0.0)
            treble = audio_data.get('trebleLevel', 0.0)

            for i in range(freq_bins):
                # Create frequency distribution based on audio features
                freq_pos = i / freq_bins
                if freq_pos < 0.33:  # Bass range
                    val = bass * (1.0 - freq_pos * 3)
                elif freq_pos < 0.66:  # Mid range
                    val = mid * (1.0 - abs(freq_pos - 0.5) * 2)
                else:  # Treble range
                    val = treble * (freq_pos - 0.66) * 3

                texture_data.append(int(val * 255))

            # Create 1D texture
            texture_bytes = bytes(texture_data)
            texture = self.ctx.texture((freq_bins, 1), 1, texture_bytes)
            return texture

        except Exception as e:
            logger.warning(f"Failed to create frame audio texture: {e}")
            # Fallback: create empty texture
            empty_data = bytes([0] * 256)
            return self.ctx.texture((256, 1), 1, empty_data)

    def get_real_fft_audio_analysis(self, audio_file, total_frames):
        """Extract real FFT frequency data for Waveform shader"""
        try:
            logger.info(f"Performing FFT audio analysis for Waveform: {audio_file}")
            y, sr = librosa.load(str(audio_file), sr=None)

            # Calculate hop length to match video frame rate
            hop_length = int(sr / self.frame_rate)

            # Perform STFT to get frequency data
            stft = librosa.stft(y, hop_length=hop_length, n_fft=512)  # 512 FFT size gives us 256 frequency bins
            magnitude = np.abs(stft)

            # Get frequency bins (we'll use first 256 bins)
            freq_bins = min(256, magnitude.shape[0])
            magnitude = magnitude[:freq_bins, :]

            # Normalize each frequency bin across time with safety checks
            for i in range(freq_bins):
                if magnitude[i].max() > 0:
                    magnitude[i] = magnitude[i] / magnitude[i].max()
                    # Extra safety: ensure all values are in 0-1 range
                    magnitude[i] = np.clip(magnitude[i], 0.0, 1.0)

            # Resize to match total frames
            if magnitude.shape[1] != total_frames:
                # Interpolate to match frame count
                old_indices = np.linspace(0, magnitude.shape[1] - 1, magnitude.shape[1])
                new_indices = np.linspace(0, magnitude.shape[1] - 1, total_frames)

                resized_magnitude = np.zeros((freq_bins, total_frames))
                for i in range(freq_bins):
                    if magnitude.shape[1] > 1:
                        f = interp1d(old_indices, magnitude[i], kind='linear', fill_value='extrapolate')
                        resized_magnitude[i] = f(new_indices)
                    else:
                        resized_magnitude[i] = magnitude[i, 0]

                magnitude = resized_magnitude

            logger.info(f"FFT analysis complete: {freq_bins} frequency bins, {total_frames} frames")
            return magnitude

        except Exception as e:
            logger.error(f"FFT audio analysis failed: {e}")
            # Return zero array if analysis fails
            return np.zeros((256, total_frames))



    def _create_fft_texture(self, audio_data, frame_index):
        """Create a texture with audio data (FFT or time domain) for the current frame"""
        try:
            # Get audio data for this frame
            data_bins = audio_data.shape[0]  # Could be 256 (FFT) or 128 (time domain)
            frame_data = audio_data[:, frame_index] if frame_index < audio_data.shape[1] else audio_data[:, -1]

            # Convert to texture format (0-255)
            texture_data = []
            for audio_val in frame_data:
                # Clamp and convert to byte with proper range checking
                val = max(0.0, min(1.0, float(audio_val)))  # Ensure it's a float and clamped
                byte_val = int(val * 255.0)
                # Extra safety: ensure byte value is in valid range
                byte_val = max(0, min(255, byte_val))
                texture_data.append(byte_val)



            # Create 1D texture with audio data (size depends on data type)
            texture_bytes = bytes(texture_data)
            texture = self.ctx.texture((data_bins, 1), 1, texture_bytes)
            return texture

        except Exception as e:
            logger.warning(f"Failed to create audio texture: {e}")
            # Fallback: create empty texture (use common size)
            fallback_size = 256 if audio_data.shape[0] > 200 else 128
            empty_data = bytes([0] * fallback_size)
            return self.ctx.texture((fallback_size, 1), 1, empty_data)



    def _load_pingpong_video_texture(self, filename, current_frame):
        """Load ping-pong video texture for VagasDome shader"""
        try:
            video_path = Path("Textures") / filename
            if not video_path.exists():
                logger.warning(f"Ping-pong video not found: {video_path}")
                return None

            cache_key = f"pingpong_{filename}"

            # Extract video frames if not cached
            if cache_key not in self.texture_cache:
                logger.info(f"Extracting ping-pong video frames: {video_path}")

                # Create temporary directory for video frames
                temp_dir = Path(tempfile.mkdtemp(prefix="disco_pingpong_"))

                try:
                    # Extract all frames from the video
                    cmd = [
                        "ffmpeg", "-y", "-i", str(video_path),
                        "-vf", f"scale={self.resolution[0]}:{self.resolution[1]}",
                        str(temp_dir / "frame_%05d.png")
                    ]

                    subprocess.run(cmd, capture_output=True, text=True, check=True)

                    # Load all frames into memory
                    frame_files = sorted(temp_dir.glob("frame_*.png"))
                    video_frames = []

                    for frame_file in frame_files:
                        img = Image.open(frame_file).convert("RGB")
                        # Flip Y to fix upside-down video
                        img = img.transpose(Image.FLIP_TOP_BOTTOM)
                        video_frames.append(img)

                    # Cache the frames
                    self.texture_cache[cache_key] = video_frames
                    logger.info(f"Cached {len(video_frames)} ping-pong frames for {filename}")

                finally:
                    # Clean up temporary directory
                    import shutil
                    shutil.rmtree(temp_dir, ignore_errors=True)

            # Get cached frames
            video_frames = self.texture_cache[cache_key]
            if not video_frames:
                return None

            # Calculate ping-pong frame index
            video_frame_count = len(video_frames)
            cycle_length = (video_frame_count - 1) * 2  # -1 to avoid duplicating end frames
            cycle_position = current_frame % cycle_length

            if cycle_position < video_frame_count:
                # Forward direction
                frame_index = cycle_position
            else:
                # Backward direction
                frame_index = video_frame_count - 1 - (cycle_position - video_frame_count + 1)

            frame_index = max(0, min(video_frame_count - 1, frame_index))

            # Create texture from the selected frame
            selected_frame = video_frames[frame_index]
            texture = self.ctx.texture(selected_frame.size, 3, selected_frame.tobytes())

            return texture

        except Exception as e:
            logger.warning(f"Failed to load ping-pong video texture: {e}")
            return None

    def combine_video(self, frames_folder):
        """Combine rendered frames with audio using FFmpeg"""
        try:
            logger.info("Combining frames with audio")

            # Build FFmpeg command
            cmd = [
                "ffmpeg", "-y",
                "-framerate", str(self.frame_rate),
                "-i", str(frames_folder / "frame_%05d.png"),
                "-i", str(self.audio_path),
            ]

            # If we used oversized rendering, scale back to target resolution
            if self.needs_oversized_rendering:
                target_w, target_h = self.base_resolution
                cmd.extend([
                    "-vf", f"scale={target_w}:{target_h}:flags=lanczos",
                ])
                logger.info(f"Scaling oversized frames back to {target_w}x{target_h}")

            # Add encoding settings
            cmd.extend([
                "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p",
                "-c:a", "aac", "-shortest",
                str(self.output_path)
            ])
            
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            logger.info("Video combination completed successfully")
            
        except subprocess.CalledProcessError as e:
            logger.error(f"FFmpeg combine error: {e.stderr}")
            raise Exception(f"Failed to combine video: {e.stderr}")

    def run(self):
        """Main processing pipeline"""
        temp_dirs = []

        try:
            logger.info("Starting video processing pipeline")

            if self.progress_tracker:
                self.progress_tracker.update(progress=10, stage="extracting",
                                           message="Extracting video frames...",
                                           details="Breaking down video into individual frames")

            # Step 1: Extract frames from input video
            input_frames, temp_frames_dir = self.extract_frames()
            temp_dirs.append(temp_frames_dir)

            if self.progress_tracker:
                self.progress_tracker.update(progress=25, stage="rendering",
                                           message="Rendering shader effects...",
                                           details="Applying visual effects to each frame",
                                           total_frames=len(input_frames))

            # Step 2: Render frames with shader effects
            rendered_frames_dir = self.render_frames(input_frames)
            temp_dirs.append(rendered_frames_dir)

            if self.progress_tracker:
                self.progress_tracker.update(progress=85, stage="combining",
                                           message="Combining final video...",
                                           details="Merging processed frames with audio")

            # Step 3: Combine frames with audio
            self.combine_video(rendered_frames_dir)

            if self.progress_tracker:
                self.progress_tracker.update(progress=100, stage="complete",
                                           message="Processing complete!",
                                           details="Your trippy video is ready!")

            logger.info(f"Processing complete! Output: {self.output_path}")

        except Exception as e:
            logger.error(f"Processing pipeline failed: {e}")
            if self.progress_tracker:
                self.progress_tracker.update(progress=0, stage="error",
                                           message="Processing failed",
                                           details=f"Error: {str(e)}")
            raise
        finally:
            # Clean up temporary directories
            for temp_dir in temp_dirs:
                try:
                    shutil.rmtree(temp_dir, ignore_errors=True)
                    logger.info(f"Cleaned up temp dir: {temp_dir}")
                except Exception as e:
                    logger.warning(f"Failed to clean up {temp_dir}: {e}")