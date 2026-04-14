#!/bin/bash
# PREPARE.sh - Run this on an ONLINE computer.
#
# UNIFIED BUNDLE: This repo already contains hloc source + LightGlue + all model
# weights. PREPARE.sh only needs to download:
#   - Python wheels (PyTorch + CUDA + scientific libs + hloc deps)
#   - Miniconda Python 3.12 installer (fallback for systems with Python < 3.10)
#
# After this finishes, the bundle is 100% self-contained for offline install.
#
# FLAGS:
#   --skip-wheels        Don't download Python wheels (you already have them)
#   --skip-miniconda     Don't download Miniconda (target has Python 3.10+)
#
# EXAMPLES:
#   bash PREPARE.sh                    # download wheels + Miniconda
#   bash PREPARE.sh --skip-wheels      # only fetch Miniconda
#   bash PREPARE.sh --skip-wheels --skip-miniconda  # nothing downloaded
#
# Requirements:
#   - Python 3.10+
#   - pip, wget or curl
#   - Internet access to pypi.org, download.pytorch.org, repo.anaconda.com

set -e

# ============================================
# Parse flags
# ============================================
SKIP_WHEELS=false
SKIP_MINICONDA=false

for arg in "$@"; do
    case $arg in
        --skip-wheels)
            SKIP_WHEELS=true
            ;;
        --skip-miniconda)
            SKIP_MINICONDA=true
            ;;
        -h|--help)
            grep '^#' "$0" | head -30
            exit 0
            ;;
        *)
            echo "Unknown flag: $arg"
            echo "Run 'bash PREPARE.sh --help' for usage."
            exit 1
            ;;
    esac
done

echo "============================================"
echo "  PREPARE.sh (unified bundle)"
echo "============================================"
echo ""
echo "Flags:"
echo "  Download Python wheels:  $([ "$SKIP_WHEELS" = "true" ] && echo 'SKIP' || echo 'YES')"
echo "  Download Miniconda:      $([ "$SKIP_MINICONDA" = "true" ] && echo 'SKIP' || echo 'YES')"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WHEELS_DIR="$SCRIPT_DIR/wheels"

mkdir -p "$WHEELS_DIR"

# ============================================
# Step 0: Check requirements
# ============================================
echo "[0/3] Checking requirements on this machine..."

if ! command -v python3 &> /dev/null; then
    echo "  ERROR: python3 not found"
    exit 1
fi

PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "  Python: $PY_VER"
if [ "$(printf '%s\n' "3.10" "$PY_VER" | sort -V | head -n1)" != "3.10" ]; then
    echo "  ERROR: Python 3.10+ required (you have $PY_VER)"
    echo "  NOTE: Python version must match the offline server!"
    exit 1
fi

if [ "$SKIP_WHEELS" = "false" ]; then
    if ! curl -s --max-time 5 https://pypi.org/ > /dev/null; then
        echo "  ERROR: Cannot reach pypi.org (needed for wheels)"
        exit 1
    fi
    echo "  pypi.org: OK"
fi

# ============================================
# Step 1: Download wheels (PyTorch + deps + scientific + hloc deps)
# ============================================
if [ "$SKIP_WHEELS" = "true" ]; then
    echo ""
    echo "[1/3] SKIPPED - wheel downloads"
