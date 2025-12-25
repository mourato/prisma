"""
FastAPI transcription service for Meeting Assistant.

Provides REST API for audio transcription using Parakeet TDT 0.6B v3.
"""

import logging
import tempfile
from pathlib import Path
from datetime import datetime
from threading import Lock
from contextlib import asynccontextmanager

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

# Temp directory for uploads
TEMP_DIR = Path(tempfile.gettempdir()) / "meeting-assistant-uploads"

# Thread lock for service state
_state_lock = Lock()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan context manager.
    Handles startup and shutdown events.
    """
    # Startup
    global _SERVICE_START_TIME
    with _state_lock:
        _SERVICE_START_TIME = datetime.now()
    
    logger.info("Meeting Transcription Service starting...")
    logger.info(f"Temp directory: {TEMP_DIR}")
    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    
    yield  # Application runs here
    
    # Shutdown
    logger.info("Shutting down...")
    engine = get_engine()
    engine.unload_model()

# FastAPI app with lifespan
app = FastAPI(
    title="Meeting Transcription Service",
    description="Local transcription service using Parakeet TDT 0.6B v3",
    version="1.0.0",
    lifespan=lifespan
)

# Service state tracking (protected by _state_lock)
_SERVICE_START_TIME: datetime | None = None
_LAST_TRANSCRIPTION_TIME: datetime | None = None
_TOTAL_TRANSCRIPTIONS: int = 0
_TOTAL_AUDIO_PROCESSED_SECONDS: float = 0.0
_MODEL_STATE: str = "unloaded"  # "unloaded", "loading", "loaded", "error"
_MODEL_ERROR: str | None = None


def _get_service_state() -> dict:
    """Thread-safe getter for all service state."""
    with _state_lock:
        return {
            "start_time": _SERVICE_START_TIME,
            "last_transcription_time": _LAST_TRANSCRIPTION_TIME,
            "total_transcriptions": _TOTAL_TRANSCRIPTIONS,
            "total_audio_processed": _TOTAL_AUDIO_PROCESSED_SECONDS,
            "model_state": _MODEL_STATE,
            "model_error": _MODEL_ERROR,
        }


def _update_model_state(state: str, error: str | None = None) -> None:
    """Thread-safe setter for model state."""
    global _MODEL_STATE, _MODEL_ERROR
    with _state_lock:
        _MODEL_STATE = state
        _MODEL_ERROR = error


def _record_transcription(duration_seconds: float) -> None:
    """Thread-safe update after successful transcription."""
    global _LAST_TRANSCRIPTION_TIME, _TOTAL_TRANSCRIPTIONS, _TOTAL_AUDIO_PROCESSED_SECONDS
    with _state_lock:
        _LAST_TRANSCRIPTION_TIME = datetime.now()
        _TOTAL_TRANSCRIPTIONS += 1
        _TOTAL_AUDIO_PROCESSED_SECONDS += duration_seconds


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
    engine = get_engine()
    state = _get_service_state()
    
    # Calculate uptime
    uptime = 0.0
    if state["start_time"]:
        uptime = (datetime.now() - state["start_time"]).total_seconds()
    
    # Determine model state based on engine status
    model_state = state["model_state"]
    if engine.is_loaded:
        model_state = "loaded"
    elif model_state != "loading":
        if state["model_error"]:
            model_state = "error"
        else:
            model_state = "unloaded"
    
    return ServiceStatusResponse(
        status="healthy",
        model_state=model_state,
        model_loaded=engine.is_loaded,
        device=engine.device,
        model_name="nvidia/parakeet-tdt-0.6b-v3",
        uptime_seconds=uptime,
        last_transcription_time=state["last_transcription_time"].isoformat() if state["last_transcription_time"] else None,
        total_transcriptions=state["total_transcriptions"],
        total_audio_processed_seconds=state["total_audio_processed"]
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
        
        # Update service statistics (thread-safe)
        _record_transcription(result.duration_seconds)
        
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
    logger.info("Warming up model...")
    _update_model_state("loading")
    
    try:
        engine = get_engine()
        engine.load_model()
        _update_model_state("loaded")
        return {"status": "model_loaded", "device": engine.device}
    except Exception as e:
        _update_model_state("error", str(e))
        logger.error(f"Failed to load model: {e}")
        raise HTTPException(status_code=500, detail=f"Model load failed: {e}")



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
