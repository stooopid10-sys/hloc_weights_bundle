# hloc Offline/Online Bundle

Bundle for installing **hloc (Hierarchical-Localization)** on a target server.

**Tested on:** Ubuntu 20.04 + RTX 3060 + CUDA 12.6.3 + cuDNN 9.10.2 + Python 3.12

---

## TL;DR — Start Here

### Do you already have these Python wheels on your local PC?

```
torch==2.7.1+cu126                    numpy==2.4.4
torchvision==0.22.1+cu126             opencv-python==4.13.0.92
nvidia-cublas-cu12==12.6.4.1          scipy==1.17.1
nvidia-cuda-cupti-cu12==12.6.80       h5py==3.16.0
nvidia-cuda-nvrtc-cu12==12.6.77       pillow==12.2.0
nvidia-cuda-runtime-cu12==12.6.77     pycolmap==4.0.3
nvidia-cudnn-cu12==9.5.1.17           kornia==0.8.2
nvidia-cufft-cu12==11.3.0.4           kornia_rs==0.1.10
nvidia-cufile-cu12==1.11.1.6          gdown==5.2.1
nvidia-curand-cu12==10.3.7.77         tqdm==4.67.3
nvidia-cusolver-cu12==11.7.1.2        matplotlib==3.10.8
nvidia-cusparse-cu12==12.5.4.2        plotly==6.7.0
nvidia-cusparselt-cu12==0.6.3         triton==3.3.1
nvidia-nccl-cu12==2.26.2
nvidia-nvjitlink-cu12==12.6.85
nvidia-nvtx-cu12==12.6.77
```

(Full list with transitive deps: see `friend_requirements.txt`)

