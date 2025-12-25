#!/bin/bash
# Run transcription service with MPS acceleration enabled

set -e

# Enable MPS fallback for unsupported PyTorch operations
export PYTORCH_ENABLE_MPS_FALLBACK=1

# Navigate to script directory
cd "$(dirname "$0")"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    echo "Installing dependencies..."
    pip install --upgrade pip
    pip install -r requirements.txt
else
    source venv/bin/activate
fi

echo "Starting Meeting Transcription Service..."
echo "Device: MPS (Apple Silicon) with CPU fallback"
echo "Server: http://127.0.0.1:8765"
echo ""

uvicorn transcription_service:app --host 127.0.0.1 --port 8765 --reload
