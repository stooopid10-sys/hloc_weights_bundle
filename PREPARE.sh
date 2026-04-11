#!/bin/bash
# PREPARE.sh - Run this on an ONLINE computer with GitHub and/or PyPI access.
#
# This script downloads all Python wheels and the hloc repository into this
# bundle folder, making it ready for offline installation on the target server.
#
# FLAGS:
#   --skip-wheels        Don't download Python wheels (you already have them
#                        in wheels/, or will provide them separately)
#   --skip-hloc-repo     Don't clone hloc repo (you already have it)
#   --skip-lightglue     Don't build LightGlue wheel (you already have it)
#   --skip-miniconda     Don't download Miniconda (you know target has Python 3.10+)
#   --github-only        Equivalent to --skip-wheels (only fetches from GitHub)
#
# EXAMPLES:
#   bash PREPARE.sh                     # download everything (wheels + repos)
#   bash PREPARE.sh --github-only       # only clone hloc + LightGlue from GitHub
#   bash PREPARE.sh --skip-hloc-repo    # only download wheels
#
# After this script finishes:
#   1. Pack: cd .. && tar czf hloc_ready.tar.gz hloc_weights_bundle
#   2. Transfer via USB to the offline server
#   3. Run INSTALL.sh on the offline server (no internet needed)
#
# Requirements on this computer:
#   - Python 3.10+  (same minor version as the offline server)
#   - pip, git, curl
#   - Internet access to whichever sources you aren't skipping

set -e

# ============================================
# Parse flags
# ============================================
SKIP_WHEELS=false
SKIP_HLOC_REPO=false
SKIP_LIGHTGLUE=false
SKIP_MINICONDA=false

for arg in "$@"; do
    case $arg in
        --skip-wheels|--github-only)
            SKIP_WHEELS=true
            ;;
        --skip-hloc-repo)
            SKIP_HLOC_REPO=true
            ;;
        --skip-lightglue)
            SKIP_LIGHTGLUE=true
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
echo "  PREPARE.sh - Online computer preparation"
echo "============================================"
echo ""
echo "Flags:"
echo "  Download Python wheels:    $([ "$SKIP_WHEELS" = "true" ] && echo 'SKIP' || echo 'YES')"
echo "  Clone hloc repo:           $([ "$SKIP_HLOC_REPO" = "true" ] && echo 'SKIP' || echo 'YES')"
echo "  Build LightGlue wheel:     $([ "$SKIP_LIGHTGLUE" = "true" ] && echo 'SKIP' || echo 'YES')"
echo "  Download Miniconda:        $([ "$SKIP_MINICONDA" = "true" ] && echo 'SKIP' || echo 'YES')"
echo ""

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WHEELS_DIR="$SCRIPT_DIR/wheels"
HLOC_REPO_DIR="$SCRIPT_DIR/hloc_repo"

mkdir -p "$WHEELS_DIR"

# ============================================
# Step 0: Check requirements
# ============================================
echo "[0/6] Checking requirements on this machine..."

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

if ! command -v git &> /dev/null; then
    echo "  ERROR: git not found"
    exit 1
fi

# Test connectivity (only to sources we'll actually use)
echo "  Testing network access..."
if [ "$SKIP_WHEELS" = "false" ]; then
    if ! curl -s --max-time 5 https://pypi.org/ > /dev/null; then
        echo "  ERROR: Cannot reach pypi.org (needed for wheels)"
        exit 1
    fi
    echo "    pypi.org: OK"
fi
if [ "$SKIP_HLOC_REPO" = "false" ] || [ "$SKIP_LIGHTGLUE" = "false" ]; then
    if ! curl -s --max-time 5 https://github.com/ > /dev/null; then
        echo "  ERROR: Cannot reach github.com (needed for hloc/LightGlue)"
        exit 1
    fi
    echo "    github.com: OK"
fi

# ============================================
# Step 1: Download PyTorch 2.7.1+cu126
# ============================================
if [ "$SKIP_WHEELS" = "true" ]; then
    echo ""
    echo "[1/6] SKIPPED - PyTorch wheel download"
    if [ -z "$(ls -A "$WHEELS_DIR"/torch-*.whl 2>/dev/null)" ]; then
        echo "  WARNING: No torch wheel found in $WHEELS_DIR"
        echo "  Make sure you place the wheels there before running INSTALL.sh"
    fi
else
    echo ""
    echo "[1/6] Downloading PyTorch 2.7.1+cu126 wheels (~1.5 GB)..."
    pip download -d "$WHEELS_DIR" \
        "torch==2.7.1+cu126" "torchvision==0.22.1+cu126" \
        --index-url https://download.pytorch.org/whl/cu126 2>&1 | tail -5
    echo "  Done."
