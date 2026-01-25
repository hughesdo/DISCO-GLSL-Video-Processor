from fastapi import FastAPI, UploadFile, File, Form, Request
from fastapi.responses import FileResponse, JSONResponse, HTMLResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
import shutil
import tempfile
import json
import logging
import asyncio
import uuid

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

try:
    from streaming_video_processor import StreamingVideoProcessor
    # Enable streaming for AmigaSinus3.1 with automatic streaming flag detection
    USE_STREAMING = True  # Enabled for shaders with streaming flag
    logger.info("Streaming processor available and enabled for streaming-capable shaders")
except ImportError as e:
    logger.warning(f"Streaming processor not available: {e}")
    USE_STREAMING = False

# Always import legacy processor as fallback
from shader_video_processor import ShaderVideoProcessor

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SHADER_DIR = Path("./Shaders")  # Fixed path to match your structure
TEMP_DIR = Path(tempfile.gettempdir())
CONFIG_FILE = SHADER_DIR / "shader_config.json"

# Progress tracking
progress_store = {}

# Load shader config
try:
    SHADER_CONFIG = json.load(open(CONFIG_FILE, 'r', encoding='utf-8')) if CONFIG_FILE.exists() else {}
    logger.info(f"Loaded shader config: {list(SHADER_CONFIG.keys())}")
except Exception as e:
    logger.error(f"Error loading shader config: {e}")
    SHADER_CONFIG = {}

class ProgressTracker:
    def __init__(self, job_id):
        self.job_id = job_id
        self.progress = 0
        self.stage = "initializing"
        self.message = "Starting processing..."
        self.details = ""
        self.frame_count = 0
        self.total_frames = 0
        self.start_time = None

    def update(self, progress=None, stage=None, message=None, details=None, frame_count=None, total_frames=None):
        if progress is not None:
            self.progress = progress
        if stage is not None:
            self.stage = stage
        if message is not None:
            self.message = message
        if details is not None:
            self.details = details
        if frame_count is not None:
            self.frame_count = frame_count
        if total_frames is not None:
            self.total_frames = total_frames

        progress_store[self.job_id] = {
            "progress": self.progress,
            "stage": self.stage,
            "message": self.message,
            "details": self.details,
            "frame_count": self.frame_count,
            "total_frames": self.total_frames,
            "start_time": self.start_time
        }

@app.get("/shaders/list")
async def list_shaders():
    """Return list of available GLSL shaders (single-file and multi-buffer)"""
    try:
        shader_files = []

        # Add single-file .glsl shaders
        for f in SHADER_DIR.glob("*.glsl"):
            shader_files.append(f.name)

        # Add multi-buffer shader folders (folders with multiBuffer: true in config)
        for shader_name, config in SHADER_CONFIG.items():
            if config.get('multiBuffer', False):
                # Multi-buffer shaders are identified by folder name, not .glsl extension
                shader_folder = SHADER_DIR / shader_name
                if shader_folder.is_dir():
                    shader_files.append(shader_name)  # Add folder name as shader option
                    logger.info(f"Found multi-buffer shader folder: {shader_name}")

        logger.info(f"Found shaders: {shader_files}")
        return JSONResponse(shader_files)
    except Exception as e:
        logger.error(f"Error listing shaders: {e}")
        return JSONResponse([])

@app.get("/shaders/config")
async def get_config():
    """Return shader configuration for UI"""
    return JSONResponse(SHADER_CONFIG)

@app.get("/progress/{job_id}")
async def get_progress(job_id: str):
    """Get processing progress for a job"""
    if job_id in progress_store:
        return JSONResponse(progress_store[job_id])
    else:
        return JSONResponse({"error": "Job not found"}, status_code=404)

@app.get("/progress/stream/{job_id}")
async def stream_progress(job_id: str):
    """Stream processing progress updates"""
    async def generate():
        while job_id in progress_store:
            data = progress_store[job_id]
            yield f"data: {json.dumps(data)}\n\n"

            # If processing is complete, stop streaming
            if data.get("progress", 0) >= 100:
                break

            await asyncio.sleep(1)  # Update every second

    return StreamingResponse(generate(), media_type="text/plain")

@app.post("/process")
async def process_video(request: Request):
    """Process video with shader effects and instrument audio"""
    try:
        # Generate unique job ID for progress tracking
        job_id = str(uuid.uuid4())
        tracker = ProgressTracker(job_id)
        tracker.start_time = asyncio.get_event_loop().time()

        form = await request.form()

        # Get required files
        video = form.get('video')
        audio = form.get('audio')
        shader = form.get('shader')

        if not video or not audio or not shader:
            return JSONResponse(
                {"error": "Missing required files: video, audio, or shader"},
                status_code=400
            )

        # Return job ID immediately for progress tracking
        response_data = {"job_id": job_id}

        # Start processing in background
        asyncio.create_task(process_video_background(form, tracker))

        return JSONResponse(response_data)

    except Exception as e:
        logger.error(f"Error processing video: {str(e)}")
        return JSONResponse(
            {"error": f"Processing failed: {str(e)}"},
            status_code=500
        )

