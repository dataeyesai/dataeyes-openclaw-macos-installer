#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${DATAEYES_REPO_URL:-https://github.com/YOUR_ORG/YOUR_REPO.git}"
BRANCH="${DATAEYES_BRANCH:-main}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}i ${NC}$*"; }
success() { echo -e "${GREEN}OK ${NC}$*"; }
warn()    { echo -e "${YELLOW}! ${NC}$*"; }
error()   { echo -e "${RED}X ${NC}$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_PATH="$SCRIPT_DIR/内部文件/安装主程序.sh"

ensure_git() {
  if command -v git >/dev/null 2>&1; then
    return 0
  fi
  error "未检测到 git，请先安装 git 后重试。"
  echo "macOS 可先执行: xcode-select --install"
  exit 1
}

clone_repo_if_needed() {
  local tmp_dir="$1"
  info "正在下载安装资源..."
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$tmp_dir/repo" >/dev/null 2>&1 || {
    error "无法从 GitHub 下载仓库: $REPO_URL"
    exit 1
  }
  echo "$tmp_dir/repo"
}

run_local_installer() {
  if [[ ! -f "$INSTALLER_PATH" ]]; then
    error "没有找到安装脚本: $INSTALLER_PATH"
    exit 1
  fi
  bash "$INSTALLER_PATH"
}

run_remote_installer() {
  ensure_git
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  local repo_dir
  repo_dir="$(clone_repo_if_needed "$tmp_dir")"

  if [[ ! -f "$repo_dir/内部文件/安装主程序.sh" ]]; then
    error "仓库中没有找到 /内部文件/安装主程序.sh"
    exit 1
  fi

  success "下载完成，开始安装"
  bash "$repo_dir/内部文件/安装主程序.sh"
}

main() {
  echo "DataEyes GitHub Installer"
  echo "Repo: $REPO_URL"
  echo ""

  if [[ -f "$INSTALLER_PATH" ]]; then
    run_local_installer
  else
    run_remote_installer
  fi
}

main "$@"
