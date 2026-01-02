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

# IMPORTANT: On new GPUs (e.g. RTX 5080 / sm_120) xformers kernels can crash.
# The safest approach: uninstall xformers so ToonCrafter falls back to torch attention.
RUN python3 -m pip uninstall -y xformers || true

# ---- Entrypoint ----
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /opt/ComfyUI
ENTRYPOINT ["/entrypoint.sh"]