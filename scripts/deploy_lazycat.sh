#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

log() {
  printf '[INFO] %s\n' "$*"
}

err() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

run() {
  printf '+ '
  printf '%q ' "$@"
  printf '\n'
  "$@"
}

DRY_RUN=0
BOX_NAME="${BOX_NAME:-}"
PLATFORM="${PLATFORM:-linux/amd64}"
IMAGE_TAG="${IMAGE_TAG:-}"
REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-lzc}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --box)
      BOX_NAME="$2"
      shift 2
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --image-tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: ./scripts/deploy_lazycat.sh [--box <box-name>] [--platform <platform>] [--image-tag <tag>] [--dry-run]

Examples:
  ./scripts/deploy_lazycat.sh
  ./scripts/deploy_lazycat.sh --box immiqtop
  ./scripts/deploy_lazycat.sh --box immiqtop --image-tag 3.5.9-test1
USAGE
      exit 0
      ;;
    *)
      err "unknown argument: $1"
      ;;
  esac
done

if command -v lzc-cli >/dev/null 2>&1; then
  LZC_CLI=(lzc-cli)
elif [[ -f "$HOME/.local/node_modules/@lazycatcloud/lzc-cli/scripts/cli.js" ]]; then
  LZC_CLI=(node "$HOME/.local/node_modules/@lazycatcloud/lzc-cli/scripts/cli.js")
else
  err 'lzc-cli not found; please install it first'
fi

lzc() {
  "${LZC_CLI[@]}" "$@"
}

VERSION="$(sed -nE "s/^APP_VERSION = 'v?([^']+)'$/\1/p" version.py)"
[[ -n "$VERSION" ]] || err 'failed to parse version from version.py'

PKG_ID="$(sed -nE 's/^package:[[:space:]]*(.+)$/\1/p' package.yml | head -n1)"
[[ -n "$PKG_ID" ]] || err 'failed to parse package id from package.yml'

SUBDOMAIN="$(sed -nE 's/^[[:space:]]*subdomain:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p' lzc-manifest.yml | head -n1)"
[[ -n "$SUBDOMAIN" ]] || err 'failed to parse subdomain from lzc-manifest.yml'

if [[ -z "$BOX_NAME" ]]; then
  BOX_NAME="$(lzc box default | tail -n1 | tr -d '\r')"
fi
[[ -n "$BOX_NAME" ]] || err 'failed to resolve target box name'

GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
if [[ -z "$IMAGE_TAG" ]]; then
  IMAGE_TAG="${VERSION}-${GIT_SHA}-$(date +%Y%m%d%H%M%S)"
fi

IMAGE_REF="dev.${BOX_NAME}.heiyu.space/${REGISTRY_NAMESPACE}/nas-tools:${IMAGE_TAG}"
APP_URL="https://${SUBDOMAIN}.${BOX_NAME}.heiyu.space"
LPK_PATH="$ROOT_DIR/${PKG_ID}-v${VERSION}.lpk"
mkdir -p "$ROOT_DIR/.tmp"
TMP_DIR="$(mktemp -d "$ROOT_DIR/.tmp/nas-tools-deploy.XXXXXX")"
TMP_MANIFEST="$TMP_DIR/lzc-manifest.yml"
TMP_BUILD="$TMP_DIR/lzc-build.yml"
REL_TMP_MANIFEST="./${TMP_MANIFEST#"$ROOT_DIR/"}"
REL_TMP_BUILD="./${TMP_BUILD#"$ROOT_DIR/"}"
trap 'rm -rf "$TMP_DIR"' EXIT

python3 - "$ROOT_DIR/lzc-manifest.yml" "$TMP_MANIFEST" "$IMAGE_REF" <<'PY'
from pathlib import Path
import re
import sys
src, dst, image = sys.argv[1:4]
text = Path(src).read_text()
text, count = re.subn(r'(^\s+image:\s+).+$', rf'\1{image}', text, count=1, flags=re.M)
if count != 1:
    raise SystemExit('failed to replace image in lzc-manifest.yml')
Path(dst).write_text(text)
PY

python3 - "$ROOT_DIR/lzc-build.yml" "$TMP_BUILD" "$REL_TMP_MANIFEST" <<'PY'
from pathlib import Path
import re
import sys
src, dst, manifest = sys.argv[1:4]
text = Path(src).read_text()
if re.search(r'^manifest:', text, flags=re.M):
    text = re.sub(r'^manifest:.*$', f'manifest: {manifest}', text, count=1, flags=re.M)
else:
    text = f'manifest: {manifest}\n' + text
Path(dst).write_text(text)
PY

log "box       : $BOX_NAME"
log "version   : $VERSION"
log "image_ref : $IMAGE_REF"
log "app_url   : $APP_URL"
log "lpk       : $LPK_PATH"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log 'dry-run mode enabled; no changes applied'
  exit 0
fi

run docker buildx build \
  --network host \
  --platform "$PLATFORM" \
  -t "$IMAGE_REF" \
  --provenance=false \
  --push \
  .

run lzc docker pull "$IMAGE_REF"
run lzc project build -f "$REL_TMP_BUILD"
run lzc app install "$LPK_PATH"

HTTP_OK=0
for _ in $(seq 1 30); do
  if curl -k -I --max-time 10 "$APP_URL" >/tmp/nas-tools-deploy.headers.$$ 2>/dev/null; then
    if grep -Eq 'HTTP/[12](\.[01])? (200|307|401|403)' /tmp/nas-tools-deploy.headers.$$; then
      HTTP_OK=1
      break
    fi
  fi
  sleep 2
done
rm -f /tmp/nas-tools-deploy.headers.$$

if [[ "$HTTP_OK" -eq 1 ]]; then
  log "deploy finished: $APP_URL"
else
  err "deploy finished but HTTP health check did not pass: $APP_URL"
fi
