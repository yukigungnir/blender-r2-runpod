FROM nvidia/cuda:12.8.1-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG BLENDER_VERSION=5.2.2
ARG BLENDER_SHA256=84098912789dc450e95697c4184fb8a90acbe5111c2ba4aede3fecb57806a168
ARG RCLONE_VERSION=1.70.3

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip xz-utils \
        libx11-6 libxi6 libxrender1 libxfixes3 libxxf86vm1 \
        libxkbcommon0 libsm6 libice6 libgl1 libegl1 libopengl0 \
        libglvnd0 libglx0 libvulkan1 \
        libglib2.0-0 libfontconfig1 libfreetype6 libdbus-1-3 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://download.blender.org/release/Blender5.2/blender-${BLENDER_VERSION}-linux-x64.tar.xz" -o /tmp/blender.tar.xz \
    && echo "${BLENDER_SHA256}  /tmp/blender.tar.xz" | sha256sum -c - \
    && mkdir -p /opt/blender \
    && tar -xJf /tmp/blender.tar.xz --strip-components=1 -C /opt/blender \
    && rm /tmp/blender.tar.xz

RUN curl -fsSL "https://downloads.rclone.org/v${RCLONE_VERSION}/rclone-v${RCLONE_VERSION}-linux-amd64.zip" -o "/tmp/rclone-v${RCLONE_VERSION}-linux-amd64.zip" \
    && curl -fsSL "https://downloads.rclone.org/v${RCLONE_VERSION}/SHA256SUMS" -o /tmp/rclone-sha256sums \
    && grep " rclone-v${RCLONE_VERSION}-linux-amd64.zip$" /tmp/rclone-sha256sums \
        | sed 's#  rclone-#  /tmp/rclone-#' \
        | sha256sum -c - \
    && unzip -q "/tmp/rclone-v${RCLONE_VERSION}-linux-amd64.zip" -d /tmp \
    && install -m 0755 "/tmp/rclone-v${RCLONE_VERSION}-linux-amd64/rclone" /usr/local/bin/rclone \
    && rm -rf "/tmp/rclone-v${RCLONE_VERSION}-linux-amd64.zip" /tmp/rclone-sha256sums "/tmp/rclone-v${RCLONE_VERSION}-linux-amd64"

ENV PATH="/opt/blender:${PATH}" \
    NVIDIA_VISIBLE_DEVICES="all" \
    NVIDIA_DRIVER_CAPABILITIES="all" \
    RENDER_DIR="/workspace/render/frames" \
    LOG_DIR="/workspace/logs" \
    R2_PREFIX="castorice_vertical/frames" \
    R2_INTERVAL_SECONDS="120" \
    R2_MIN_AGE="2m" \
    R2_TRANSFERS="4" \
    R2_CHECKERS="8"

COPY scripts/ /opt/render-tools/
RUN chmod 0755 /opt/render-tools/*.sh \
    && mkdir -p /workspace/project /workspace/render/frames /workspace/logs

WORKDIR /workspace
CMD ["/bin/bash"]
