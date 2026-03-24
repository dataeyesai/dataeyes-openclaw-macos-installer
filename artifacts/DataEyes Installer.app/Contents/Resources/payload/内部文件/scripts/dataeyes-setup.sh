#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="$SCRIPT_DIR"
TEMPLATE="$WORKDIR/dataeyes-provider.json"
if [[ ! -f "$TEMPLATE" ]]; then
  TEMPLATE="$SCRIPT_DIR/../templates/dataeyes-provider.json"
fi
CFG="$HOME/.openclaw/openclaw.json"
SHUYANAI_API_KEY="${SHUYANAI_API_KEY:-${1:-}}"
DATAEYES_API_KEY="${DATAEYES_API_KEY:-${2:-}}"

if [[ -z "$SHUYANAI_API_KEY" && -z "$DATAEYES_API_KEY" ]]; then
  echo "Usage: SHUYANAI_API_KEY=xxx DATAEYES_API_KEY=yyy $0"
  echo "or: $0 <shuyanai-api-key> <dataeyes-api-key>"
  exit 1
fi

mkdir -p "$(dirname "$CFG")"

python3 - "$CFG" "$TEMPLATE" "$SHUYANAI_API_KEY" "$DATAEYES_API_KEY" <<'PY'
import json
import os
import re
import sys
import urllib.error
import urllib.request

cfg_path, tpl_path, shuyanai_api_key, dataeyes_api_key = sys.argv[1:5]

if os.path.exists(cfg_path):
    with open(cfg_path, 'r', encoding='utf-8') as f:
        cfg = json.load(f)
else:
    cfg = {}

with open(tpl_path, 'r', encoding='utf-8') as f:
    tpl = json.load(f)

provider_specs = tpl.get('providerSpecs', {})
fallback_models = tpl.get('fallbackModels', {})
display_names = tpl.get('displayNames', {})
model_candidates = (((tpl.get('agents') or {}).get('defaults') or {}).get('modelCandidates') or [])

DEFAULT_CONTEXT_WINDOW = 256000
DEFAULT_MAX_TOKENS = 8192

def prettify_model_name(model_id):
    parts = [p for p in re.split(r'[-_/]+', model_id) if p]
    rendered = []
    for part in parts:
        upper = part.upper()
        if upper in {'GPT', 'GLM', 'R1', 'R2', 'K2', 'K2P5'}:
            rendered.append(upper)
        elif part.isdigit():
            rendered.append(part)
        else:
            rendered.append(part.capitalize())
    return ' '.join(rendered) or model_id

def endpoint_candidates(base_url):
    base = (base_url or '').rstrip('/')
    if not base:
        return []
    candidates = [f"{base}/models"]
    if not base.endswith('/v1'):
        candidates.append(f"{base}/v1/models")
    result = []
    seen = set()
    for item in candidates:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result

def fetch_models(base_url, api_key):
    if not api_key:
        return [], None
    headers = {
        'Authorization': f'Bearer {api_key}',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'dataeyes-openclaw-installer/1.0'
    }
    for url in endpoint_candidates(base_url):
        req = urllib.request.Request(url, headers=headers, method='GET')
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                payload = json.loads(resp.read().decode('utf-8'))
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, json.JSONDecodeError):
            continue
        data = payload.get('data')
        if isinstance(data, list):
            return data, url
    return [], None

def normalize_models(provider_id, models):
    normalized = []
    seen = set()
    provider_display_names = display_names.get(provider_id, {})
    for item in models:
        if not isinstance(item, dict):
            continue
        model_id = item.get('id')
        if not model_id or model_id in seen:
            continue
        seen.add(model_id)
        normalized.append({
            'id': model_id,
            'name': provider_display_names.get(model_id) or item.get('name') or prettify_model_name(model_id),
            'input': item.get('input') or ['text', 'image'],
            'contextWindow': item.get('contextWindow') or item.get('context_window') or DEFAULT_CONTEXT_WINDOW,
            'maxTokens': item.get('maxTokens') or item.get('max_output_tokens') or DEFAULT_MAX_TOKENS
        })
    return normalized

providers = {}
selected_models = []

for provider_id, api_key in [('shuyanai', shuyanai_api_key), ('dataeyes', dataeyes_api_key)]:
    if not api_key:
        continue
    spec = provider_specs.get(provider_id) or {}
    fetched_models, endpoint = fetch_models(spec.get('baseUrl'), api_key)
    normalized_models = normalize_models(provider_id, fetched_models)
    if not normalized_models:
        normalized_models = fallback_models.get(provider_id, [])
    providers[provider_id] = {
        'baseUrl': spec.get('baseUrl'),
        'api': spec.get('api', 'openai-responses'),
        'apiKey': api_key,
        'models': normalized_models
    }
    for model in normalized_models:
        selected_models.append(f"{provider_id}/{model['id']}")
    if endpoint:
        print(f"Fetched {provider_id} models from: {endpoint}")
    else:
        print(f"Using fallback models for: {provider_id}")

if not providers:
    raise SystemExit('No provider API keys were supplied.')

if not selected_models:
    raise SystemExit('No models detected from the configured providers. Please verify the API Key or network connectivity.')

cfg['models'] = {
    'mode': 'replace',
    'providers': providers
}

primary = None
for candidate in model_candidates:
    if candidate in selected_models:
        primary = candidate
        break
if primary is None and selected_models:
    primary = selected_models[0]

fallbacks = [model for model in selected_models if model != primary]
defaults = cfg.setdefault('agents', {}).setdefault('defaults', {})
if primary:
    defaults['model'] = {
        'primary': primary,
        'fallbacks': fallbacks[:4]
    }
defaults['models'] = {model: {} for model in selected_models}
cfg.setdefault('gateway', {})['mode'] = 'local'

with open(cfg_path, 'w', encoding='utf-8') as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
    f.write('\n')

print('Injected providers:', ', '.join(providers.keys()))
print('Detected models:', len(selected_models))
print('Default model:', primary or '')
PY

chmod 600 "$CFG" || true
echo "DataEyes setup done: $CFG"
