#!/bin/bash
# INSTALL.sh - Install hloc on the target server.
#
# UNIFIED BUNDLE: This repo contains everything (hloc source, LightGlue wheel,
# model weights). After running PREPARE.sh on an online PC (for Python wheels
# and Miniconda), this script installs completely offline.
#
# WHAT THIS INSTALLS:
#   - PyTorch 2.7.1+cu126 + torchvision + bundled CUDA libs
#   - numpy, opencv, scipy, h5py, pillow         (scientific computing)
#   - pycolmap, kornia, gdown, matplotlib, ...   (hloc direct dependencies)
#   - hloc (from bundled hloc_source/ folder)
#   - LightGlue (from bundled lightglue_wheel/*.whl)
#   - Pre-downloaded model weights (NetVLAD, SuperGlue, LightGlue)
#
# FALLBACK: If system Python is older than 3.10, auto-installs bundled
# Miniconda Python 3.12 to ~/miniconda3/ (no sudo needed).
#
# TWO MODES:
#   1. OFFLINE: wheels/ folder populated (from PREPARE.sh) -> uses local files
#   2. ONLINE:  no wheels/ folder -> downloads from PyPI at install time

set -e

echo "============================================"
echo "  hloc Installer (unified bundle)"
echo "============================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/hloc_offline"
WHEELS_DIR="$SCRIPT_DIR/wheels"
HLOC_SOURCE="$SCRIPT_DIR/hloc_source"
LIGHTGLUE_WHEEL_DIR="$SCRIPT_DIR/lightglue_wheel"

# ============================================
# Sanity check: bundled components must exist
# ============================================
if [ ! -d "$HLOC_SOURCE" ]; then
    echo "ERROR: hloc_source/ folder not found in bundle."
    echo "This bundle appears incomplete. Re-clone the repo."
    exit 1
fi

if [ ! -d "$LIGHTGLUE_WHEEL_DIR" ] || [ -z "$(ls -A "$LIGHTGLUE_WHEEL_DIR"/*.whl 2>/dev/null)" ]; then
    echo "ERROR: lightglue_wheel/*.whl not found in bundle."
    echo "This bundle appears incomplete. Re-clone the repo."
    exit 1
fi

# ============================================
# Detect offline vs online mode
# ============================================
OFFLINE_MODE=false
if [ -d "$WHEELS_DIR" ] && [ -n "$(ls -A "$WHEELS_DIR"/torch-*.whl 2>/dev/null)" ]; then
    OFFLINE_MODE=true
    echo "Mode: OFFLINE (using local wheels + bundled hloc_source)"
else
    echo "Mode: ONLINE (will download wheels from PyPI)"
    echo ""
    echo "  NOTE: For offline install, first run bash PREPARE.sh"
    echo "        on an online computer to download everything."
fi
echo ""

# ============================================
# Step 0: Prerequisites check (+ Miniconda fallback)
# ============================================
echo "[0/6] Checking prerequisites..."

PYTHON_BIN="python3"

if ! command -v python3 &> /dev/null; then
    echo "  System python3 not found."
    PY_VER="none"
else
    PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    echo "  System Python: $PY_VER"
fi

PYTHON_OK=true
if [ "$PY_VER" = "none" ]; then
    PYTHON_OK=false
elif [ "$(printf '%s\n' "3.10" "$PY_VER" | sort -V | head -n1)" != "3.10" ]; then
    PYTHON_OK=false
fi

