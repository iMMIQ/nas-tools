# syntax=docker/dockerfile:1.7
#
# Unified Dockerfile for nas-tools
# Build args:
#   BASE        - "alpine" (default) or "debian"
#   BUILD_MODE  - "copy" (default, immutable) or "clone" (mutable, git pull at runtime)
#   VCS_REF     - Git revision to embed in image metadata
#   PYPI_MIRROR - PyPI mirror URL
#   SYS_MIRROR  - System package mirror URL (Alpine apk / Debian apt)
#

# ---------- global build arguments (must precede first FROM) ----------
ARG BASE=alpine
ARG BUILD_MODE=copy

FROM python:3.12.8-alpine3.20 AS base-alpine

FROM python:3.12.8-slim-bookworm AS base-debian
COPY --from=shinsenter/s6-overlay / /

FROM base-${BASE} AS base

# ---------- build arguments ----------
ARG PYPI_MIRROR=https://pypi.tuna.tsinghua.edu.cn/simple
ARG SYS_MIRROR=""
ARG VCS_REF=unknown

# ---------- Alpine: system packages ----------
FROM base AS packages-alpine
COPY package_list.txt ./
RUN sed -i "s#https://dl-cdn.alpinelinux.org/alpine#${SYS_MIRROR:-https://mirrors.tuna.tsinghua.edu.cn/alpine}#g" /etc/apk/repositories \
    && grep -q '/community' /etc/apk/repositories \
       || echo "${SYS_MIRROR:-https://mirrors.tuna.tsinghua.edu.cn}/alpine/v3.20/community" >> /etc/apk/repositories \
    && apk add --no-cache --virtual .build-deps \
        libffi-dev gcc musl-dev libxml2-dev libxslt-dev \
    && apk add --no-cache $(tr '\n' ' ' < package_list.txt) rclone \
    && ARCH=$(case "$(uname -m)" in x86_64) echo amd64 ;; aarch64) echo arm64 ;; *) uname -m ;; esac) \
    && curl -fsSL "https://dl.min.io/client/mc/release/linux-${ARCH}/mc" -o /usr/bin/mc \
    && chmod +x /usr/bin/mc \
    && rm -f package_list.txt

# ---------- Debian: system packages ----------
FROM base AS packages-debian
COPY package_list_debian.txt ./
ENV DEBIAN_FRONTEND=noninteractive
RUN set -e \
    && if [ -n "${SYS_MIRROR}" ]; then \
        echo "deb ${SYS_MIRROR}/debian/ bookworm main" > /etc/apt/sources.list \
        && echo "deb ${SYS_MIRROR}/debian/ bookworm-updates main" >> /etc/apt/sources.list \
        && echo "deb ${SYS_MIRROR}/debian-security/ bookworm-security main" >> /etc/apt/sources.list; \
    fi \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends $(tr '\n' ' ' < package_list_debian.txt) curl \
    && ARCH=$(case "$(uname -m)" in x86_64) echo amd64 ;; aarch64) echo arm64 ;; *) uname -m ;; esac) \
    && curl -fsSL "https://dl.min.io/client/mc/release/linux-${ARCH}/mc" -o /usr/bin/mc \
    && chmod +x /usr/bin/mc \
    && curl https://rclone.org/install.sh | bash \
    && rm -f package_list_debian.txt \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# ---------- Python dependencies ----------
FROM packages-${BASE} AS deps

ENV PIP_INDEX_URL=${PYPI_MIRROR} \
    UV_DEFAULT_INDEX=${PYPI_MIRROR} \
    PIP_DEFAULT_TIMEOUT=120 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy

COPY pyproject.toml uv.lock ./