else
    echo ""
    echo "[1/3] Downloading PyTorch + CUDA + scientific + hloc deps (~2 GB)..."

    # PyTorch with all its CUDA deps (no --no-deps, so nvidia-*-cu12 wheels come along)
    pip download -d "$WHEELS_DIR" \
        "torch==2.7.1+cu126" "torchvision==0.22.1+cu126" \
        --index-url https://download.pytorch.org/whl/cu126 2>&1 | tail -3

    # Scientific + hloc dependencies (--no-deps to avoid dup resolution)
    pip download -d "$WHEELS_DIR" --no-deps \
        numpy==2.4.4 opencv-python==4.13.0.92 scipy==1.17.1 h5py==3.16.0 pillow==12.2.0 \
        pycolmap==4.0.3 kornia==0.8.2 kornia_rs==0.1.10 gdown==5.2.1 tqdm==4.67.3 \
        matplotlib==3.10.8 plotly==6.7.0 \
        beautifulsoup4==4.14.3 soupsieve==2.8.3 requests==2.33.1 urllib3==2.6.3 \
        idna==3.11 certifi==2026.2.25 charset_normalizer==3.4.7 PySocks==1.7.1 \
        contourpy==1.3.3 cycler==0.12.1 fonttools==4.62.1 kiwisolver==1.5.0 \
        pyparsing==3.3.2 python-dateutil==2.9.0.post0 six==1.17.0 narwhals==2.19.0 \
        packaging==26.0 filelock==3.25.2 typing_extensions==4.15.0 networkx==3.6.1 \
        jinja2==3.1.6 fsspec==2026.3.0 sympy==1.14.0 mpmath==1.3.0 markupsafe==3.0.3 \
        pip wheel setuptools 2>&1 | tail -3

    echo "  Done."
fi

# ============================================
# Step 2: Download Miniconda installer
# ============================================
MINICONDA_INSTALLER="$SCRIPT_DIR/Miniconda3-py312-Linux-x86_64.sh"
if [ "$SKIP_MINICONDA" = "true" ]; then
    echo ""
    echo "[2/3] SKIPPED - Miniconda installer"
else
    echo ""
    echo "[2/3] Downloading Miniconda Python 3.12 installer (~140 MB)..."
    if [ -f "$MINICONDA_INSTALLER" ]; then
        echo "  Miniconda installer already exists, skipping"
    else
        MC_URL="https://repo.anaconda.com/miniconda/Miniconda3-py312_24.11.1-0-Linux-x86_64.sh"
        if command -v wget &> /dev/null; then
            wget -q -O "$MINICONDA_INSTALLER" "$MC_URL"
        elif command -v curl &> /dev/null; then
            curl -sL -o "$MINICONDA_INSTALLER" "$MC_URL"
        else
            echo "  ERROR: neither wget nor curl found"
            exit 1
        fi
        echo "  Downloaded: $(du -h "$MINICONDA_INSTALLER" | cut -f1)"
    fi
    echo "  Done."
fi

# ============================================
# Step 3: Summary
# ============================================
echo ""
echo "[3/3] Bundle summary:"
echo ""
echo "  hloc_source/       : $(du -sh "$SCRIPT_DIR/hloc_source" 2>/dev/null | cut -f1 || echo 'missing')"
echo "  lightglue_wheel/   : $(du -sh "$SCRIPT_DIR/lightglue_wheel" 2>/dev/null | cut -f1 || echo 'missing')"
echo "  model_cache/       : $(du -sh "$SCRIPT_DIR/model_cache" | cut -f1)"
echo "  superglue_weights/ : $(du -sh "$SCRIPT_DIR/superglue_weights" 2>/dev/null | cut -f1 || echo 'n/a')"
echo "  wheels/            : $(du -sh "$WHEELS_DIR" 2>/dev/null | cut -f1 || echo 'empty')"
echo "  Miniconda:         : $([ -f "$MINICONDA_INSTALLER" ] && du -h "$MINICONDA_INSTALLER" | cut -f1 || echo 'missing')"
echo ""
echo "  Total bundle size  : $(du -sh "$SCRIPT_DIR" | cut -f1)"
echo ""
echo "============================================"
echo "  PREPARE complete!"
echo ""
echo "  Next steps:"
echo "    1. Pack this folder:"
echo "         cd .. && tar czf hloc_ready.tar.gz --exclude='.git' $(basename "$SCRIPT_DIR")"
echo "    2. Transfer hloc_ready.tar.gz to the offline server (USB/SFTP)"
echo "    3. On the offline server:"
echo "         tar xzf hloc_ready.tar.gz"
echo "         cd $(basename "$SCRIPT_DIR")"
echo "         bash INSTALL.sh"
echo "============================================"
