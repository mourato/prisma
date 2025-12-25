"""
Audio preprocessing utilities for transcription service.

Handles format conversion, resampling, and normalization
to prepare audio for Parakeet model.
"""

import logging
import uuid
from pathlib import Path
from typing import BinaryIO

import soundfile as sf
import numpy as np

logger = logging.getLogger(__name__)

# Parakeet requirements
TARGET_SAMPLE_RATE = 16000
TARGET_CHANNELS = 1  # Mono

# Supported audio formats
SUPPORTED_EXTENSIONS = {".wav", ".m4a", ".mp3", ".mp4", ".aac", ".flac", ".ogg"}

# Upload limits
MAX_FILE_SIZE_MB = 500  # 500 MB limit for audio files
MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024

# Audio normalization
NORMALIZATION_FACTOR = 0.95  # Target peak level (5% headroom to prevent clipping)


def preprocess_audio(
    input_path: str | Path,
    output_path: str | Path | None = None
) -> Path:
    """
    Preprocess audio file for Parakeet transcription.
    
    Converts to WAV format, resamples to 16kHz, and converts to mono.
    Supports WAV, M4A, MP3, MP4, AAC, FLAC, and OGG formats.
    
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
    
    # Read audio based on format
    audio_data, sample_rate = _read_audio(input_path)
    
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
    
    # Write output as WAV (for Parakeet compatibility)
    sf.write(str(output_path), audio_data, TARGET_SAMPLE_RATE)
    logger.info(f"Preprocessed audio saved: {output_path.name}")
    
    return output_path


def _read_audio(input_path: Path) -> tuple[np.ndarray, int]:
    """
    Read audio from various formats.
    
    Uses soundfile for WAV/FLAC, pydub for M4A/MP3/AAC.
    
    Args:
        input_path: Path to audio file
    
    Returns:
        Tuple of (audio_data as numpy array, sample_rate)
    """
    suffix = input_path.suffix.lower()
    
    # Soundfile handles WAV and FLAC natively
    if suffix in {".wav", ".flac"}:
        return sf.read(str(input_path))
    
    # Use pydub for compressed formats (M4A, MP3, AAC, etc.)
    # pydub uses ffmpeg backend for decoding
    if suffix in {".m4a", ".mp3", ".mp4", ".aac", ".ogg"}:
        return _read_with_pydub(input_path)
    
    # Try soundfile as fallback
    logger.warning(f"Unknown format {suffix}, attempting soundfile read")
    return sf.read(str(input_path))


def _read_with_pydub(input_path: Path) -> tuple[np.ndarray, int]:
    """
    Read audio using pydub (requires ffmpeg).
    
    Args:
        input_path: Path to audio file
    
    Returns:
        Tuple of (audio_data as numpy array, sample_rate)
    """
    from pydub import AudioSegment
    
    suffix = input_path.suffix.lower().lstrip(".")
    audio = AudioSegment.from_file(str(input_path), format=suffix)
    
    # Convert to numpy array
    sample_rate = audio.frame_rate
    samples = np.array(audio.get_array_of_samples())
    
    # Handle stereo
    if audio.channels == 2:
        samples = samples.reshape((-1, 2))
    
    # Normalize to float32 range [-1, 1]
    max_val = 2 ** (audio.sample_width * 8 - 1)
    samples = samples.astype(np.float32) / max_val
    
    logger.debug(f"Read {suffix.upper()} file: {len(samples)} samples at {sample_rate}Hz")
    return samples, sample_rate


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
    """Normalize audio to prevent clipping while preserving headroom."""
    max_val = np.abs(audio).max()
    if max_val > 0:
        audio = audio / max_val * NORMALIZATION_FACTOR
    return audio


def save_upload_to_temp(file: BinaryIO, filename: str, temp_dir: Path) -> Path:
    """
    Save uploaded file to temporary directory with validation.
    
    Args:
        file: File-like object from upload
        filename: Original filename
        temp_dir: Directory to save file
    
    Returns:
        Path to saved file
    
    Raises:
        ValueError: If file exceeds size limit or has unsupported format
    """
    temp_dir.mkdir(parents=True, exist_ok=True)
    
    # Sanitize filename - only allow alphanumeric, dots, hyphens, underscores
    safe_name = "".join(c for c in filename if c.isalnum() or c in "._-")
    
    # Handle empty or invalid filenames
    if not safe_name or len(safe_name) < 3:
        ext = Path(filename).suffix.lower() if filename else ".wav"
        if ext not in SUPPORTED_EXTENSIONS:
            ext = ".wav"
        safe_name = f"upload_{uuid.uuid4().hex[:8]}{ext}"
        logger.debug(f"Generated safe filename: {safe_name}")
    
    # Validate file extension
    ext = Path(safe_name).suffix.lower()
    if ext not in SUPPORTED_EXTENSIONS:
        raise ValueError(
            f"Unsupported audio format: {ext}. "
            f"Supported formats: {', '.join(sorted(SUPPORTED_EXTENSIONS))}"
        )
    
    output_path = temp_dir / safe_name
    
    # Read content with size limit check
    content = file.read()
    file_size = len(content)
    
    if file_size > MAX_FILE_SIZE_BYTES:
        raise ValueError(
            f"File too large: {file_size / (1024*1024):.1f} MB. "
            f"Maximum allowed: {MAX_FILE_SIZE_MB} MB"
        )
    
    if file_size == 0:
        raise ValueError("Empty file uploaded")
    
    with open(output_path, "wb") as f:
        f.write(content)
    
    logger.debug(f"Saved upload to: {output_path} ({file_size / (1024*1024):.2f} MB)")
    return output_path


def get_audio_info(audio_path: str | Path) -> dict:
    """
    Get metadata about audio file.
    
    Supports WAV, M4A, MP3, and other formats.
    
    Returns:
        Dict with duration, sample_rate, channels, format
    """
    audio_path = Path(audio_path)
    suffix = audio_path.suffix.lower()
    
    # Use pydub for compressed formats
    if suffix in {".m4a", ".mp3", ".mp4", ".aac", ".ogg"}:
        return _get_audio_info_pydub(audio_path, suffix)
    
    # Use soundfile for WAV/FLAC
    info = sf.info(str(audio_path))
    return {
        "duration_seconds": info.duration,
        "sample_rate": info.samplerate,
        "channels": info.channels,
        "format": info.format,
        "subtype": info.subtype,
    }


def _get_audio_info_pydub(audio_path: Path, suffix: str) -> dict:
    """Get audio info using pydub."""
    from pydub import AudioSegment
    
    format_name = suffix.lstrip(".")
    audio = AudioSegment.from_file(str(audio_path), format=format_name)
    
    return {
        "duration_seconds": len(audio) / 1000.0,
        "sample_rate": audio.frame_rate,
        "channels": audio.channels,
        "format": format_name.upper(),
        "subtype": f"{audio.sample_width * 8}-bit",
    }


def is_supported_format(filename: str) -> bool:
    """Check if file format is supported."""
    suffix = Path(filename).suffix.lower()
    return suffix in SUPPORTED_EXTENSIONS