RUN --mount=type=cache,target=/root/.cache/uv \
    pip install --upgrade pip setuptools wheel uv \
    && pip install cython \
    && uv export --frozen --no-dev --no-hashes --no-emit-project -o /tmp/requirements.txt \
    && uv pip install --system -r /tmp/requirements.txt \
    && pip install --no-deps feapder==1.9.2 \
    && pip uninstall -y uv cython \
    && rm -rf /tmp/* /root/.cache/pip

# ---------- common runtime environment ----------
FROM deps AS runtime

LABEL org.opencontainers.image.source="https://github.com/iMMIQ/nas-tools" \
      org.opencontainers.image.revision="${VCS_REF}"

ENV PYTHONPATH=/usr/local/lib/python3.12/site-packages \
    S6_SERVICES_GRACETIME=30000 \
    S6_KILL_GRACETIME=60000 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_SYNC_DISKS=1 \
    HOME="/nt" \
    TERM="xterm" \
    PATH=${PATH}:/usr/lib/chromium \
    LANG="C.UTF-8" \
    TZ="Asia/Shanghai" \
    NASTOOL_CONFIG="/config/config.yaml" \
    NASTOOL_CACHE_DIR="/cache" \
    NASTOOL_LOG="/cache/logs" \
    NASTOOL_TMDB_CACHE="/cache/tmdb.dat" \
    NASTOOL_WEBDRIVER_PATH="/cache/webdriver" \
    NASTOOL_AUTO_UPDATE=false \
    NASTOOL_CN_UPDATE=true \
    NASTOOL_IMMUTABLE_IMAGE=true \
    NASTOOL_VERSION=master \
    NASTOOL_BUILD_REF=${VCS_REF} \
    PS1="\u@\h:\w \$ " \
    PYPI_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple" \
    ALPINE_MIRROR="mirrors.tuna.tsinghua.edu.cn/alpine" \
    PUID=0 \
    PGID=0 \
    UMASK=000 \
    PYTHONWARNINGS="ignore:semaphore_tracker:UserWarning" \
    WORKDIR="/nas-tools"

WORKDIR ${WORKDIR}

# ---------- user & system setup ----------
RUN set -e \
    && mkdir -p ${HOME} \
    && addgroup -S nt -g 911 2>/dev/null || groupadd -r nt -g 911 \
    && adduser -S nt -G nt -h ${HOME} -s /bin/bash -u 911 2>/dev/null \
       || useradd -r nt -g nt -d ${HOME} -s /bin/bash -u 911 \
    && python_ver=$(python3 -V | awk '{print $2}') \
    && mkdir -p "/usr/local/lib/python${python_ver%.*}/site-packages" \
    && echo "${WORKDIR}/" > "/usr/local/lib/python${python_ver%.*}/site-packages/nas-tools.pth" \
    && echo 'fs.inotify.max_user_watches=5242880' >> /etc/sysctl.conf \
    && echo 'fs.inotify.max_user_instances=5242880' >> /etc/sysctl.conf

# ---------- source code (BUILD_MODE=copy, immutable) ----------
FROM runtime AS mode-copy
COPY . ${WORKDIR}/
COPY ./docker/rootfs /

# ---------- source code (BUILD_MODE=clone, mutable) ----------
FROM runtime AS mode-clone
ENV REPO_URL="https://github.com/iMMIQ/nas-tools.git" \
    NASTOOL_IMMUTABLE_IMAGE=false
RUN set -e \
    && if command -v apk >/dev/null 2>&1; then \
        apk add --no-cache git sudo; \
    else \
        apt-get update -y && apt-get install -y --no-install-recommends git sudo \
        && apt-get clean -y && rm -rf /var/lib/apt/lists/*; \
    fi \
    && echo "nt ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && git config --global pull.ff only \
    && git clone -b master ${REPO_URL} ${WORKDIR} --depth=1 --recurse-submodules \
    && git config --global --add safe.directory ${WORKDIR}
COPY ./docker/rootfs /

# ---------- final image ----------
FROM mode-${BUILD_MODE} AS final
RUN chmod 755 /etc/s6-overlay/s6-rc.d/*/run /etc/s6-overlay/s6-rc.d/*/finish /etc/s6-overlay/s6-rc.d/*/up 2>/dev/null || true

EXPOSE 3000
VOLUME ["/config", "/cache"]
ENTRYPOINT ["/init"]
