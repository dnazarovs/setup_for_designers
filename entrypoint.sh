#!/usr/bin/env bash
set -e

COMFY_DIR="/opt/ComfyUI"
TC_DIR="$COMFY_DIR/custom_nodes/ComfyUI-ToonCrafter/ToonCrafter"

# ---- Configurable model selection via ENV ----
MODEL_REPO="${TOONCRAFTER_MODEL_REPO:-Doubiiu/ToonCrafter}"
MODEL_FILE="${TOONCRAFTER_MODEL_FILE:-model.ckpt}"
MODEL_DIR="${TOONCRAFTER_MODEL_DIR:-tooncrafter_512_interp_v1}"

CKPT_DIR="$TC_DIR/checkpoints/$MODEL_DIR"
CKPT_FILE="$CKPT_DIR/model.ckpt"

echo "[entrypoint] Starting ComfyUI"
echo "[entrypoint] ToonCrafter model: repo=$MODEL_REPO file=$MODEL_FILE dir=$MODEL_DIR"

if [ ! -f "$CKPT_FILE" ]; then
  echo "[entrypoint] Weights not found, downloading..."
  mkdir -p "$CKPT_DIR"

  python3 - <<PY
from huggingface_hub import hf_hub_download
import os, shutil

repo_id = "${MODEL_REPO}"
filename = "${MODEL_FILE}"
dst = "${CKPT_FILE}"

tmp = hf_hub_download(repo_id=repo_id, filename=filename)
os.makedirs(os.path.dirname(dst), exist_ok=True)
shutil.copyfile(tmp, dst)
print("[entrypoint] Downloaded to", dst)
PY
else
  echo "[entrypoint] Weights already present"
fi

cd "$COMFY_DIR"
exec python3 main.py --listen 0.0.0.0 --port 8188
