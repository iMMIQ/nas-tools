FROM python:3.12.8-alpine3.20

ARG PYPI_MIRROR=https://pypi.tuna.tsinghua.edu.cn/simple
ENV PIP_INDEX_URL=${PYPI_MIRROR} \
    UV_DEFAULT_INDEX=${PYPI_MIRROR}

RUN sed -i 's#https://dl-cdn.alpinelinux.org/alpine#https://mirrors.ustc.edu.cn/alpine#g' /etc/apk/repositories \
    && apk update \
    && apk add --no-cache --virtual .build-deps \
        libffi-dev \
        gcc \
        musl-dev \
        libxml2-dev \
        libxslt-dev \
    && apk add --no-cache $(wget --no-check-certificate -qO- https://raw.githubusercontent.com/iMMIQ/nas-tools/master/package_list.txt) \
    && curl -sSf https://rclone.org/install.sh | bash \
    && ARCH=$(if [ "$(uname -m)" = "x86_64" ]; then echo "amd64"; else echo "arm64"; fi) \
    && curl -sSfL https://dl.min.io/client/mc/release/linux-${ARCH}/mc --create-dirs -o /usr/bin/mc \
    && chmod +x /usr/bin/mc \
    && python -m pip install --upgrade pip setuptools wheel uv \
    && python -m pip install cython \
    && curl -sSfL https://raw.githubusercontent.com/iMMIQ/nas-tools/master/pyproject.toml -o /tmp/pyproject.toml \
    && curl -sSfL https://raw.githubusercontent.com/iMMIQ/nas-tools/master/uv.lock -o /tmp/uv.lock \
    && cd /tmp \
    && uv export --frozen --no-dev --no-hashes --no-emit-project -o /tmp/requirements.txt \
    && uv pip install --system -r /tmp/requirements.txt \
    && python -m pip install feapder==1.9.2 --no-deps \
    && python -m pip install uv \
    && apk del --purge .build-deps \
    && rm -rf /var/cache/apk/* /tmp/* /root/.cache/*

ENV PYTHONPATH=/usr/lib/python3.12/site-packages \
    S6_SERVICES_GRACETIME=30000 \
    S6_KILL_GRACETIME=60000 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_SYNC_DISKS=1 \
    HOME="/nt" \
    TERM="xterm" \
    PATH="${PATH}:/usr/lib/chromium" \
    LANG="C.UTF-8" \
    TZ="Asia/Shanghai" \
    NASTOOL_CONFIG="/config/config.yaml" \
    NASTOOL_AUTO_UPDATE=false \
    NASTOOL_CN_UPDATE=true \
    NASTOOL_VERSION=master \
    PS1="\u@\h:\w \$ " \
    REPO_URL="https://github.com/iMMIQ/nas-tools.git" \
    PYPI_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple" \
    ALPINE_MIRROR="mirrors.ustc.edu.cn" \
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
    && mkdir -p /usr/lib/python${python_ver%.*}/site-packages \
    && echo "${WORKDIR}/" > /usr/lib/python${python_ver%.*}/site-packages/nas-tools.pth \
    && echo 'fs.inotify.max_user_watches=5242880' >> /etc/sysctl.conf \
    && echo 'fs.inotify.max_user_instances=5242880' >> /etc/sysctl.conf \
    && echo "nt ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers \
    && git config --global pull.ff only \
    && git clone -b master ${REPO_URL} ${WORKDIR} --depth=1 --recurse-submodule \
    && git config --global --add safe.directory ${WORKDIR}

COPY ./rootfs /
RUN chmod 755 /etc/s6-overlay/s6-rc.d/*/run /etc/s6-overlay/s6-rc.d/*/finish /etc/s6-overlay/s6-rc.d/*/up 2>/dev/null || true
EXPOSE 3000
VOLUME ["/config"]
ENTRYPOINT ["/init"]
