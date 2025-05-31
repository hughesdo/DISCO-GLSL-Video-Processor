from fastapi import FastAPI, UploadFile, File, Form, Request
from fastapi.responses import FileResponse, JSONResponse, HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
import shutil
import tempfile
import json
import logging
from shader_video_processor import ShaderVideoProcessor

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

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

# Load shader config
try:
    SHADER_CONFIG = json.load(open(CONFIG_FILE)) if CONFIG_FILE.exists() else {}
    logger.info(f"Loaded shader config: {list(SHADER_CONFIG.keys())}")
except Exception as e:
    logger.error(f"Error loading shader config: {e}")
    SHADER_CONFIG = {}

@app.get("/shaders/list")
async def list_shaders():
    """Return list of available GLSL shaders"""
    try:
        shader_files = [f.name for f in SHADER_DIR.glob("*.glsl")]
        logger.info(f"Found shaders: {shader_files}")
        return JSONResponse(shader_files)
    except Exception as e:
        logger.error(f"Error listing shaders: {e}")
        return JSONResponse([])

@app.get("/shaders/config")
async def get_config():
    """Return shader configuration for UI"""
    return JSONResponse(SHADER_CONFIG)

@app.post("/process")
async def process_video(request: Request):
    """Process video with shader effects and instrument audio"""
    try:
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

        logger.info(f"Processing with shader: {shader}")

        # Parse uniforms
        uniforms = {}
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
        
        logger.info(f"Parsed uniforms: {uniforms}")



        # Save main files to temp
        video_path = TEMP_DIR / f"input_video_{video.filename}"
        audio_path = TEMP_DIR / f"input_audio_{audio.filename}"
        output_path = TEMP_DIR / "output_disco.mp4"

        with open(video_path, "wb") as f:
            shutil.copyfileobj(video.file, f)
        with open(audio_path, "wb") as f:
            shutil.copyfileobj(audio.file, f)

        logger.info(f"Saved input files: video={video_path}, audio={audio_path}")

        # Process video
        processor = ShaderVideoProcessor(
            video_path=video_path,
            audio_path=audio_path,
            shader_path=SHADER_DIR / shader,
            output_path=output_path,
            extra_uniforms=uniforms
        )
        
        processor.run()

        if not output_path.exists():
            raise Exception("Output video was not created")

        logger.info("Video processing completed successfully")
        return FileResponse(
            output_path, 
            filename="output_disco.mp4", 
            media_type="video/mp4"
        )

    except Exception as e:
        logger.error(f"Error processing video: {str(e)}")
        return JSONResponse(
            {"error": f"Processing failed: {str(e)}"}, 
            status_code=500
        )

@app.get("/", response_class=HTMLResponse)
async def frontend():
    """Serve the frontend HTML"""
    try:
        return Path("index.html").read_text()
    except FileNotFoundError:
        return HTMLResponse("<h1>Error: index.html not found</h1>", status_code=404)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)