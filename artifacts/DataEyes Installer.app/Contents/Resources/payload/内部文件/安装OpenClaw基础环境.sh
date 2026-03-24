#!/usr/bin/env bash
#
# OpenClaw 安装脚本（无管理员权限版）
# 特点：
# - 仅写入用户目录，不触碰 /usr/local
# - 不修改 shell 配置文件
# - 不修改全局 npm registry
# - 不依赖 Homebrew / Git
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${BLUE}i ${NC}$*"; }
success() { echo -e "${GREEN}OK ${NC}$*"; }
warn()    { echo -e "${YELLOW}! ${NC}$*"; }
error()   { echo -e "${RED}X ${NC}$*"; }
step()    { echo -e "\n${CYAN}=== $* ===${NC}\n"; }

REQUIRED_NODE_MAJOR=22
OPENCLAW_PKG="${OPENCLAW_PKG:-openclaw@latest}"
APP_HOME="${OPENCLAW_HOME:-$HOME/.dataeyes-openclaw}"
NODE_HOME="$APP_HOME/node"
NPM_HOME="$APP_HOME/npm"
BIN_HOME="$NPM_HOME/bin"
NODE_BIN_DIR=""
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
  arm64|aarch64) ARCH="arm64" ;;
  x86_64|amd64)  ARCH="x64" ;;
  *)             ARCH="x64" ;;
esac

ensure_dirs() {
  mkdir -p "$APP_HOME" "$NODE_HOME" "$NPM_HOME" "$BIN_HOME"
}

ensure_path() {
  local dirs=(
    "$NODE_HOME/bin"
    "$BIN_HOME"
    "$HOME/.npm-global/bin"
    "/opt/homebrew/bin"
    "/usr/local/bin"
    "$PATH"
  )
  local combined=""
  local dir
  for dir in "${dirs[@]}"; do
    if [[ -n "$dir" ]]; then
      combined="${combined:+$combined:}$dir"
    fi
  done
  export PATH="$combined"
}

check_node_version() {
  local cmd="${1:-node}"
  local ver
  ver=$("$cmd" -v 2>/dev/null || true)
  if [[ "$ver" =~ v([0-9]+) ]] && (( BASH_REMATCH[1] >= REQUIRED_NODE_MAJOR )); then
    echo "$ver"
    return 0
  fi
  return 1
}

pin_node_path() {
  local dir
  IFS=':' read -ra dirs <<< "$PATH"
  for dir in "${dirs[@]}"; do
    if [[ -x "$dir/node" ]]; then
      local ver
      ver=$("$dir/node" -v 2>/dev/null || true)
      if [[ "$ver" =~ v([0-9]+) ]] && (( BASH_REMATCH[1] >= REQUIRED_NODE_MAJOR )); then
        NODE_BIN_DIR="$dir"
        export PATH="$dir:$BIN_HOME:$PATH"
        info "使用 Node.js: $dir/node ($ver)"
        return 0
      fi
    fi
  done
  return 1
}

download_file() {
  local dest="$1"
  shift
  local url
  for url in "$@"; do
    local host
    host=$(echo "$url" | sed 's|https\?://\([^/]*\).*|\1|')
    info "下载中: $host"
    if curl -fsSL --connect-timeout 30 --retry 3 --retry-delay 2 --max-time 300 -o "$dest" "$url"; then
      return 0
    fi
  done
  return 1
}

get_latest_node_version() {
  local major="$1"
  local url
  for url in \
    "https://nodejs.org/dist/latest-v${major}.x/SHASUMS256.txt" \
    "https://npmmirror.com/mirrors/node/latest-v${major}.x/SHASUMS256.txt"
  do
    local content
    content=$(curl -fsSL --connect-timeout 10 "$url" 2>/dev/null || true)
    local ver
    ver=$(echo "$content" | grep -oE 'node-(v[0-9]+\.[0-9]+\.[0-9]+)' | head -1 | sed 's/node-//')
    if [[ -n "$ver" ]]; then
      echo "$ver"
      return 0
    fi
  done
  return 1
}

