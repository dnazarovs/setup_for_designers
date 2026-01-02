FROM ghcr.io/ai-dock/comfyui:latest

WORKDIR /opt/ComfyUI

# Base deps you listed (kept in repo root requirements.txt)
COPY requirements.txt /tmp/requirements.txt
RUN python3 -m pip install --no-cache-dir -r /tmp/requirements.txt

# Tools for entrypoint + healthcheck
RUN python3 -m pip install --no-cache-dir huggingface_hub \
 && apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

# ---- ToonCrafter custom node ----
WORKDIR /opt/ComfyUI/custom_nodes
RUN git clone https://github.com/AIGODLIKE/ComfyUI-ToonCrafter.git \
 && cd ComfyUI-ToonCrafter \
 && python3 -m pip install --no-cache-dir -r requirements.txt

# ---- Patch ToonCrafter to avoid xformers on very new GPUs (sm_120) ----
RUN python3 - <<'PY'
from pathlib import Path
import re

files = [
  "/opt/ComfyUI/custom_nodes/ComfyUI-ToonCrafter/ToonCrafter/lvdm/modules/attention_svd.py",
  "/opt/ComfyUI/custom_nodes/ComfyUI-ToonCrafter/ToonCrafter/lvdm/modules/attention.py",
  "/opt/ComfyUI/custom_nodes/ComfyUI-ToonCrafter/ToonCrafter/lvdm/models/autoencoder_dualref.py",
]

helper = """
# --- PATCH: disable xformers on very new GPUs or when forced ---
import os
import torch
def _tooncrafter_should_disable_xformers():
    if os.getenv("TOONCRAFTER_FORCE_TORCH_ATTENTION", "0") == "1":
        return True
    if torch.cuda.is_available():
        major, minor = torch.cuda.get_device_capability()
        # xformers kernels lag behind newest SMs; disable for >= 10 (Hopper/Blackwell)
        if major >= 10:
            return True
    return False
# --------------------------------------------------------------
"""

def inject_top(text: str) -> str:
    if "_tooncrafter_should_disable_xformers" in text:
        return text
    # after initial imports block if possible
    m = re.search(r"^(from .*|import .*)(\n(from .*|import .*)\n)+", text, flags=re.M)
    if m:
        i = m.end()
        return text[:i] + "\n" + helper + "\n" + text[i:]
    return helper + "\n" + text

for f in files:
    p = Path(f)
    if not p.exists():
        continue
    t = p.read_text(encoding="utf-8", errors="ignore")
    t = inject_top(t)

    # If XFORMERS_IS_AVAILABLE exists, force-off when needed
    if "XFORMERS_IS_AVAILABLE" in t and "if _tooncrafter_should_disable_xformers():" not in t:
        t = re.sub(
            r"(XFORMERS_IS_AVAILABLE\s*=\s*.*)",
            r"\1\nif _tooncrafter_should_disable_xformers():\n    XFORMERS_IS_AVAILABLE = False\n",
            t,
            count=1,
        )

    p.write_text(t, encoding="utf-8")

print("ToonCrafter patched: xformers disabled on new GPUs / env force.")
PY

# ---- Entrypoint ----
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /opt/ComfyUI
ENTRYPOINT ["/entrypoint.sh"]