async def process_video_background(form, tracker: ProgressTracker):
    """Background video processing with progress tracking"""
    try:
        # Get form data
        video = form.get('video')
        audio = form.get('audio')
        shader = form.get('shader')

        tracker.update(progress=5, stage="initializing", message="Initializing video stream...",
                      details="Setting up direct video streaming pipeline")

        logger.info(f"Processing with shader: {shader}")

        # Parse uniforms
        uniforms = {}
        text_inputs = {}
        for k, v in form.items():
            if k.startswith("uniform_"):
                name = k[8:]  # Remove "uniform_" prefix
                try:
                    # Try to parse as JSON first (for arrays/objects)
                    uniforms[name] = json.loads(v)
                except (json.JSONDecodeError, TypeError):
                    try:
                        # Try to parse as float
                        uniforms[name] = float(v)
                    except (ValueError, TypeError):
                        # Keep as string if all else fails
                        uniforms[name] = str(v)
            elif k.startswith("textInput_"):
                name = k[10:]  # Remove "textInput_" prefix
                text_inputs[name] = str(v)

        logger.info(f"Parsed uniforms: {uniforms}")
        logger.info(f"Parsed text inputs: {text_inputs}")

        tracker.update(progress=15, stage="analyzing", message="Analyzing audio...",
                      details="Processing audio for beat detection and frequency analysis")

        # Save main files to temp
        video_path = TEMP_DIR / f"input_video_{video.filename}"
        audio_path = TEMP_DIR / f"input_audio_{audio.filename}"
        output_path = TEMP_DIR / "output_disco.mp4"

        with open(video_path, "wb") as f:
            shutil.copyfileobj(video.file, f)
        with open(audio_path, "wb") as f:
            shutil.copyfileobj(audio.file, f)

        logger.info(f"Saved input files: video={video_path}, audio={audio_path}")

        tracker.update(progress=25, stage="streaming", message="Streaming video through shader...",
                      details="Applying trippy visual effects in real-time")

        # Parse audio settings from form
        audio_settings = {}
        if form.get('reactivity_preset'):
            audio_settings['reactivity_preset'] = form.get('reactivity_preset')
        if form.get('beat_sensitivity'):
            audio_settings['beat_sensitivity'] = float(form.get('beat_sensitivity'))
        if form.get('bass_response'):
            audio_settings['bass_response'] = float(form.get('bass_response'))
        if form.get('mid_response'):
            audio_settings['mid_response'] = float(form.get('mid_response'))
        if form.get('treble_response'):
            audio_settings['treble_response'] = float(form.get('treble_response'))

        # Handle preview mode
        max_frames = None
        if form.get('preview_mode') == 'true':
            max_frames = int(form.get('max_frames', 240))
            logger.info(f"Preview mode enabled: {max_frames} frames")

        # Check if shader supports streaming or is multi-buffer
        use_streaming = False
        is_multi_buffer = False

        if shader in SHADER_CONFIG:
            use_streaming = SHADER_CONFIG[shader].get('streaming', False)
            is_multi_buffer = SHADER_CONFIG[shader].get('multiBuffer', False)

            # Multi-buffer shaders MUST use streaming processor
            if is_multi_buffer:
                use_streaming = True
                logger.info(f"Shader {shader} is multi-buffer - forcing streaming processor")
            elif use_streaming:
                logger.info(f"Shader {shader} supports streaming - using streaming processor")
            else:
                logger.info(f"Shader {shader} using frame-based processor")
        else:
            logger.info(f"Shader {shader} not in config - using frame-based processor")

        # Determine shader path - for multi-buffer shaders, it's a folder
        shader_path = SHADER_DIR / shader

        # Process video with progress tracking and audio settings
        if use_streaming and USE_STREAMING:
            logger.info(f"Using streaming video processor for: {shader_path}")
            processor = StreamingVideoProcessor(
                video_path=video_path,
                audio_path=audio_path,
                shader_path=shader_path,
                output_path=output_path,
                extra_uniforms=uniforms,
                progress_tracker=tracker,
                audio_settings=audio_settings,
                max_frames=max_frames,
                text_inputs=text_inputs
            )
        else:
            if use_streaming and not USE_STREAMING:
                logger.info("Shader supports streaming but USE_STREAMING is disabled - falling back to frame-based processor")
            if is_multi_buffer:
                raise Exception(f"Multi-buffer shader {shader} requires streaming processor which is not available")
            logger.info("Using frame-based video processor")
            processor = ShaderVideoProcessor(
                video_path=video_path,
                audio_path=audio_path,
                shader_path=shader_path,
                output_path=output_path,
                extra_uniforms=uniforms,
                progress_tracker=tracker,
                audio_settings=audio_settings,
                max_frames=max_frames,
                text_inputs=text_inputs
            )

        processor.run()

        if not output_path.exists():
            raise Exception("Output video was not created")

        tracker.update(progress=100, stage="complete", message="Processing complete!",
                      details="Your trippy video is ready!")

        logger.info("Video processing completed successfully")

        # Store the output path for download
        progress_store[tracker.job_id]["output_path"] = str(output_path)

    except Exception as e:
        logger.error(f"Error in background processing: {str(e)}")
        tracker.update(progress=0, stage="error", message="Processing failed",
                      details=f"Error: {str(e)}")

@app.get("/download/{job_id}")
async def download_result(job_id: str):
    """Download the processed video"""
    if job_id in progress_store and "output_path" in progress_store[job_id]:
        output_path = Path(progress_store[job_id]["output_path"])
        if output_path.exists():
            return FileResponse(
                output_path,
                filename="disco_trippy_video.mp4",
                media_type="video/mp4"
            )

    return JSONResponse({"error": "Video not found or not ready"}, status_code=404)

@app.get("/", response_class=HTMLResponse)
async def frontend():
    """Serve the frontend HTML"""
    try:
        return Path("index.html").read_text(encoding='utf-8')
    except FileNotFoundError:
        return HTMLResponse("<h1>Error: index.html not found</h1>", status_code=404)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)