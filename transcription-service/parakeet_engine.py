"""
Parakeet TDT 0.6B v3 transcription engine wrapper.

Provides multilingual speech-to-text using NVIDIA's Parakeet model
optimized for Apple Silicon (MPS backend).
"""

import os
import logging
from pathlib import Path
from dataclasses import dataclass

# Enable MPS fallback for unsupported operations
os.environ["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"

import torch
import nemo.collections.asr as nemo_asr

logger = logging.getLogger(__name__)

# Constants
MODEL_NAME = "nvidia/parakeet-tdt-0.6b-v3"
CHUNK_DURATION_SECONDS = 1200  # 20 minutes per chunk
OVERLAP_SECONDS = 30
SAMPLE_RATE = 16000


@dataclass
class TranscriptionSegment:
    """Represents a segment of transcribed text with timing."""
    
    text: str
    start_time: float
    end_time: float


@dataclass
class TranscriptionResult:
    """Complete transcription result with metadata."""
    
    text: str
    segments: list[TranscriptionSegment]
    language: str
    duration_seconds: float
    model_name: str


class ParakeetEngine:
    """
    Wrapper for Parakeet TDT 0.6B v3 model.
    
    Handles model loading, device selection (MPS/CPU),
    and audio transcription with chunking for long files.
    """
    
    def __init__(self):
        self._model = None
        self._device = self._select_device()
        logger.info(f"ParakeetEngine initialized with device: {self._device}")
    
    def _select_device(self) -> str:
        """Select best available device (MPS > CPU)."""
        if torch.backends.mps.is_available():
            return "mps"
        return "cpu"
    
    def load_model(self) -> None:
        """
        Load Parakeet model from Hugging Face.
        
        Downloads on first run (~1.2GB), then uses cache.
        """
        if self._model is not None:
            logger.debug("Model already loaded, skipping")
            return
        
        logger.info(f"Loading model: {MODEL_NAME}")
        self._model = nemo_asr.models.ASRModel.from_pretrained(MODEL_NAME)
        self._model = self._model.to(self._device)
        self._model.eval()
        logger.info("Model loaded successfully")
    
    def unload_model(self) -> None:
        """Unload model to free memory."""
        if self._model is not None:
            del self._model
            self._model = None
            if self._device == "mps":
                torch.mps.empty_cache()
            logger.info("Model unloaded")
    
    def transcribe(self, audio_path: str | Path) -> TranscriptionResult:
        """
        Transcribe audio file to text.
        
        Args:
            audio_path: Path to WAV file (16kHz, mono recommended)
        
        Returns:
            TranscriptionResult with full text and segments
        
        Raises:
            FileNotFoundError: If audio file doesn't exist
            RuntimeError: If transcription fails
        """
        audio_path = Path(audio_path)
        if not audio_path.exists():
            raise FileNotFoundError(f"Audio file not found: {audio_path}")
        
        self.load_model()
        
        logger.info(f"Transcribing: {audio_path.name}")
        
        try:
            # NeMo transcribe returns list of transcriptions
            output = self._model.transcribe([str(audio_path)])
            
            # Extract text from output
            if isinstance(output, list) and len(output) > 0:
                text = output[0] if isinstance(output[0], str) else output[0].text
            else:
                text = str(output)
            
            # Get audio duration
            duration = self._get_audio_duration(audio_path)
            
            # Build result
            result = TranscriptionResult(
                text=text.strip(),
                segments=[
                    TranscriptionSegment(
                        text=text.strip(),
                        start_time=0.0,
                        end_time=duration
                    )
                ],
                language="pt",  # Parakeet auto-detects, but PT is primary
                duration_seconds=duration,
                model_name=MODEL_NAME
            )
            
            logger.info(f"Transcription complete: {len(text)} characters")
            return result
            
        except Exception as e:
            logger.error(f"Transcription failed: {e}")
            raise RuntimeError(f"Transcription failed: {e}") from e
    
    def _get_audio_duration(self, audio_path: Path) -> float:
        """Get duration of audio file in seconds."""
        try:
            import soundfile as sf
            info = sf.info(str(audio_path))
            return info.duration
        except Exception as e:
            logger.warning(f"Failed to get audio duration for {audio_path.name}: {e}")
            return 0.0
    
    @property
    def is_loaded(self) -> bool:
        """Check if model is currently loaded."""
        return self._model is not None
    
    @property
    def device(self) -> str:
        """Get current device (mps or cpu)."""
        return self._device


# Singleton instance for reuse
_engine_instance: ParakeetEngine | None = None


def get_engine() -> ParakeetEngine:
    """Get or create singleton ParakeetEngine instance."""
    global _engine_instance
    if _engine_instance is None:
        _engine_instance = ParakeetEngine()
    return _engine_instance
