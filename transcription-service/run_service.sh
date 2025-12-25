#!/bin/bash
# Run transcription service with MPS acceleration enabled

set -e

# Enable MPS fallback for unsupported PyTorch operations
export PYTORCH_ENABLE_MPS_FALLBACK=1

# Navigate to script directory
cd "$(dirname "$0")"

# Find Python 3.10+
find_python() {
    for py in python3.12 python3.11 python3.10 python3; do
        if command -v "$py" &> /dev/null; then
            version=$("$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
            major=$(echo "$version" | cut -d. -f1)
            minor=$(echo "$version" | cut -d. -f2)
            if [ "$major" -ge 3 ] && [ "$minor" -ge 10 ]; then
                echo "$py"
                return 0
            fi
        fi
    done
    echo ""
    return 1
}

PYTHON=$(find_python)

if [ -z "$PYTHON" ]; then
    echo "❌ Erro: Python 3.10+ é necessário."
    echo "   Instale via: brew install python@3.11"
    exit 1
fi

echo "✅ Usando Python: $PYTHON ($($PYTHON --version))"

# Check if virtual environment exists and uses correct Python
if [ -d "venv" ]; then
    VENV_PYTHON=$(./venv/bin/python --version 2>&1 | grep -oE '[0-9]+\.[0-9]+')
    VENV_MAJOR=$(echo "$VENV_PYTHON" | cut -d. -f1)
    VENV_MINOR=$(echo "$VENV_PYTHON" | cut -d. -f2)
    
    if [ "$VENV_MAJOR" -lt 3 ] || [ "$VENV_MINOR" -lt 10 ]; then
        echo "⚠️  Venv usa Python $VENV_PYTHON. Recriando com Python 3.10+..."
        rm -rf venv
    fi
fi

if [ ! -d "venv" ]; then
    echo "📦 Criando virtual environment..."
    $PYTHON -m venv venv
    source venv/bin/activate
    echo "📥 Instalando dependências..."
    pip install --upgrade pip
    pip install -r requirements.txt
else
    source venv/bin/activate
fi

echo ""
echo "🚀 Iniciando Meeting Transcription Service..."
echo "   Device: MPS (Apple Silicon) com fallback CPU"
echo "   Server: http://127.0.0.1:8765"
echo ""

uvicorn transcription_service:app --host 127.0.0.1 --port 8765 --reload
