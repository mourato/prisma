"""
Audio preprocessing utilities for transcription service.

Handles format conversion, resampling, and normalization
to prepare audio for Parakeet model.
"""

import logging
from pathlib import Path
from typing import BinaryIO

import soundfile as sf
import numpy as np

logger = logging.getLogger(__name__)

# Parakeet requirements
TARGET_SAMPLE_RATE = 16000
TARGET_CHANNELS = 1  # Mono


def preprocess_audio(
    input_path: str | Path,
    output_path: str | Path | None = None
) -> Path:
    """
    Preprocess audio file for Parakeet transcription.
    
    Converts to WAV format, resamples to 16kHz, and converts to mono.
    
    Args:
        input_path: Path to input audio file
        output_path: Optional output path. If None, creates temp file.
    
    Returns:
        Path to preprocessed WAV file
    """
    input_path = Path(input_path)
    
    if output_path is None:
        output_path = input_path.with_suffix(".processed.wav")
    else:
        output_path = Path(output_path)
    
    logger.info(f"Preprocessing audio: {input_path.name}")
    
    # Read audio
    audio_data, sample_rate = sf.read(str(input_path))
    
    # Convert to mono if stereo
    if len(audio_data.shape) > 1:
        audio_data = np.mean(audio_data, axis=1)
        logger.debug("Converted stereo to mono")
    
    # Resample if needed
    if sample_rate != TARGET_SAMPLE_RATE:
        audio_data = _resample(audio_data, sample_rate, TARGET_SAMPLE_RATE)
        logger.debug(f"Resampled from {sample_rate}Hz to {TARGET_SAMPLE_RATE}Hz")
    
    # Normalize audio
    audio_data = _normalize(audio_data)
    
    # Write output
    sf.write(str(output_path), audio_data, TARGET_SAMPLE_RATE)
    logger.info(f"Preprocessed audio saved: {output_path.name}")
    
    return output_path


def _resample(audio: np.ndarray, orig_sr: int, target_sr: int) -> np.ndarray:
    """Resample audio to target sample rate."""
    try:
        import librosa
        return librosa.resample(audio, orig_sr=orig_sr, target_sr=target_sr)
    except ImportError:
        # Fallback: simple decimation (lower quality)
        ratio = target_sr / orig_sr
        indices = np.round(np.arange(0, len(audio), 1/ratio)).astype(int)
        indices = indices[indices < len(audio)]
        return audio[indices]


def _normalize(audio: np.ndarray) -> np.ndarray:
    """Normalize audio to prevent clipping."""
    max_val = np.abs(audio).max()
    if max_val > 0:
        audio = audio / max_val * 0.95
    return audio


def save_upload_to_temp(file: BinaryIO, filename: str, temp_dir: Path) -> Path:
    """
    Save uploaded file to temporary directory.
    
    Args:
        file: File-like object from upload
        filename: Original filename
        temp_dir: Directory to save file
    
    Returns:
        Path to saved file
    """
    temp_dir.mkdir(parents=True, exist_ok=True)
    
    # Sanitize filename
    safe_name = "".join(c for c in filename if c.isalnum() or c in "._-")
    output_path = temp_dir / safe_name
    
    with open(output_path, "wb") as f:
        content = file.read()
        f.write(content)
    
    logger.debug(f"Saved upload to: {output_path}")
    return output_path


def get_audio_info(audio_path: str | Path) -> dict:
    """
    Get metadata about audio file.
    
    Returns:
        Dict with duration, sample_rate, channels, format
    """
    info = sf.info(str(audio_path))
    return {
        "duration_seconds": info.duration,
        "sample_rate": info.samplerate,
        "channels": info.channels,
        "format": info.format,
        "subtype": info.subtype,
    }
