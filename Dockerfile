# syntax=docker/dockerfile:1.7
FROM python:3.12.8-alpine3.20

ARG PYPI_MIRROR=https://pypi.tuna.tsinghua.edu.cn/simple
ARG ALPINE_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/alpine
ARG VCS_REF=unknown

LABEL org.opencontainers.image.source="https://github.com/iMMIQ/nas-tools" \
      org.opencontainers.image.revision="${VCS_REF}"

ENV PIP_INDEX_URL=${PYPI_MIRROR} \
    UV_DEFAULT_INDEX=${PYPI_MIRROR} \
    PIP_DEFAULT_TIMEOUT=120 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy

COPY pyproject.toml uv.lock package_list.txt ./

RUN --mount=type=cache,target=/root/.cache/pip \
    --mount=type=cache,target=/root/.cache/uv \
    mkdir -p /root/.config/pip \
    && python -m pip config set global.index-url "${PIP_INDEX_URL}" \
    && sed -i "s#https://dl-cdn.alpinelinux.org/alpine#${ALPINE_MIRROR}#g" /etc/apk/repositories \
    && if ! apk add --no-cache --virtual .build-deps \
        libffi-dev \
        gcc \
        musl-dev \
        libxml2-dev \
        libxslt-dev; then \
        sed -i 's#https://mirrors.tuna.tsinghua.edu.cn/alpine#https://dl-cdn.alpinelinux.org/alpine#g' /etc/apk/repositories \
        && apk add --no-cache --virtual .build-deps \
            libffi-dev \
            gcc \
            musl-dev \
            libxml2-dev \
            libxslt-dev; \
    fi \
    && apk add --no-cache $(tr '\n' ' ' < package_list.txt) \
    && curl -fsSL https://rclone.org/install.sh | bash \
    && ARCH=$(case "$(uname -m)" in x86_64) echo amd64 ;; aarch64) echo arm64 ;; *) uname -m ;; esac) \
    && curl -fsSL "https://dl.min.io/client/mc/release/linux-${ARCH}/mc" -o /usr/bin/mc \
    && chmod +x /usr/bin/mc \
    && python -m pip install --upgrade pip setuptools wheel uv cython \
    && uv export --frozen --no-dev --no-hashes --no-emit-project -o /tmp/requirements.txt \
    && uv pip install --system -r /tmp/requirements.txt \
    && python -m pip install --no-deps feapder==1.9.2 \
    && python -m pip uninstall -y uv cython \
    && apk del --purge .build-deps \
    && rm -rf /tmp/* /var/cache/apk/*

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

RUN mkdir -p ${HOME} \
    && addgroup -S nt -g 911 \
    && adduser -S nt -G nt -h ${HOME} -s /bin/bash -u 911 \
    && python_ver=$(python3 -V | awk '{print $2}') \
    && mkdir -p "/usr/local/lib/python${python_ver%.*}/site-packages" \
    && echo "${WORKDIR}/" > "/usr/local/lib/python${python_ver%.*}/site-packages/nas-tools.pth" \
    && echo 'fs.inotify.max_user_watches=5242880' >> /etc/sysctl.conf \
    && echo 'fs.inotify.max_user_instances=5242880' >> /etc/sysctl.conf

COPY . ${WORKDIR}/
COPY ./docker/rootfs /

RUN chmod 755 /etc/s6-overlay/s6-rc.d/*/run /etc/s6-overlay/s6-rc.d/*/finish /etc/s6-overlay/s6-rc.d/*/up 2>/dev/null || true

EXPOSE 3000
VOLUME ["/config", "/cache"]
ENTRYPOINT ["/init"]
