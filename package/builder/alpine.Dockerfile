FROM python:3.12.8-alpine3.20 AS builder

ARG branch

ENV NASTOOL_CONFIG=/nas-tools/config/config.yaml \
    py_site_packages=/usr/local/lib/python3.12/site-packages \
    UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple

RUN sed -i 's#https://dl-cdn.alpinelinux.org/alpine#https://mirrors.ustc.edu.cn/alpine#g' /etc/apk/repositories \
    && apk update \
    && apk add build-base git libxslt-dev libxml2-dev musl-dev gcc libffi-dev
RUN python -m pip install --upgrade pip setuptools wheel uv
RUN git clone --depth=1 -b ${branch} https://github.com/TonyLiooo/nas-tools --recurse-submodule /nas-tools
WORKDIR /nas-tools
RUN python -m pip install cython \
    && uv export --frozen --group build --no-dev --no-hashes --no-emit-project -o /tmp/requirements.txt \
    && uv pip install --system -r /tmp/requirements.txt \
    && python -m pip install feapder==1.9.2 --no-deps \
    && python -m pip install uv
RUN cp ./package/rely/hook-cn2an.py ${py_site_packages}/PyInstaller/hooks/ && \
    cp ./package/rely/hook-zhconv.py ${py_site_packages}/PyInstaller/hooks/ && \
    cp ./package/rely/hook-iso639.py ${py_site_packages}/PyInstaller/hooks/ && \
    cp ./third_party.txt ./package/ && \
    mkdir -p ${py_site_packages}/setuptools/_vendor/pyparsing/diagram/ && \
    cp ./package/rely/template.jinja2 ${py_site_packages}/setuptools/_vendor/pyparsing/diagram/ && \
    cp -r ./web/. ${py_site_packages}/web/ && \
    cp -r ./config/. ${py_site_packages}/config/ && \
    cp -r ./scripts/. ${py_site_packages}/scripts/
WORKDIR /nas-tools/package
RUN pyinstaller nas-tools.spec
RUN ls -al /nas-tools/package/dist/
WORKDIR /rootfs
RUN cp /nas-tools/package/dist/nas-tools .

FROM scratch

COPY --from=builder /rootfs/nas-tools /nas-tools
