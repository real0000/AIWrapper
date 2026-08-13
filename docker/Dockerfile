# CAGE Server — container image.
#
# Build it yourself; nothing is published to a registry. The server package goes
# in the build context next to this file:
#
#   cp cage-server-0.1.1-linux-x64.tar.gz release/docker/
#   docker build -t cage:0.1.1 release/docker
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
FROM nvidia/cuda:12.6.3-devel-ubuntu24.04

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
    && rm -rf /var/lib/apt/lists/*

# ── The package ─────────────────────────────────────────────────────────────
# To pull from a GitHub Release instead of the build context, replace the COPY
# with:
#   ADD https://github.com/real0000/AIWrapper/releases/download/v0.1.1/${PACKAGE} /tmp/
WORKDIR /tmp
COPY ${PACKAGE} /tmp/pkg.tar.gz
RUN mkdir -p /opt/cage \
    && tar -xzf /tmp/pkg.tar.gz --strip-components=1 -C /opt/cage \
    && rm -f /tmp/pkg.tar.gz \
    && chmod 755 /opt/cage/bin/* /opt/cage/*.sh

WORKDIR /opt/cage

# Templates are seeded into /config on first start if it is empty.
COPY config.xml.template control.xml.template /opt/cage/templates/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

# ── Mount points ────────────────────────────────────────────────────────────
#   /config              config.xml + control.xml     (holds credentials)
#   /models              model files, mount read-only (huge; never in the image)
#   /opt/cage/data  logic graphs, workflows, vectors — the server resolves
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