install_node_to_user_dir() {
  step "步骤 1/4: 准备 Node.js"

  ensure_dirs
  ensure_path

  local ver=""
  if ver=$(check_node_version); then
    pin_node_path
    success "检测到现有 Node.js $ver"
    return 0
  fi

  local version
  version=$(get_latest_node_version 22) || {
    error "无法获取 Node.js 22 最新版本"
    return 1
  }

  local os_name filename tmp_dir tmp_file
  [[ "$OS" == "darwin" ]] && os_name="darwin" || os_name="linux"
  filename="node-${version}-${os_name}-${ARCH}.tar.gz"
  tmp_dir=$(mktemp -d)
  tmp_file="$tmp_dir/$filename"

  info "未检测到可用 Node.js，安装到用户目录: $NODE_HOME"
  if ! download_file "$tmp_file" \
    "https://nodejs.org/dist/${version}/${filename}" \
    "https://npmmirror.com/mirrors/node/${version}/${filename}"; then
    rm -rf "$tmp_dir"
    error "Node.js 下载失败，请检查网络连接"
    return 1
  fi

  rm -rf "$NODE_HOME"
  mkdir -p "$NODE_HOME"
  tar -xzf "$tmp_file" -C "$NODE_HOME" --strip-components=1
  rm -rf "$tmp_dir"

  ensure_path
  if ver=$(check_node_version "$NODE_HOME/bin/node"); then
    NODE_BIN_DIR="$NODE_HOME/bin"
    export PATH="$NODE_BIN_DIR:$BIN_HOME:$PATH"
    success "Node.js 已安装到 $NODE_HOME ($ver)"
    return 0
  fi

  error "Node.js 安装完成但验证失败"
  return 1
}

npm_install_openclaw() {
  step "步骤 2/4: 安装 OpenClaw"

  ensure_dirs
  ensure_path
  pin_node_path || true

  local npm_cmd="${NODE_BIN_DIR:-$NODE_HOME/bin}/npm"
  if [[ ! -x "$npm_cmd" ]]; then
    error "未找到 npm，可用 Node.js 环境不完整"
    return 1
  fi

  local tmp_cache
  tmp_cache=$(mktemp -d)

  info "安装位置: $NPM_HOME"
  info "软件包: $OPENCLAW_PKG"

  if NPM_CONFIG_PREFIX="$NPM_HOME" \
     NPM_CONFIG_CACHE="$tmp_cache" \
     NPM_CONFIG_FUND=false \
     NPM_CONFIG_AUDIT=false \
     NPM_CONFIG_UPDATE_NOTIFIER=false \
     "$npm_cmd" install -g "$OPENCLAW_PKG" --loglevel=notice; then
    rm -rf "$tmp_cache"
    export PATH="$BIN_HOME:$PATH"
    success "OpenClaw 安装完成"
    return 0
  fi

  rm -rf "$tmp_cache"
  error "OpenClaw 安装失败"
  return 1
}

verify_openclaw() {
  step "步骤 3/4: 验证安装"

  ensure_path
  local openclaw_cmd="$BIN_HOME/openclaw"
  if [[ ! -x "$openclaw_cmd" ]]; then
    openclaw_cmd="$(command -v openclaw || true)"
  fi

  if [[ -z "$openclaw_cmd" || ! -x "$openclaw_cmd" ]]; then
    error "安装后未找到 openclaw 命令"
    return 1
  fi

  local ver
  ver=$("$openclaw_cmd" -v 2>/dev/null || "$openclaw_cmd" --version 2>/dev/null || true)
  if [[ -n "$ver" ]]; then
    success "OpenClaw 已就绪: $ver"
    echo "$openclaw_cmd" > "$APP_HOME/openclaw-bin-path"
    return 0
  fi

  warn "openclaw 已安装，但未能读取版本号"
  echo "$openclaw_cmd" > "$APP_HOME/openclaw-bin-path"
  return 0
}

step_onboard() {
  if [[ "${OPENCLAW_SKIP_ONBOARD:-}" == "1" ]]; then
    step "步骤 4/4: 跳过官方向导"
    info "将由外层安装脚本写入 DataEyes 配置"
    return 0
  fi

  step "步骤 4/4: 打开 OpenClaw 官方向导"
  local openclaw_cmd="$BIN_HOME/openclaw"
  [[ -x "$openclaw_cmd" ]] || openclaw_cmd="$(command -v openclaw || true)"
  if [[ -z "$openclaw_cmd" ]]; then
    error "未找到 openclaw 命令"
    return 1
  fi
  "$openclaw_cmd" onboard
}

main() {
  echo ""
  echo -e "${GREEN}DataEyes × OpenClaw 安装器${NC}"
  echo -e "${BLUE}仅写入当前用户目录，不会申请管理员权限${NC}"
  echo ""

  install_node_to_user_dir
  npm_install_openclaw
  verify_openclaw
  step_onboard

  echo ""
  success "基础环境准备完成"
  echo "用户目录: $APP_HOME"
  echo "CLI 路径: $BIN_HOME/openclaw"
}

main "$@"
