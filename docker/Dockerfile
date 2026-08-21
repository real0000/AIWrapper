# CAGE Server — container image.
#
# Build it yourself; nothing is published to a registry. The server package and
# the backend pack for your GPUs both go in the build context next to this file:
#
#   cp cage-server-0.1.1-linux-x64.tar.gz  release/docker/
#   cp cage-backend-cuda-sm89_sm90-*.tar.gz release/docker/   # one or more
#   cp cage-backend-vulkan-*.tar.gz         release/docker/
#   docker build -t cage:0.1.1 release/docker
#
# The server package carries no GPU code. Without a backend pack the image still
# runs, but only the vllm and remote backends work — in-process GGUF inference
# is unavailable. Copy in as many packs as you want covered; every
# cage-backend-*.tar.gz in the context is unpacked.
#
# Base image notes, both load-bearing:
#   * ubuntu24.04 — the server binary needs GLIBC_2.38. Ubuntu 22.04 ships 2.35
#     and the binary will not start on it.
#   * -devel, not -runtime — `nvcc` is needed if you build the Python worker
#     environments inside the container, which is the normal way to use this.
#     Swap to -runtime for a smaller image if you build the venvs elsewhere and
#     mount them.
#
# CUDA 12.x containers run on any driver from the 12.x series (>= 525.60.13)
# thanks to minor-version compatibility, so this does not have to match the
# host's CUDA toolkit exactly.
# BASE_IMAGE 讓同一份 Dockerfile 服務兩種硬體：
#   NVIDIA → nvidia/cuda:*-devel（預設；需要 nvcc 才能在容器內建 Python worker）
#   AMD    → ubuntu:24.04（HIP 後端包自帶 ROCm 的執行期函式庫，不需要 CUDA base）
# 見 docker-compose.yml 與 docker-compose.amd.yml。
ARG BASE_IMAGE=nvidia/cuda:12.6.3-devel-ubuntu24.04
FROM ${BASE_IMAGE}

ARG PACKAGE=cage-server-0.1.1-linux-x64.tar.gz
ARG DEBIAN_FRONTEND=noninteractive

# Runtime libraries the server links against, plus what setup-workers.sh needs:
#   libgomp1 libquadmath0   — linked by the server binary
#   python3-venv            — Ubuntu splits venv out; without it the worker
#                             setup cannot create an environment at all
#   pkg-config libav*-dev   — audiocraft pins av==11.0.0, which has no wheel and
#                             must compile against the FFmpeg headers
#   ffmpeg                  — needed at runtime by the tts family
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git tini \
        libgomp1 libquadmath0 \
        python3 python3-venv python3-dev \
        pkg-config ffmpeg \
        libavformat-dev libavcodec-dev libavdevice-dev \
        libavutil-dev libavfilter-dev libswscale-dev libswresample-dev \
        default-mysql-client \
        libnuma1 libelf1 libdrm2 libdrm-amdgpu1 \
    && rm -rf /var/lib/apt/lists/*

# ── The package ─────────────────────────────────────────────────────────────
# To pull from a GitHub Release instead of the build context, replace the COPY
# with:
#   ADD https://github.com/real0000/AIWrapper/releases/download/v0.1.1/${PACKAGE} /tmp/
#
# The backend glob is in the same COPY as the server package on purpose: a glob
# that matches nothing is tolerated as long as another source matched, so the
# build still works when no pack was copied in. On its own it would be an error.
WORKDIR /tmp
COPY ${PACKAGE} cage-backend-*.tar.gz* /tmp/pkgs/
RUN mkdir -p /opt/cage \
    && tar -xzf "/tmp/pkgs/${PACKAGE}" --strip-components=1 -C /opt/cage \
    && rm -f "/tmp/pkgs/${PACKAGE}" \
    && for b in /tmp/pkgs/cage-backend-*.tar.gz; do \
           [ -e "$b" ] || continue; \
           echo "backend pack: $(basename "$b")"; \
           tar -xzf "$b" --strip-components=1 -C /opt/cage; \
       done \
    && rm -rf /tmp/pkgs \
    && ls /opt/cage/bin/libcage-llama-*.so >/dev/null 2>&1 \
       || echo "WARNING: no backend pack — backend=\"llama\" models will not load" \
    && chmod 755 /opt/cage/bin/* /opt/cage/*.sh

WORKDIR /opt/cage

# Templates are seeded into /config on first start if it is empty.
COPY config.xml.template control.xml.template /opt/cage/templates/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# ── Mount points ────────────────────────────────────────────────────────────
#   /config              config.xml + control.xml     (holds credentials)
#   /models              model files, mount read-only (huge; never in the image)
#   /opt/cage/data  logic graphs and retrieval vectors — the server resolves
#                        these relative to its working directory, so this exact
#                        path is what has to be persisted
#   /venvs               Python worker environments  (~46 GB for every family,
#                        and rebuilding them recompiles CUDA)
VOLUME ["/config", "/opt/cage/data", "/venvs"]

#   15963  AI API — HTTP + WebSocket, what the editor connects to
#   15972  node agent API
#   8088   control-plane web UI
EXPOSE 15963 15972 8088

ENV CONFIG_FILE=/config/config.xml \
    CAGE_CONTROL_CONFIG=/config/control.xml

# tini reaps the worker subprocesses the server spawns; without an init the
# container accumulates zombies as models load and unload.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["--all"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
    CMD curl -fsS http://127.0.0.1:15963/health || exit 1