**→ YES, I have most/all of these wheels:** Jump to [**RECOMMENDED WORKFLOW**](#recommended-workflow-you-have-wheels-need-only-github) below.

**→ NO, I need everything downloaded:** Jump to [Scenario A: Full download](#scenario-a-full-download-needs-pypi--github).

**→ My target server has direct internet:** Jump to [Scenario C: Target online](#scenario-c-target-has-internet).

---

## RECOMMENDED WORKFLOW (you have wheels, need only GitHub)

**This is the most common case.** You already have Python wheels collected from other projects or internal mirrors. You only need to pull hloc's source code from GitHub (which is public and nearly always accessible).

### Step 1: Put your wheels into the bundle

```bash
tar xzf hloc_weights_bundle.tar.gz
cd hloc_weights_bundle

# Copy your existing wheels into the wheels/ folder
mkdir -p wheels
cp /path/to/your/wheel/collection/*.whl wheels/
```

**Required wheels** (see TL;DR list above). Missing any? See `friend_requirements.txt` for the exact list.

### Step 2: Fetch only GitHub content

```bash
bash PREPARE.sh --github-only
```

This skips PyPI/PyTorch downloads entirely. It only:
- Clones `https://github.com/cvg/Hierarchical-Localization` (~350 MB)
- Clones and builds `https://github.com/cvg/LightGlue` (~1 MB)

**~5 minutes**, only needs `github.com` access.

### Step 3: Pack and transfer

**On Linux/macOS** (recommended):
```bash
cd ..
tar czf hloc_ready.tar.gz --exclude='.git' hloc_weights_bundle
# Transfer via USB or SFTP to offline server
```

**IMPORTANT: On Windows**, do NOT create `.tar.gz` with Git Bash for large bundles — Git Bash's tar has known bugs with large archives containing `.git` folders, producing truncated/corrupt files that fail to extract. Instead:

- **Option A (recommended):** Transfer the `hloc_weights_bundle/` **folder directly** via Bitvise SFTP, WinSCP, or FileZilla. SFTP clients handle per-file integrity automatically.
- **Option B:** Use 7-Zip (GUI) to create the archive, not Git Bash tar.
- **Option C:** Create the tar.gz **on the online Linux machine** (the one that ran PREPARE.sh), then transfer the single `.tar.gz` file.

### Step 4: Install on the offline server

If you transferred a tar.gz:
```bash
tar xzf hloc_ready.tar.gz
cd hloc_weights_bundle
bash INSTALL.sh
```

If you transferred the folder directly:
```bash
cd hloc_weights_bundle
bash INSTALL.sh
```

Done. No internet needed on the offline server.

---

## Prerequisites on the target server

- Ubuntu 20.04+ with **NVIDIA driver** (`nvidia-smi` works)
- **CUDA 12.6 toolkit** at `/usr/local/cuda-12.6/`
- **cuDNN 9.x** at `/usr/lib/x86_64-linux-gnu/`
- **Python 3.10+** — *optional, see note below*

No sudo needed for hloc install — everything goes into `~/hloc_env/` and `~/hloc_repo/`.

### What if my Python is too old (3.8, 3.9)?

No problem. `PREPARE.sh` downloads a **Miniconda Python 3.12** installer (~141 MB) automatically. If `INSTALL.sh` detects your system Python is older than 3.10, it will:

1. Install Miniconda into `~/miniconda3/` (isolated, doesn't touch system Python)
2. Use its Python 3.12 to create the `~/hloc_env/` venv
3. Continue the install normally

Your system Python (3.8, 3.9, whatever) stays untouched. The venv uses Miniconda internally.

**TL;DR:** You don't need to upgrade Python manually. The installer handles it.

---

## Scenario A: Full download (needs PyPI + GitHub)

On an online computer with **both PyPI and GitHub access**:

```bash
# On Linux/macOS:
git clone https://github.com/stooopid10-sys/hloc_weights_bundle.git
cd hloc_weights_bundle
bash PREPARE.sh                                                  # downloads ~2 GB
cd ..
tar czf hloc_ready.tar.gz --exclude='.git' hloc_weights_bundle   # ~3 GB
```

Transfer the resulting file (or the `hloc_weights_bundle/` folder directly — see Windows note above), then on offline server:

```bash
tar xzf hloc_ready.tar.gz
cd hloc_weights_bundle
bash INSTALL.sh
```

---

## Scenario C: Target has internet

Skip `PREPARE.sh` — just run `INSTALL.sh` directly on the target:

```bash
tar xzf hloc_weights_bundle.tar.gz
cd hloc_weights_bundle
bash INSTALL.sh        # downloads everything in ~10 min
```

`INSTALL.sh` auto-detects there's no `wheels/` folder and fetches from PyPI + GitHub.

---

## PREPARE.sh flags reference

| Flag | What it skips | Use when |
|---|---|---|
| `--github-only` or `--skip-wheels` | PyTorch/numpy/etc. wheel downloads | You already have the wheels in `wheels/` folder |
| `--skip-hloc-repo` | `git clone` of hloc repo | You already have `hloc_repo/` |
| `--skip-lightglue` | LightGlue wheel build | You already have the `lightglue-*.whl` in `wheels/` |
| `--skip-miniconda` | Miniconda Python 3.12 download | Target server already has Python 3.10+ |

**Combine flags freely.** Example:
```bash
# You have wheels AND hloc repo, only need LightGlue from GitHub
bash PREPARE.sh --skip-wheels --skip-hloc-repo
```

---

## What you need to install vs. what's free

Python comes with **~200 standard library modules** for free (`os`, `sys`, `pathlib`, `json`, `re`, `collections`, etc.) — no install needed.

What you **do** need to install on top of Python:

| Category | Direct packages (you install these) | Transitive (pip resolves automatically) |
|---|---|---|
| **PyTorch + CUDA** | `torch`, `torchvision` | 15 `nvidia-*-cu12` wheels, `triton` |
| **Scientific** | `numpy`, `opencv-python`, `scipy`, `h5py`, `pillow` | (none extra) |
| **hloc deps** | `pycolmap`, `kornia`, `gdown`, `tqdm`, `matplotlib`, `plotly` | `kornia_rs`, `contourpy`, `cycler`, `fonttools`, `kiwisolver`, `pyparsing`, `python-dateutil`, `six`, `narwhals`, `packaging`, `beautifulsoup4`, `soupsieve`, `requests`, `urllib3`, `idna`, `certifi`, `charset_normalizer`, `PySocks` |
| **hloc itself** | `git clone` from GitHub + `pip install -e .` | (none — it's a local install) |
| **LightGlue** | `pip install git+https://github.com/cvg/LightGlue.git` | (none) |

**You only need ~13 explicit pip installs.** Pip automatically pulls in the ~25 transitive deps.

---

## Bundle contents

```
hloc_weights_bundle/
├── README.md                       # This file
├── PREPARE.sh                      # Run on ONLINE PC to fetch wheels/repos/Miniconda
├── INSTALL.sh                      # Run on TARGET server
├── reassemble_netvlad.sh           # Reassemble split NetVLAD file (auto-run by INSTALL.sh)
├── visualize.py                    # Generate interactive 3D HTML viewer
├── friend_requirements.txt         # Exact package versions (reference)
├── model_cache/                    # Pre-downloaded model weights (575 MB)
│   └── torch/hub/
│       ├── netvlad/
│       │   ├── VGG16-NetVLAD-Pitts30K.mat.part_01   (90 MB)
│       │   ├── VGG16-NetVLAD-Pitts30K.mat.part_02   (90 MB)
│       │   ├── VGG16-NetVLAD-Pitts30K.mat.part_03   (90 MB)
│       │   ├── VGG16-NetVLAD-Pitts30K.mat.part_04   (90 MB)
│       │   ├── VGG16-NetVLAD-Pitts30K.mat.part_05   (90 MB)
│       │   └── VGG16-NetVLAD-Pitts30K.mat.part_06   (79 MB)
│       └── checkpoints/
│           └── superpoint_lightglue_v0-1_arxiv.pth  (45 MB, GitHub releases)
└── superglue_weights/              # Pre-downloaded SuperGlue weights (97 MB)
    ├── superpoint_v1.pth
    ├── superglue_indoor.pth
    └── superglue_outdoor.pth
```

**Note about split NetVLAD file:**
`VGG16-NetVLAD-Pitts30K.mat` (528 MB) is split into 6 chunks of ~90 MB each because GitHub has a 100 MB per-file limit. `INSTALL.sh` automatically reassembles the chunks before copying to `~/.cache/torch/hub/netvlad/`. You can also run `bash reassemble_netvlad.sh` manually if you need the full `.mat` file for something else.

SHA256 of the reassembled file:
`a67d9d897d3b7942f206478e3a22a4c4c9653172ae2447041d35f6cb278fdc67`

After running `PREPARE.sh`, more files appear (these are NOT committed to git — they are generated by PREPARE.sh):
```
├── wheels/                                  # Python wheels (~2 GB if downloaded, or your existing ones)
├── hloc_repo/                               # hloc source + submodules (~350 MB)
└── Miniconda3-py312-Linux-x86_64.sh         # Miniconda Python 3.12 installer (~141 MB)
```

The Miniconda installer is used **automatically by INSTALL.sh** if the target server has Python older than 3.10. If you already have Python 3.10+ on the target, you can skip downloading it: `bash PREPARE.sh --skip-miniconda`.

---

## Daily usage (after install)

```bash
source ~/hloc_env/bin/activate
python3 your_script.py
```

---

## Quick demo (Sacre Coeur reconstruction)

```bash
source ~/hloc_env/bin/activate
cd ~/hloc_repo
python3 << 'EOF'
from pathlib import Path
from hloc import extract_features, match_features, reconstruction, pairs_from_exhaustive

images = Path("datasets/sacre_coeur")
outputs = Path("/tmp/hloc_demo")
outputs.mkdir(exist_ok=True)

feature_conf = extract_features.confs["superpoint_aachen"]
matcher_conf = match_features.confs["superglue"]
references = sorted([p.relative_to(images).as_posix() for p in (images / "mapping").iterdir()])

extract_features.main(feature_conf, images, image_list=references, feature_path=outputs/"features.h5")
pairs_from_exhaustive.main(outputs/"pairs.txt", image_list=references)
match_features.main(matcher_conf, outputs/"pairs.txt", features=outputs/"features.h5", matches=outputs/"matches.h5")
model = reconstruction.main(outputs/"sfm", images, outputs/"pairs.txt", outputs/"features.h5", outputs/"matches.h5", image_list=references)

print(f"Reconstructed: {model.num_reg_images()} cameras, {model.num_points3D()} 3D points")
EOF
```

**Expected on RTX 3060:** 10 cameras registered, ~1850 3D points, ~8 seconds total.

---

## Uninstall

```bash
rm -rf ~/hloc_env ~/hloc_repo ~/.cache/torch/hub
```

Only user-space files are touched. System Python, CUDA, and ROS are untouched.

---

## Troubleshooting

**"ERROR: ... is not a supported wheel on this platform"**
Python version mismatch. Wheels are built for a specific Python version (e.g. `cp312` = Python 3.12). Make sure your wheels match the Python version on the target server.

**"ImportError: libcudart.so.12 not found"**
CUDA 12.6 toolkit not in LD_LIBRARY_PATH. Try:
```bash
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:$LD_LIBRARY_PATH
```

**"torch.cuda.is_available() returns False"**
NVIDIA driver issue, not hloc. Run `nvidia-smi`. If it fails, driver isn't installed.

**"ModuleNotFoundError: No module named 'SuperGluePretrainedNetwork'"**
hloc's git submodules not on Python path. When cloning hloc manually, use `git clone --recursive`. `PREPARE.sh` and `INSTALL.sh` handle this automatically.

---

## Notes

- The `model_cache/` folder contains pre-downloaded model weights for components whose hosts may be firewall-blocked:
  - **NetVLAD** (`cvg-data.inf.ethz.ch`) — research server, often blocked
  - **LightGlue** (`github.com/cvg/LightGlue/releases`) — GitHub releases, sometimes blocked
- **SuperGlue/SuperPoint** weights come from GitHub submodule (`magicleap/SuperGluePretrainedNetwork`). Included as backup.
- `friend_requirements.txt` is the **exact frozen version list** from a verified working install. Use it as a reference for version pinning. In practice, you don't need to list all 57 packages — pip resolves most of them automatically when you install the ~13 direct ones.

---

## File reference

| File | What it is | Who runs it |
|---|---|---|
| `README.md` | This file | Human reads |
| `INSTALL.sh` | Auto-installer (online or offline mode) | Target server |
| `PREPARE.sh` | Downloads wheels + hloc repo for offline transfer | Online PC |
| `friend_requirements.txt` | Reference list of exact versions (pinned) | Reference only |
| `visualize.py` | Generate interactive 3D HTML from reconstruction | Target server (after demo) |
| `model_cache/` | Pre-downloaded NetVLAD + LightGlue weights | Copied to `~/.cache/torch/hub/` |
| `superglue_weights/` | Pre-downloaded SuperGlue + SuperPoint weights | Copied to repo submodule folder |
