# hloc Unified Offline Bundle

Everything needed to install **hloc (Hierarchical-Localization)** on an offline server, in **one self-contained repo**. No external GitHub repos or research-server downloads required at install time.

**Tested on:** Ubuntu 20.04 + RTX 3060 + CUDA 12.6.3 + cuDNN 9.10.2 + Python 3.12

---

## What's included (all in this repo)

- **hloc source code** (`hloc_source/`) — full v1.5 source + submodules (SuperGlue, D2Net, R2D2, deep-image-retrieval)
- **LightGlue wheel** (`lightglue_wheel/`) — pre-built, no GitHub clone needed
- **Model weights** (`model_cache/`, `superglue_weights/`) — NetVLAD (split into chunks), LightGlue, SuperGlue, SuperPoint
- **Install scripts** (`PREPARE.sh`, `INSTALL.sh`) — smart offline/online install

What's NOT included (must be downloaded by `PREPARE.sh` on an online PC):
- **Python wheels** (~2 GB) — PyTorch, CUDA libs, numpy, opencv, etc.
- **Miniconda installer** (~141 MB) — fallback if target has Python < 3.10

---

## TL;DR — 3 step workflow

### Step 1: On an ONLINE computer

```bash
git clone https://github.com/stooopid10-sys/hloc_weights_bundle.git
cd hloc_weights_bundle
bash PREPARE.sh        # downloads wheels (~2 GB) + Miniconda (~141 MB)
```

Options:
- `bash PREPARE.sh --skip-wheels` — skip wheel download (you already have them)
- `bash PREPARE.sh --skip-miniconda` — skip Miniconda (target has Python 3.10+)
- `bash PREPARE.sh --skip-wheels --skip-miniconda` — nothing downloaded (both already present)

### Step 2: Pack and transfer

```bash
cd ..
tar czf hloc_ready.tar.gz --exclude='.git' hloc_weights_bundle   # ~2.5 GB
# Transfer via USB or SFTP to offline server
```

> **Windows note:** Git Bash `tar` has known bugs with large archives. Either transfer the `hloc_weights_bundle/` folder **directly via Bitvise/WinSCP SFTP** (recommended), or use 7-Zip GUI.

### Step 3: On the OFFLINE target server

```bash
tar xzf hloc_ready.tar.gz
cd hloc_weights_bundle
bash INSTALL.sh
```

That's it. No external network access needed.

---

## Prerequisites on the target server

- Ubuntu 20.04+ with **NVIDIA driver** (`nvidia-smi` works)
- **CUDA 12.6 toolkit** at `/usr/local/cuda-12.6/`
- **cuDNN 9.x** at `/usr/lib/x86_64-linux-gnu/`
- **Python 3.10+** — *optional*, see note below

No sudo needed for hloc install — everything goes into `~/hloc_env/`.

### What if my Python is too old (3.8, 3.9)?

No problem. If `INSTALL.sh` detects system Python is older than 3.10, it automatically installs bundled **Miniconda Python 3.12** to `~/miniconda3/` and uses it. Your system Python stays untouched.

---

## Directory structure

```
hloc_weights_bundle/
├── README.md                         # This file
├── INSTALL.sh                        # Run on TARGET server
├── PREPARE.sh                        # Run on ONLINE PC
├── reassemble_netvlad.sh             # NetVLAD chunk reassembler (auto-run by INSTALL.sh)
├── visualize.py                      # 3D HTML viewer
├── friend_requirements.txt           # Exact version pins (reference)
├── hloc_source/                      # hloc v1.5 + submodules (171 MB)
│   ├── hloc/
│   ├── third_party/
│   │   ├── SuperGluePretrainedNetwork/
│   │   ├── d2net/
│   │   ├── deep-image-retrieval/
│   │   └── r2d2/
│   └── setup.py
├── lightglue_wheel/
│   └── lightglue-0.0-py3-none-any.whl   # Pre-built, 40 KB
├── model_cache/torch/hub/
│   ├── netvlad/
│   │   ├── VGG16-NetVLAD-Pitts30K.mat.part_01   (90 MB)
│   │   ├── ... part_02 through part_06          (~90 MB each)
│   └── checkpoints/
│       └── superpoint_lightglue_v0-1_arxiv.pth  (45 MB)
└── superglue_weights/
    ├── superpoint_v1.pth
    ├── superglue_indoor.pth
    └── superglue_outdoor.pth
```

