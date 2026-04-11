#!/bin/bash
# INSTALL.sh - Install hloc on the target server.
#
# WHAT THIS INSTALLS:
#   - PyTorch 2.7.1+cu126 + torchvision + bundled CUDA libs
#   - numpy, opencv, scipy, h5py, pillow         (scientific computing)
#   - pycolmap, kornia, gdown, matplotlib, ...   (hloc direct dependencies)
#   - hloc itself (cloned from GitHub + pip install -e .)
#   - LightGlue (from GitHub)
#   - Pre-downloaded model weights (NetVLAD, SuperGlue, LightGlue weights)
#
# NOT installed (comes free with Python):
#   - Python standard library (os, sys, pathlib, json, re, collections, ...)
#   - ~200 built-in modules you don't need to install
#
# Only ~13 direct packages are installed explicitly. Pip automatically pulls
# in the ~25 transitive deps (contourpy, cycler, requests, etc.).
#
# TWO MODES:
#   1. ONLINE  mode: if wheels/ folder is empty, downloads from PyPI/GitHub
#   2. OFFLINE mode: if wheels/ and hloc_repo/ exist (after running PREPARE.sh),
#                    installs from local files only (no internet needed)
#
# To use offline mode:
#   1. On an online computer, run:  bash PREPARE.sh
#   2. Transfer the whole folder to the offline server
#   3. On the offline server, run:  bash INSTALL.sh

set -e

echo "============================================"
echo "  hloc Installer"
echo "============================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WHEELS_DIR="$SCRIPT_DIR/wheels"
HLOC_REPO_DIR="$SCRIPT_DIR/hloc_repo"

# ============================================
# Detect mode
# ============================================
OFFLINE_MODE=false
if [ -d "$WHEELS_DIR" ] && [ -d "$HLOC_REPO_DIR" ] && \
   [ -n "$(ls -A "$WHEELS_DIR"/torch-*.whl 2>/dev/null)" ] && \
   [ -f "$HLOC_REPO_DIR/setup.py" ]; then
    OFFLINE_MODE=true
    echo "Mode: OFFLINE (using local wheels + hloc_repo)"
else
    echo "Mode: ONLINE (will download from PyPI + GitHub)"
    echo ""
    echo "  NOTE: For offline install, first run bash PREPARE.sh"
    echo "        on an online computer to download everything."
fi
echo ""

# ============================================
# Step 0: Prerequisites check
# ============================================
echo "[0/7] Checking prerequisites..."

if ! command -v python3 &> /dev/null; then
    echo "  ERROR: python3 not found"
    exit 1
fi

PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "  Python: $PY_VER"
if [ "$(printf '%s\n' "3.10" "$PY_VER" | sort -V | head -n1)" != "3.10" ]; then
    echo "  ERROR: Python 3.10+ required (you have $PY_VER)"
    exit 1
fi

if command -v nvidia-smi &> /dev/null; then
    GPU=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
    echo "  GPU: $GPU"
else
    echo "  WARNING: nvidia-smi not found - GPU may not be available"
fi

if [ "$OFFLINE_MODE" = "false" ] && ! command -v git &> /dev/null; then
    echo "  ERROR: git not found (needed for online mode)"
    exit 1
fi

# ============================================
# Step 1: venv
# ============================================
echo ""
echo "[1/7] Creating Python venv at ~/hloc_env..."
if [ ! -d "$HOME/hloc_env" ]; then
    python3 -m venv "$HOME/hloc_env"
fi
source "$HOME/hloc_env/bin/activate"

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
# Step 2: PyTorch
# ============================================
echo ""
echo "[2/7] Installing PyTorch 2.7.1 + CUDA 12.6..."
if [ "$OFFLINE_MODE" = "true" ]; then
    pip install $PIP_ARGS --no-deps "torch==2.7.1+cu126" "torchvision==0.22.1+cu126" 2>&1 | tail -5
    # Install torch's pure-Python deps from local wheels
    pip install $PIP_ARGS --no-deps \
        filelock typing_extensions networkx jinja2 fsspec sympy mpmath markupsafe \
        nvidia-cuda-nvrtc-cu12 nvidia-cuda-runtime-cu12 nvidia-cuda-cupti-cu12 \
        nvidia-cudnn-cu12 nvidia-cublas-cu12 nvidia-cufft-cu12 nvidia-curand-cu12 \
        nvidia-cusolver-cu12 nvidia-cusparse-cu12 nvidia-cusparselt-cu12 \
        nvidia-nccl-cu12 nvidia-nvtx-cu12 nvidia-nvjitlink-cu12 nvidia-cufile-cu12 triton 2>&1 | tail -3
else
    pip install "torch==2.7.1+cu126" "torchvision==0.22.1+cu126" \
        --index-url https://download.pytorch.org/whl/cu126 2>&1 | tail -5
fi

# ============================================
# Step 3: Scientific libs
# ============================================
echo ""
echo "[3/7] Installing numpy, opencv, scipy, h5py, pillow..."
if [ "$OFFLINE_MODE" = "true" ]; then
    pip install $PIP_ARGS --no-deps numpy opencv-python scipy h5py pillow 2>&1 | tail -3
