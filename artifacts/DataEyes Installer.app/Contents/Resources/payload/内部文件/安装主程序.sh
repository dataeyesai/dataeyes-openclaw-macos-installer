#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
INNER_DIR="$DIR/内部文件"
APP_HOME="${OPENCLAW_HOME:-$HOME/.dataeyes-openclaw}"
export PATH="$APP_HOME/npm/bin:$APP_HOME/node/bin:$HOME/.npm-global/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

OPENCLAW_SKIP_ONBOARD=1 bash "$INNER_DIR/安装OpenClaw基础环境.sh"
export PATH="$APP_HOME/npm/bin:$APP_HOME/node/bin:$HOME/.npm-global/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
hash -r || true

OPENCLAW_BIN="$APP_HOME/npm/bin/openclaw"
[[ -x "$OPENCLAW_BIN" ]] || OPENCLAW_BIN="$(command -v openclaw || true)"
if [[ -z "$OPENCLAW_BIN" ]]; then
  echo "OpenClaw 安装后未找到 openclaw 命令"
  exit 1
fi

open_dashboard() {
  local dashboard_output dashboard_url
  dashboard_url="$(
    python3 - <<'PY'
import json, os
cfg_path = os.path.expanduser("~/.openclaw/openclaw.json")
token = ""
try:
    with open(cfg_path, "r", encoding="utf-8") as f:
        cfg = json.load(f)
    token = (((cfg.get("gateway") or {}).get("auth") or {}).get("token")) or ""
except Exception:
    token = ""
if token:
    print(f"http://localhost:18789/#token={token}")
PY
  )"
  if [[ -n "$dashboard_url" ]]; then
    if open "$dashboard_url" 2>/dev/null; then
      echo "已打开控制台（带令牌）"
    else
      echo "控制台地址已生成，请运行以下命令获取带令牌地址："
      echo "  python3 - <<'PY'"
      echo "  import json, os"
      echo "  cfg=json.load(open(os.path.expanduser('~/.openclaw/openclaw.json')))"
      echo "  print('http://localhost:18789/#token=' + cfg['gateway']['auth']['token'])"
      echo "  PY"
    fi
    return 0
  fi
  return 1
}

SHUYANAI_API_KEY="${SHUYANAI_API_KEY:-}"
DATAEYES_API_KEY="${DATAEYES_API_KEY:-}"
if [[ -z "$SHUYANAI_API_KEY" ]]; then
  if [[ -t 0 ]]; then
    read -rsp "请输入国内站 API Key（可回车跳过）: " SHUYANAI_API_KEY
    echo ""
  elif [[ -t 1 || -t 2 ]]; then
    read -rsp "请输入国内站 API Key（可回车跳过）: " SHUYANAI_API_KEY < /dev/tty
    echo "" > /dev/tty
  fi
fi
if [[ -z "$DATAEYES_API_KEY" ]]; then
  if [[ -t 0 ]]; then
    read -rsp "请输入国际站 API Key（可回车跳过）: " DATAEYES_API_KEY
    echo ""
  elif [[ -t 1 || -t 2 ]]; then
    read -rsp "请输入国际站 API Key（可回车跳过）: " DATAEYES_API_KEY < /dev/tty
    echo "" > /dev/tty
  fi
fi
if [[ -z "$SHUYANAI_API_KEY" && -z "$DATAEYES_API_KEY" ]]; then
  echo "至少需要填写一个 API Key"
  exit 1
fi

SHUYANAI_API_KEY="$SHUYANAI_API_KEY" DATAEYES_API_KEY="$DATAEYES_API_KEY" bash "$INNER_DIR/scripts/dataeyes-setup.sh"
"$OPENCLAW_BIN" gateway install --force >/tmp/openclaw-gateway-install.log 2>&1 || {
  cat /tmp/openclaw-gateway-install.log
  exit 1
}
"$OPENCLAW_BIN" gateway restart >/tmp/openclaw-gateway-restart.log 2>&1 || {
  cat /tmp/openclaw-gateway-restart.log
  exit 1
}
bash "$INNER_DIR/scripts/dataeyes-verify.sh"
open_dashboard || {
  echo "控制台未自动打开，请稍后重试或手动执行:"
  echo "  python3 - <<'PY'"
  echo "  import json, os"
  echo "  cfg=json.load(open(os.path.expanduser('~/.openclaw/openclaw.json')))"
  echo "  print('http://localhost:18789/#token=' + cfg['gateway']['auth']['token'])"
  echo "  PY"
}