if [ "$PYTHON_OK" = "false" ]; then
    echo "  System Python is too old or missing."
    MINICONDA_INSTALLER="$SCRIPT_DIR/Miniconda3-py312-Linux-x86_64.sh"
    if [ -f "$MINICONDA_INSTALLER" ]; then
        if [ ! -d "$HOME/miniconda3" ]; then
            echo "  Installing bundled Miniconda (Python 3.12) to ~/miniconda3..."
            bash "$MINICONDA_INSTALLER" -b -p "$HOME/miniconda3"
        else
            echo "  ~/miniconda3 already exists, reusing."
        fi
        export PATH="$HOME/miniconda3/bin:$PATH"
        PYTHON_BIN="$HOME/miniconda3/bin/python3"
        PY_VER=$("$PYTHON_BIN" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
        echo "  Using Miniconda Python: $PY_VER"
    else
        echo "  ERROR: Python 3.10+ required (you have $PY_VER), and"
        echo "         Miniconda installer not found at: $MINICONDA_INSTALLER"
        echo ""
        echo "  Fix: run PREPARE.sh on an online machine first to download Miniconda,"
        echo "       or upgrade your system Python to 3.10+."
        exit 1
    fi
fi

if command -v nvidia-smi &> /dev/null; then
    GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
    echo "  GPU: $GPU"
else
    echo "  WARNING: nvidia-smi not found - GPU may not be available"
fi

# ============================================
# Step 1: Create venv
# ============================================
echo ""
echo "[1/6] Creating Python venv at ~/hloc_env..."
HLOC_ENV="$HOME/hloc_env"
if [ ! -d "$HLOC_ENV" ]; then
    "$PYTHON_BIN" -m venv "$HLOC_ENV"
fi
source "$HLOC_ENV/bin/activate"

if [ "$OFFLINE_MODE" = "true" ]; then
    pip install --no-index --find-links "$WHEELS_DIR" --upgrade pip wheel setuptools 2>&1 | tail -3
else
    pip install --upgrade pip 2>&1 | tail -3
fi

# Set pip install args for reuse
if [ "$OFFLINE_MODE" = "true" ]; then
    PIP_ARGS="--no-index --find-links $WHEELS_DIR"
else
    PIP_ARGS=""
fi

# ============================================
# Step 2: PyTorch + CUDA
# ============================================
echo ""
echo "[2/6] Installing PyTorch 2.7.1 + CUDA 12.6..."
if [ "$OFFLINE_MODE" = "true" ]; then
    pip install $PIP_ARGS --no-deps "torch==2.7.1+cu126" "torchvision==0.22.1+cu126" 2>&1 | tail -3
    pip install $PIP_ARGS --no-deps \
        filelock typing_extensions networkx jinja2 fsspec sympy mpmath markupsafe \
        nvidia-cuda-nvrtc-cu12 nvidia-cuda-runtime-cu12 nvidia-cuda-cupti-cu12 \
        nvidia-cudnn-cu12 nvidia-cublas-cu12 nvidia-cufft-cu12 nvidia-curand-cu12 \
        nvidia-cusolver-cu12 nvidia-cusparse-cu12 nvidia-cusparselt-cu12 \
        nvidia-nccl-cu12 nvidia-nvtx-cu12 nvidia-nvjitlink-cu12 nvidia-cufile-cu12 triton 2>&1 | tail -3
else
    pip install "torch==2.7.1+cu126" "torchvision==0.22.1+cu126" \
        --index-url https://download.pytorch.org/whl/cu126 2>&1 | tail -3
fi

# ============================================
# Step 3: Scientific + hloc dependencies
# ============================================
echo ""
echo "[3/6] Installing scientific + hloc dependencies..."
if [ "$OFFLINE_MODE" = "true" ]; then
    pip install $PIP_ARGS --no-deps numpy opencv-python scipy h5py pillow 2>&1 | tail -3
    pip install $PIP_ARGS --no-deps \
        pycolmap kornia kornia_rs gdown tqdm matplotlib plotly \
        beautifulsoup4 soupsieve requests urllib3 idna certifi charset_normalizer \
        PySocks contourpy cycler fonttools kiwisolver pyparsing \
        python-dateutil six narwhals packaging 2>&1 | tail -3
else
    pip install \
        numpy==2.4.4 opencv-python==4.13.0.92 scipy==1.17.1 h5py==3.16.0 pillow==12.2.0 \
        pycolmap==4.0.3 kornia==0.8.2 kornia_rs==0.1.10 \
        gdown==5.2.1 tqdm==4.67.3 matplotlib==3.10.8 plotly==6.7.0 2>&1 | tail -3
fi

# ============================================
# Step 4: Install hloc from bundled source
# ============================================
echo ""
echo "[4/6] Installing hloc from bundled hloc_source/..."
PIP_NO_INDEX=$([ "$OFFLINE_MODE" = "true" ] && echo "1" || echo "") \
PIP_FIND_LINKS=$([ "$OFFLINE_MODE" = "true" ] && echo "$WHEELS_DIR" || echo "") \
    pip install $PIP_ARGS --no-deps "$HLOC_SOURCE" 2>&1 | tail -3

# Set up third_party module paths (SuperGlue, R2D2, D2Net, etc.)
SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")
HLOC_TP="$HLOC_SOURCE/third_party"
cat > "$SITE_PACKAGES/hloc_third_party.pth" << PTHEOF
$HLOC_TP
$HLOC_TP/SuperGluePretrainedNetwork
$HLOC_TP/d2net
$HLOC_TP/deep-image-retrieval
$HLOC_TP/r2d2
PTHEOF
echo "  third_party .pth file created"

# ============================================
# Step 5: Install LightGlue from bundled wheel
# ============================================
echo ""
echo "[5/6] Installing LightGlue from bundled wheel..."
pip install --no-deps "$LIGHTGLUE_WHEEL_DIR"/lightglue-*.whl 2>&1 | tail -3

# ============================================
# Step 6: Copy pre-downloaded model weights
# ============================================
echo ""
echo "[6/6] Copying pre-downloaded model weights..."

mkdir -p "$HOME/.cache/torch/hub/netvlad"
mkdir -p "$HOME/.cache/torch/hub/checkpoints"

NETVLAD_DIR="$SCRIPT_DIR/model_cache/torch/hub/netvlad"
NETVLAD_FILE="$NETVLAD_DIR/VGG16-NetVLAD-Pitts30K.mat"

# Reassemble NetVLAD from split parts if needed (GitHub 100MB limit workaround)
if [ ! -f "$NETVLAD_FILE" ] && ls "$NETVLAD_DIR"/VGG16-NetVLAD-Pitts30K.mat.part_* 1> /dev/null 2>&1; then
    echo "  Reassembling NetVLAD weights from chunks..."
    cat "$NETVLAD_DIR"/VGG16-NetVLAD-Pitts30K.mat.part_* > "$NETVLAD_FILE"
    echo "  Reassembled: $(du -h "$NETVLAD_FILE" | cut -f1)"
fi

if [ -f "$NETVLAD_FILE" ]; then
    cp "$NETVLAD_FILE" "$HOME/.cache/torch/hub/netvlad/"
    echo "  NetVLAD weights copied (528 MB)"
fi

if [ -f "$SCRIPT_DIR/model_cache/torch/hub/checkpoints/superpoint_lightglue_v0-1_arxiv.pth" ]; then
    cp "$SCRIPT_DIR/model_cache/torch/hub/checkpoints/superpoint_lightglue_v0-1_arxiv.pth" \
       "$HOME/.cache/torch/hub/checkpoints/"
    echo "  LightGlue weights copied (45 MB)"
fi

# SuperGlue weights: overwrite/populate hloc_source's SuperGlue submodule folder
SG_DIR="$HLOC_SOURCE/third_party/SuperGluePretrainedNetwork/models/weights"
if [ -d "$SG_DIR" ] && [ -d "$SCRIPT_DIR/superglue_weights" ]; then
    cp "$SCRIPT_DIR/superglue_weights/"*.pth "$SG_DIR/" 2>/dev/null || true
    echo "  SuperGlue weights copied to hloc_source"
fi

# ============================================
# Verify
# ============================================
echo ""
echo "Verifying installation..."
python3 << 'PYCHECK'
import torch
print("  PyTorch:", torch.__version__)
print("  CUDA available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("  GPU:", torch.cuda.get_device_name(0))
    print("  cuDNN:", torch.backends.cudnn.version())
import hloc
print("  hloc:", hloc.__version__)
from hloc.extractors.superpoint import SuperPoint
from hloc.matchers.superglue import SuperGlue
from hloc.matchers.lightglue import LightGlue
print("  SuperPoint, SuperGlue, LightGlue: OK")
print("")
print("  >>> Installation SUCCESS <<<")
PYCHECK

echo ""
echo "============================================"
echo "  Installation complete!"
echo ""
echo "  To use hloc:"
echo "    source ~/hloc_env/bin/activate"
echo "    python3 your_script.py"
echo ""
echo "  Quick demo:"
echo "    source ~/hloc_env/bin/activate"
echo "    cd $HLOC_SOURCE"
echo "    python3 demo.py  # (or adapt Sacre Coeur example from README)"
echo "============================================"
