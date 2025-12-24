FROM ghcr.io/ai-dock/comfyui:latest

WORKDIR /opt/ComfyUI

# ✅ core deps comfyui
RUN pip install --no-cache-dir -r requirements.txt

# ✅ util for entrypoint download
RUN pip install --no-cache-dir huggingface_hub

# ---- ToonCrafter custom node ----
WORKDIR /opt/ComfyUI/custom_nodes
RUN git clone https://github.com/AIGODLIKE/ComfyUI-ToonCrafter.git \
 && cd ComfyUI-ToonCrafter \
 && pip install --no-cache-dir -r requirements.txt

# ---- Entrypoint ----
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /opt/ComfyUI
ENTRYPOINT ["/entrypoint.sh"]
