#!/usr/bin/env bash
set -euo pipefail

REPORT_DIR="${1:-$HOME/.openclaw/verify-output}"
mkdir -p "$REPORT_DIR"
TS="$(date +%Y%m%d-%H%M%S)"
TXT="$REPORT_DIR/dataeyes-verify-$TS.txt"
JSON="$REPORT_DIR/dataeyes-verify-$TS.json"
CFG="$HOME/.openclaw/openclaw.json"
APP_HOME="${OPENCLAW_HOME:-$HOME/.dataeyes-openclaw}"
GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://127.0.0.1:18789}"
GATEWAY_LABEL="${OPENCLAW_GATEWAY_LABEL:-ai.openclaw.gateway}"

export PATH="$APP_HOME/npm/bin:$APP_HOME/node/bin:$HOME/.npm-global/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"
hash -r || true

OPENCLAW_BIN="$APP_HOME/npm/bin/openclaw"
[[ -x "$OPENCLAW_BIN" ]] || OPENCLAW_BIN="$(command -v openclaw || true)"
OPENCLAW_VERSION="$({ "$OPENCLAW_BIN" --version; } 2>/dev/null || true)"
STATUS_OUT="$({ "$OPENCLAW_BIN" status; } 2>/dev/null || true)"
PLIST="$HOME/Library/LaunchAgents/$GATEWAY_LABEL.plist"
HAS_CFG="no"
PROVIDERS=""
DEFAULT_MODEL=""
if [[ -f "$CFG" ]]; then
  HAS_CFG="yes"
  PY_OUT="$(python3 - "$CFG" <<'PY'
import json,sys
cfg=json.load(open(sys.argv[1]))
providers=((cfg.get('models') or {}).get('providers') or {})
print(','.join(sorted(providers.keys())))
model=((cfg.get('agents') or {}).get('defaults') or {}).get('model') or {}
if isinstance(model, dict):
    print(model.get('primary') or '')
else:
    print(model or '')
PY
)"
  PROVIDERS="$(printf '%s' "$PY_OUT" | sed -n '1p')"
  DEFAULT_MODEL="$(printf '%s' "$PY_OUT" | sed -n '2p')"
fi

check_gateway() {
  local attempt
  for attempt in 1 2 3 4 5 6 7 8; do
    if curl -fsS --max-time 3 "$GATEWAY_URL" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

PLIST_ARGS="$(
  /usr/libexec/PlistBuddy -c 'Print :ProgramArguments' "$PLIST" 2>/dev/null || true
)"
PLIST_PATH="$(
  /usr/libexec/PlistBuddy -c 'Print :EnvironmentVariables:PATH' "$PLIST" 2>/dev/null || true
)"
LAUNCHCTL_ROW="$(launchctl list | awk '$3 == "'"$GATEWAY_LABEL"'" { print }' || true)"
LOG_TAIL="$(
  tail -n 60 "$HOME/.openclaw/logs/gateway.log" 2>/dev/null || true
)"
ERR_LOG_TAIL="$(
  tail -n 60 "$HOME/.openclaw/logs/gateway.err.log" 2>/dev/null || true
)"

if check_gateway; then
  GATEWAY_OK="yes"
  GATEWAY_ERROR=""
else
  GATEWAY_OK="no"
  GATEWAY_ERROR="$(
    curl -sv --max-time 3 "$GATEWAY_URL" 2>&1 | tail -n 20
  )"
fi

cat > "$TXT" <<EOF
openclaw_bin=$OPENCLAW_BIN
openclaw_version=$OPENCLAW_VERSION
has_config=$HAS_CFG
providers=$PROVIDERS
default_model=$DEFAULT_MODEL
gateway_url=$GATEWAY_URL
gateway_ok=$GATEWAY_OK

[openclaw status]
$STATUS_OUT

[launchctl list]
$LAUNCHCTL_ROW

[launch agent plist]
$PLIST

[launch agent program arguments]
$PLIST_ARGS

[launch agent path]
$PLIST_PATH

[gateway curl error]
$GATEWAY_ERROR

[gateway.log tail]
$LOG_TAIL

[gateway.err.log tail]
$ERR_LOG_TAIL
EOF

python3 - "$OPENCLAW_BIN" "$OPENCLAW_VERSION" "$HAS_CFG" "$PROVIDERS" "$DEFAULT_MODEL" "$GATEWAY_URL" "$GATEWAY_OK" <<'PY' > "$JSON"
import json, sys
print(json.dumps({
  'openclaw_bin': sys.argv[1],
  'openclaw_version': sys.argv[2],
  'has_config': sys.argv[3],
  'providers': sys.argv[4].split(',') if sys.argv[4] else [],
  'default_model': sys.argv[5],
  'gateway_url': sys.argv[6],
  'gateway_ok': sys.argv[7] == 'yes'
}, ensure_ascii=False, indent=2))
PY

echo "Wrote: $TXT"
echo "Wrote: $JSON"

if [[ "$GATEWAY_OK" != "yes" ]]; then
  echo "Gateway 健康检查失败：$GATEWAY_URL 无法访问"
  echo "最近诊断信息已写入: $TXT"
  exit 1
fi