After `PREPARE.sh` runs:
```
├── wheels/                           # ~2 GB - downloaded Python wheels
└── Miniconda3-py312-Linux-x86_64.sh  # 141 MB - Python 3.12 fallback
```
(both are in `.gitignore` — not committed to the repo)

---

## Daily usage (after install)

```bash
source ~/hloc_env/bin/activate
python3 your_script.py
```

---

## Quick demo (Sacre Coeur 3D reconstruction)

```bash
source ~/hloc_env/bin/activate
cd ~/hloc_weights_bundle/hloc_source

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

Expected on RTX 3060: **10 cameras registered, ~1850 3D points, ~8 seconds total**.

---

## Uninstall (complete cleanup)

```bash
rm -rf ~/hloc_env ~/.cache/torch/hub ~/miniconda3 ~/hloc_weights_bundle
```

Only user-space files are touched. System Python, CUDA, ROS untouched.

---

## Troubleshooting

**"ERROR: ... is not a supported wheel on this platform"**
Python version mismatch. Wheels are built for specific Python version (e.g. `cp312` = Python 3.12). The Python version on the **online PC** (where PREPARE.sh ran) must match the target server. If unsure, re-run PREPARE.sh on a machine with the same Python minor version as the target.

**"ImportError: libcudart.so.12 not found"**
CUDA 12.6 toolkit not in LD_LIBRARY_PATH. Try:
```bash
export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:$LD_LIBRARY_PATH
```

**"torch.cuda.is_available() returns False"**
NVIDIA driver issue, not hloc. Run `nvidia-smi`. If it fails, driver isn't installed.

**"ModuleNotFoundError: No module named 'SuperGluePretrainedNetwork'"**
`hloc_source/third_party/` is missing or `.pth` file wasn't created. Make sure the whole `hloc_source/` folder transferred correctly (not just some files).

---

## Design notes

- **Why include hloc source directly instead of cloning?** → So the offline server doesn't need any GitHub access. Also pins the version for reproducibility.
- **Why split NetVLAD into chunks?** → GitHub's per-file limit is 100 MB. NetVLAD weights are 528 MB, so we store it as 6 x ~90 MB chunks that INSTALL.sh reassembles automatically.
- **Why don't we commit Python wheels to the repo?** → ~2 GB of wheels would bloat the repo badly and `git clone` would be painful. PREPARE.sh downloads them once on the online PC.
- **Why is the Miniconda installer also downloaded (not bundled)?** → 141 MB > 100 MB GitHub per-file limit.

---

## File reference

| File/folder | Size | Purpose |
|---|---|---|
| `README.md` | 10 KB | This file |
| `INSTALL.sh` | 11 KB | Target server installer |
| `PREPARE.sh` | 6 KB | Online PC wheel/Miniconda downloader |
| `reassemble_netvlad.sh` | 1.5 KB | Standalone NetVLAD reassembler |
| `visualize.py` | 1 KB | 3D HTML viewer |
| `friend_requirements.txt` | 3 KB | Reference version pins |
| `hloc_source/` | 171 MB | hloc v1.5 source + all submodules |
| `lightglue_wheel/` | 40 KB | Pre-built LightGlue wheel |
| `model_cache/` | 575 MB | NetVLAD (split) + LightGlue weights |
| `superglue_weights/` | 97 MB | SuperGlue + SuperPoint weights |