fi

# ============================================
# Step 2: Download scientific + hloc deps
# ============================================
if [ "$SKIP_WHEELS" = "true" ]; then
    echo ""
    echo "[2/6] SKIPPED - scientific + hloc deps download"
else
    echo ""
    echo "[2/6] Downloading scientific + hloc deps (~300 MB)..."
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
        pip wheel setuptools 2>&1 | tail -5
    echo "  Done."
fi

# ============================================
# Step 3: Clone hloc repository with submodules
# ============================================
if [ "$SKIP_HLOC_REPO" = "true" ]; then
    echo ""
    echo "[3/6] SKIPPED - hloc repo clone"
    if [ ! -d "$HLOC_REPO_DIR" ]; then
        echo "  WARNING: $HLOC_REPO_DIR does not exist"
        echo "  Make sure you place the hloc repo there before running INSTALL.sh"
    fi
else
    echo ""
    echo "[3/6] Cloning hloc repository with submodules (~350 MB)..."
    if [ -d "$HLOC_REPO_DIR" ]; then
        echo "  hloc_repo already exists, updating..."
        cd "$HLOC_REPO_DIR" && git pull && git submodule update --init --recursive
        cd "$SCRIPT_DIR"
    else
        git clone --recursive https://github.com/cvg/Hierarchical-Localization.git "$HLOC_REPO_DIR"
    fi
    echo "  Done."
fi

# ============================================
# Step 4: Build LightGlue wheel from source
# ============================================
if [ "$SKIP_LIGHTGLUE" = "true" ]; then
    echo ""
    echo "[4/6] SKIPPED - LightGlue wheel build"
else
    echo ""
    echo "[4/6] Building LightGlue wheel from GitHub source..."
    if ls "$WHEELS_DIR"/lightglue-*.whl 1> /dev/null 2>&1; then
        echo "  lightglue wheel already exists, skipping build"
    else
        TMPDIR=$(mktemp -d)
        git clone https://github.com/cvg/LightGlue "$TMPDIR/LightGlue" 2>&1 | tail -3
        cd "$TMPDIR/LightGlue"
        pip wheel --no-deps -w "$WHEELS_DIR" . 2>&1 | tail -3
        cd "$SCRIPT_DIR"
        rm -rf "$TMPDIR"
    fi
    echo "  Done."
fi

# ============================================
# Step 5: Download Miniconda installer (fallback for old Python)
# ============================================
MINICONDA_INSTALLER="$SCRIPT_DIR/Miniconda3-py312-Linux-x86_64.sh"
if [ "$SKIP_MINICONDA" = "true" ]; then
    echo ""
    echo "[5/6] SKIPPED - Miniconda installer download"
else
    echo ""
    echo "[5/6] Downloading Miniconda Python 3.12 installer (~140 MB)..."
    if [ -f "$MINICONDA_INSTALLER" ]; then
        echo "  Miniconda installer already exists, skipping"
    else
        # Pin to specific version that ships Python 3.12
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
# Step 5: Summary
# ============================================
echo ""
echo "[6/6] Bundle summary:"
echo ""
echo "  wheels/           : $(du -sh "$WHEELS_DIR" 2>/dev/null | cut -f1 || echo 'empty')"
echo "  hloc_repo/        : $(du -sh "$HLOC_REPO_DIR" 2>/dev/null | cut -f1 || echo 'missing')"
echo "  model_cache/      : $(du -sh "$SCRIPT_DIR/model_cache" | cut -f1)"
echo "  superglue_weights/: $(du -sh "$SCRIPT_DIR/superglue_weights" 2>/dev/null | cut -f1 || echo 'n/a')"
echo "  Miniconda:        $([ -f "$MINICONDA_INSTALLER" ] && du -h "$MINICONDA_INSTALLER" | cut -f1 || echo 'missing')"
echo ""
echo "  Total bundle size: $(du -sh "$SCRIPT_DIR" | cut -f1)"
echo ""
echo "============================================"
echo "  PREPARE complete!"
echo ""
echo "  Next steps:"
echo "    1. Pack this folder:"
echo "         cd .. && tar czf hloc_ready.tar.gz $(basename "$SCRIPT_DIR")"
echo "    2. Transfer hloc_ready.tar.gz to the offline server (USB)"
echo "    3. On the offline server:"
echo "         tar xzf hloc_ready.tar.gz"
echo "         cd $(basename "$SCRIPT_DIR")"
echo "         bash INSTALL.sh"
echo "============================================"
