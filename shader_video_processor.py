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

logger = logging.getLogger(__name__)

class ShaderVideoProcessor:
    def __init__(self, video_path, audio_path, shader_path, output_path,
                 extra_uniforms={}):
        """
        Initialize the shader video processor.

        Args:
            video_path: Path to input video file
            audio_path: Path to main audio file
            shader_path: Path to GLSL shader file
            output_path: Path for output video
            extra_uniforms: Dict of uniform name -> value for shader
        """
        self.video_path = Path(video_path)
        self.audio_path = Path(audio_path)
        self.shader_path = Path(shader_path)
        self.output_path = Path(output_path)
        self.extra_uniforms = extra_uniforms
        self.resolution = (1280, 720)
        self.frame_rate = 30
        
        # Create OpenGL context
        try:
            self.ctx = moderngl.create_standalone_context()
            logger.info("Created OpenGL context successfully")
        except Exception as e:
            logger.error(f"Failed to create OpenGL context: {e}")
            raise

    def get_audio_levels(self, audio_file, total_frames):
        """Extract audio amplitude levels for each frame"""
        try:
            logger.info(f"Analyzing audio: {audio_file}")
            y, sr = librosa.load(str(audio_file), sr=None)
            
            # Calculate hop length to match video frame rate
            hop_length = int(sr / self.frame_rate)
            
            # Get RMS energy for amplitude
            rms = librosa.feature.rms(y=y, hop_length=hop_length)[0]
            
            # Normalize to 0-1 range
            if rms.max() > rms.min():
                rms = np.interp(rms, (rms.min(), rms.max()), (0, 1))
            else:
                rms = np.zeros_like(rms)
            
            # Pad or trim to match video length
            if len(rms) < total_frames:
                rms = np.pad(rms, (0, total_frames - len(rms)), constant_values=0)
            elif len(rms) > total_frames:
                rms = rms[:total_frames]
                
            logger.info(f"Extracted {len(rms)} audio levels")
            return rms
            
        except Exception as e:
            logger.error(f"Error analyzing audio {audio_file}: {e}")
            # Return zero array if audio analysis fails
            return np.zeros(total_frames)

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
                str(output_pattern)
            ]
            
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
        """Render frames with shader effects"""
        temp_out = Path(tempfile.mkdtemp(prefix="disco_render_"))
        
        try:
            logger.info(f"Loading shader: {self.shader_path}")
            shader_code = self.shader_path.read_text()
            
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

            # Render each frame
            for i, frame_path in enumerate(input_frames):
                try:
                    # Load input frame as texture
                    img = Image.open(frame_path).convert("RGB")
                    tex = self.ctx.texture(self.resolution, 3, img.tobytes())
                    tex.use(0)

                    # Set standard uniforms
                    if 'iResolution' in prog:
                        prog['iResolution'].value = tuple(self.resolution)
                    if 'iTime' in prog:
                        prog['iTime'].value = i / self.frame_rate
                    if 'iChannel0' in prog:
                        prog['iChannel0'].value = 0

                    # Set extra uniforms from config
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
                    
                    if i % 30 == 0:  # Log progress every second
                        logger.info(f"Rendered frame {i+1}/{len(input_frames)}")
                        
                except Exception as e:
                    logger.error(f"Error rendering frame {i}: {e}")
                    # Copy original frame if rendering fails
                    shutil.copy2(frame_path, temp_out / f"frame_{i:05d}.png")

            logger.info(f"Rendering complete: {len(input_frames)} frames")
            return temp_out
            
        except Exception as e:
            logger.error(f"Error in render_frames: {e}")
            raise

    def combine_video(self, frames_folder):
        """Combine rendered frames with audio using FFmpeg"""
        try:
            logger.info("Combining frames with audio")
            
            cmd = [
                "ffmpeg", "-y",
                "-framerate", str(self.frame_rate),
                "-i", str(frames_folder / "frame_%05d.png"),
                "-i", str(self.audio_path),
                "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p",
                "-c:a", "aac", "-shortest",
                str(self.output_path)
            ]
            
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
            
            # Step 1: Extract frames from input video
            input_frames, temp_frames_dir = self.extract_frames()
            temp_dirs.append(temp_frames_dir)

            # Step 2: Render frames with shader effects
            rendered_frames_dir = self.render_frames(input_frames)
            temp_dirs.append(rendered_frames_dir)

            # Step 3: Combine frames with audio
            self.combine_video(rendered_frames_dir)

            logger.info(f"Processing complete! Output: {self.output_path}")

        except Exception as e:
            logger.error(f"Processing pipeline failed: {e}")
            raise
        finally:
            # Clean up temporary directories
            for temp_dir in temp_dirs:
                try:
                    shutil.rmtree(temp_dir, ignore_errors=True)
                    logger.info(f"Cleaned up temp dir: {temp_dir}")
                except Exception as e:
                    logger.warning(f"Failed to clean up {temp_dir}: {e}")