else
    pip install \
        numpy==2.4.4 opencv-python==4.13.0.92 scipy==1.17.1 \
        h5py==3.16.0 pillow==12.2.0 2>&1 | tail -3
fi

# ============================================
# Step 4: hloc dependencies
# ============================================
echo ""
echo "[4/7] Installing hloc dependencies..."
if [ "$OFFLINE_MODE" = "true" ]; then
    pip install $PIP_ARGS --no-deps \
        pycolmap kornia kornia_rs gdown tqdm matplotlib plotly \
        beautifulsoup4 soupsieve requests urllib3 idna certifi charset_normalizer \
        PySocks contourpy cycler fonttools kiwisolver pyparsing \
        python-dateutil six narwhals packaging 2>&1 | tail -5
else
    pip install \
        pycolmap==4.0.3 kornia==0.8.2 kornia_rs==0.1.10 \
        gdown==5.2.1 tqdm==4.67.3 matplotlib==3.10.8 plotly==6.7.0 2>&1 | tail -5
fi

# ============================================
# Step 5: Clone/install hloc
# ============================================
echo ""
echo "[5/7] Installing hloc..."
if [ "$OFFLINE_MODE" = "true" ]; then
    PIP_NO_INDEX=1 PIP_FIND_LINKS="$WHEELS_DIR" \
        pip install $PIP_ARGS --no-deps "$HLOC_REPO_DIR" 2>&1 | tail -5
    # Set up third_party module paths
    SITE_PACKAGES=$(python3 -c "import site; print(site.getsitepackages()[0])")
    HLOC_TP="$HLOC_REPO_DIR/third_party"
    cat > "$SITE_PACKAGES/hloc_third_party.pth" << PTHEOF
$HLOC_TP
$HLOC_TP/SuperGluePretrainedNetwork
$HLOC_TP/d2net
$HLOC_TP/deep-image-retrieval
$HLOC_TP/r2d2
PTHEOF
    echo "  third_party .pth file created"
else
    if [ ! -d "$HOME/hloc_repo" ]; then
        git clone --recursive https://github.com/cvg/Hierarchical-Localization.git "$HOME/hloc_repo"
    fi
    cd "$HOME/hloc_repo"
    pip install -e . 2>&1 | tail -5
    cd "$SCRIPT_DIR"
fi

# ============================================
# Step 6: LightGlue
# ============================================
echo ""
echo "[6/7] Installing LightGlue..."
if [ "$OFFLINE_MODE" = "true" ]; then
    pip install $PIP_ARGS --no-deps lightglue 2>&1 | tail -3
else
    pip install "git+https://github.com/cvg/LightGlue.git" 2>&1 | tail -3
fi

# ============================================
# Step 7: Copy pre-downloaded model weights
# ============================================
echo ""
echo "[7/7] Copying pre-downloaded model weights..."

mkdir -p "$HOME/.cache/torch/hub/netvlad"
mkdir -p "$HOME/.cache/torch/hub/checkpoints"

NETVLAD_DIR="$SCRIPT_DIR/model_cache/torch/hub/netvlad"
NETVLAD_FILE="$NETVLAD_DIR/VGG16-NetVLAD-Pitts30K.mat"

# Reassemble NetVLAD from split parts if needed
# (GitHub's 100MB file size limit forces the file to be stored in chunks.)
if [ ! -f "$NETVLAD_FILE" ] && ls "$NETVLAD_DIR"/VGG16-NetVLAD-Pitts30K.mat.part_* 1> /dev/null 2>&1; then
    echo "  Reassembling NetVLAD weights from chunks..."
    cat "$NETVLAD_DIR"/VGG16-NetVLAD-Pitts30K.mat.part_* > "$NETVLAD_FILE"
    echo "  Reassembled: $(du -h "$NETVLAD_FILE" | cut -f1)"
fi

if [ -f "$NETVLAD_FILE" ]; then
    cp "$NETVLAD_FILE" "$HOME/.cache/torch/hub/netvlad/"
    echo "  NetVLAD weights copied (528 MB)"
else
    echo "  WARNING: NetVLAD weights not found in bundle"
fi

if [ -f "$SCRIPT_DIR/model_cache/torch/hub/checkpoints/superpoint_lightglue_v0-1_arxiv.pth" ]; then
    cp "$SCRIPT_DIR/model_cache/torch/hub/checkpoints/superpoint_lightglue_v0-1_arxiv.pth" \
       "$HOME/.cache/torch/hub/checkpoints/"
    echo "  LightGlue weights copied (45 MB)"
fi

# SuperGlue weights into repo submodule folder
if [ "$OFFLINE_MODE" = "true" ]; then
    SG_DIR="$HLOC_REPO_DIR/third_party/SuperGluePretrainedNetwork/models/weights"
else
    SG_DIR="$HOME/hloc_repo/third_party/SuperGluePretrainedNetwork/models/weights"
fi
if [ -d "$SG_DIR" ] && [ -d "$SCRIPT_DIR/superglue_weights" ]; then
    cp "$SCRIPT_DIR/superglue_weights/"*.pth "$SG_DIR/" 2>/dev/null || true
    echo "  SuperGlue weights copied to repo"
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
echo "============================================"
