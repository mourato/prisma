"""
FastAPI transcription service for Meeting Assistant.

Provides REST API for audio transcription using Parakeet TDT 0.6B v3.
"""

import logging
import tempfile
from pathlib import Path
from datetime import datetime

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from parakeet_engine import get_engine, TranscriptionResult
from audio_utils import save_upload_to_temp, preprocess_audio, get_audio_info

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# FastAPI app
app = FastAPI(
    title="Meeting Transcription Service",
    description="Local transcription service using Parakeet TDT 0.6B v3",
    version="1.0.0"
)

# Temp directory for uploads
TEMP_DIR = Path(tempfile.gettempdir()) / "meeting-assistant-uploads"

# Service state tracking
SERVICE_START_TIME: datetime | None = None
LAST_TRANSCRIPTION_TIME: datetime | None = None
TOTAL_TRANSCRIPTIONS: int = 0
TOTAL_AUDIO_PROCESSED_SECONDS: float = 0.0
MODEL_STATE: str = "unloaded"  # "unloaded", "loading", "loaded", "error"
MODEL_ERROR: str | None = None


class TranscriptionResponse(BaseModel):
    """API response model for transcription."""
    
    text: str
    language: str
    duration_seconds: float
    model: str
    processed_at: str


class HealthResponse(BaseModel):
    """API response model for health check."""
    
    status: str
    model_loaded: bool
    device: str


class ServiceStatusResponse(BaseModel):
    """API response model for detailed service status."""
    
    status: str
    model_state: str  # "unloaded", "loading", "loaded", "error"
    model_loaded: bool
    device: str
    model_name: str
    uptime_seconds: float
    last_transcription_time: str | None = None
    total_transcriptions: int = 0
    total_audio_processed_seconds: float = 0.0


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """
    Check service health and model status.
    
    Returns device info and whether model is loaded.
    """
    engine = get_engine()
    return HealthResponse(
        status="healthy",
        model_loaded=engine.is_loaded,
        device=engine.device
    )


@app.get("/status", response_model=ServiceStatusResponse)
async def get_service_status():
    """
    Get detailed service status.
    
    Returns comprehensive status including model state, uptime, and processing stats.
    """
    global MODEL_STATE
    
    engine = get_engine()
    
    # Calculate uptime
    uptime = 0.0
    if SERVICE_START_TIME:
        uptime = (datetime.now() - SERVICE_START_TIME).total_seconds()
    
    # Determine model state based on engine status
    if engine.is_loaded:
        MODEL_STATE = "loaded"
    elif MODEL_STATE == "loading":
        pass  # Keep loading state
    elif MODEL_ERROR:
        MODEL_STATE = "error"
    else:
        MODEL_STATE = "unloaded"
    
    return ServiceStatusResponse(
        status="healthy",
        model_state=MODEL_STATE,
        model_loaded=engine.is_loaded,
        device=engine.device,
        model_name="nvidia/parakeet-tdt-0.6b-v3",
        uptime_seconds=uptime,
        last_transcription_time=LAST_TRANSCRIPTION_TIME.isoformat() if LAST_TRANSCRIPTION_TIME else None,
        total_transcriptions=TOTAL_TRANSCRIPTIONS,
        total_audio_processed_seconds=TOTAL_AUDIO_PROCESSED_SECONDS
    )


@app.post("/transcribe", response_model=TranscriptionResponse)
async def transcribe_audio(file: UploadFile = File(...)):
    """
    Transcribe uploaded audio file.
    
    Accepts WAV, MP3, M4A, and other common formats.
    Audio is automatically preprocessed (resampled to 16kHz mono).
    
    Args:
        file: Audio file upload
    
    Returns:
        Transcription result with text and metadata
    """
    if not file.filename:
        raise HTTPException(status_code=400, detail="No filename provided")
    
    logger.info(f"Received transcription request: {file.filename}")
    
    try:
        # Save uploaded file
        upload_path = save_upload_to_temp(file.file, file.filename, TEMP_DIR)
        
        # Log audio info
        audio_info = get_audio_info(upload_path)
        logger.info(f"Audio info: {audio_info}")
        
        # Preprocess if needed
        needs_preprocessing = (
            audio_info["sample_rate"] != 16000 or
            audio_info["channels"] != 1
        )
        
        if needs_preprocessing:
            processed_path = preprocess_audio(upload_path)
        else:
            processed_path = upload_path
        
        # Transcribe
        engine = get_engine()
        result = engine.transcribe(processed_path)
        
        # Update service statistics
        global LAST_TRANSCRIPTION_TIME, TOTAL_TRANSCRIPTIONS, TOTAL_AUDIO_PROCESSED_SECONDS
        LAST_TRANSCRIPTION_TIME = datetime.now()
        TOTAL_TRANSCRIPTIONS += 1
        TOTAL_AUDIO_PROCESSED_SECONDS += result.duration_seconds
        
        # Cleanup temp files
        _cleanup_temp_files(upload_path, processed_path)
        
        return TranscriptionResponse(
            text=result.text,
            language=result.language,
            duration_seconds=result.duration_seconds,
            model=result.model_name,
            processed_at=datetime.now().isoformat()
        )
        
    except FileNotFoundError as e:
        logger.error(f"File not found: {e}")
        raise HTTPException(status_code=404, detail=str(e))
    
    except RuntimeError as e:
        logger.error(f"Transcription error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    
    except Exception as e:
        logger.exception(f"Unexpected error: {e}")
        raise HTTPException(status_code=500, detail="Internal server error")


@app.post("/warmup")
async def warmup_model():
    """
    Pre-load model into memory.
    
    Call this at service startup to reduce first-request latency.
    """
    global MODEL_STATE, MODEL_ERROR
    
    logger.info("Warming up model...")
    MODEL_STATE = "loading"
    MODEL_ERROR = None
    
    try:
        engine = get_engine()
        engine.load_model()
        MODEL_STATE = "loaded"
        return {"status": "model_loaded", "device": engine.device}
    except Exception as e:
        MODEL_STATE = "error"
        MODEL_ERROR = str(e)
        logger.error(f"Failed to load model: {e}")
        raise HTTPException(status_code=500, detail=f"Model load failed: {e}")


@app.on_event("startup")
async def startup_event():
    """Log service startup."""
    global SERVICE_START_TIME
    SERVICE_START_TIME = datetime.now()
    
    logger.info("Meeting Transcription Service starting...")
    logger.info(f"Temp directory: {TEMP_DIR}")
    TEMP_DIR.mkdir(parents=True, exist_ok=True)


@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown."""
    logger.info("Shutting down...")
    engine = get_engine()
    engine.unload_model()


def _cleanup_temp_files(*paths: Path) -> None:
    """Remove temporary files."""
    for path in paths:
        try:
            if path.exists():
                path.unlink()
        except Exception as e:
            logger.warning(f"Failed to cleanup {path}: {e}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8765)
