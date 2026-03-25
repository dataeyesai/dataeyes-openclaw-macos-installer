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
managed_provider_ids = list(provider_specs.keys())
existing_models_cfg = cfg.get('models') or {}
existing_providers = existing_models_cfg.get('providers') or {}
existing_defaults = ((cfg.get('agents') or {}).get('defaults') or {})

DEFAULT_CONTEXT_WINDOW = 256000
DEFAULT_MAX_TOKENS = 8192
EXCLUDED_MODEL_KEYWORDS = (
    'image',
    'vision',
    'video',
    'audio',
    'tts',
    'speech',
    'voice',
    'embedding',
    'embed',
    'rerank',
    'moderation',
    'ocr',
    'transcribe',
    'realtime',
    'preview',
    'seedream',
    'seedance',
    'omni'
)
ALLOWED_CHAT_MODEL_HINTS = (
    'gpt',
    'claude',
    'gemini',
    'deepseek',
    'glm',
    'qwen',
    'kimi',
    'moonshot',
    'minimax',
    'doubao',
    'mistral',
    'llama',
    'o1',
    'o3',
    'o4'
)

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
    candidates = [f'{base}/models']
    if not base.endswith('/v1'):
        candidates.append(f'{base}/v1/models')
    if base.endswith('/models'):
        candidates.insert(0, base)
    result = []
    seen = set()
    for item in candidates:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result

def response_model_items(payload):
    if isinstance(payload, list):
        return payload
    if not isinstance(payload, dict):
        return []

    for key in ('data', 'models', 'items', 'results'):
        value = payload.get(key)
        if isinstance(value, list):
            return value
        if isinstance(value, dict):
            nested = response_model_items(value)
            if nested:
                return nested
    return []

def get_nested_value(item, *keys):
    for key in keys:
        if key in item and item.get(key) is not None:
            return item.get(key)
    return None

def normalize_input_capabilities(item):
    if not isinstance(item, dict):
        return ['text', 'image']

    explicit = get_nested_value(item, 'input', 'input_modalities', 'inputModalities', 'modalities')
    if isinstance(explicit, list) and explicit:
        values = []
        for value in explicit:
            if isinstance(value, str):
                lowered = value.lower()
                if lowered in ('text', 'image', 'audio', 'video', 'tool'):
                    values.append(lowered)
        if values:
            return sorted(set(values))

    capabilities = item.get('capabilities')
    if isinstance(capabilities, dict):
        values = ['text']
        for key in ('image', 'vision'):
            if capabilities.get(key):
                values.append('image')
        return sorted(set(values))

    return ['text', 'image']

def looks_like_chat_model(model_id, source, normalized_input):
    haystacks = [model_id.lower()]
    if isinstance(source, dict):
        for key in ('name', 'type', 'family', 'description'):
            value = source.get(key)
            if isinstance(value, str):
                haystacks.append(value.lower())

    combined = ' '.join(haystacks)
    if 'text' not in normalized_input:
        return False

    if any(keyword in combined for keyword in EXCLUDED_MODEL_KEYWORDS):
        return False

    if not any(keyword in combined for keyword in ALLOWED_CHAT_MODEL_HINTS):
        return False

    return True

def sort_key_for_model(provider_id, model_id):
    preferred = {
        'dataeyes': [
            'gpt-5.4',
            'claude-opus-4-6',
            'gemini-3.1-pro-preview-customtools'
        ],
        'shuyanai': [
            'deepseek-chat',
            'qwen-max',
            'glm-4-plus'
        ]
    }
    order = preferred.get(provider_id, [])
    if model_id in order:
        return (0, order.index(model_id), model_id)
    return (1, 9999, model_id)

def extract_model_id(item):
    if isinstance(item, str):
        return item.strip()
    if not isinstance(item, dict):
        return ''
    for key in ('id', 'model_id', 'modelId', 'model', 'name'):
        value = item.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ''

def fetch_models(base_url, api_key):
    if not api_key:
        return [], None, 'missing api key'

    headers = {
        'Authorization': f'Bearer {api_key}',
        'x-api-key': api_key,
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'dataeyes-openclaw-installer/1.0'
    }
    last_error = 'unknown error'

    for url in endpoint_candidates(base_url):
        req = urllib.request.Request(url, headers=headers, method='GET')
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                payload = json.loads(resp.read().decode('utf-8'))
        except urllib.error.HTTPError as exc:
            try:
                detail = exc.read().decode('utf-8', errors='ignore')[:200]
            except Exception:
                detail = ''
            last_error = f'HTTP {exc.code} from {url}' + (f': {detail}' if detail else '')
            continue
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_error = f'{type(exc).__name__} from {url}: {exc}'
            continue

        data = response_model_items(payload)
        if isinstance(data, list) and data:
            return data, url, None
        last_error = f'no model list found in {url}'

    return [], None, last_error

def normalize_models(provider_id, models):
    normalized = []
    seen = set()
    provider_display_names = display_names.get(provider_id, {})
    for item in models:
        model_id = extract_model_id(item)
        if not model_id or model_id in seen:
            continue
        source = item if isinstance(item, dict) else {}
        normalized_input = normalize_input_capabilities(source)
        if not looks_like_chat_model(model_id, source, normalized_input):
            continue
        seen.add(model_id)
        normalized.append({
            'id': model_id,
            'name': provider_display_names.get(model_id) or source.get('name') or prettify_model_name(model_id),
            'input': normalized_input,
            'contextWindow': get_nested_value(
                source,
                'contextWindow',
                'context_window',
                'max_input_tokens',
                'maxInputTokens',
                'inputTokenLimit',
                'max_context_tokens'
            ) or DEFAULT_CONTEXT_WINDOW,
            'maxTokens': get_nested_value(
                source,
                'maxTokens',
                'max_output_tokens',
                'maxOutputTokens',
                'outputTokenLimit',
                'completionTokenLimit',
                'max_completion_tokens'
            ) or DEFAULT_MAX_TOKENS
        })
    normalized.sort(key=lambda item: sort_key_for_model(provider_id, item['id']))
    return normalized

def existing_api_key(provider_id):
    provider = existing_providers.get(provider_id) or {}
    api_key = provider.get('apiKey')
    return api_key if isinstance(api_key, str) else ''

def existing_provider_models(provider_id):
    provider = existing_providers.get(provider_id) or {}
    return normalize_models(provider_id, provider.get('models') or [])

def resolve_api_key(provider_id, cli_value):
    if cli_value:
        return cli_value
    return existing_api_key(provider_id)

def resolve_base_url(provider_id, spec):
    env_key = f'{provider_id.upper()}_BASE_URL'
    return os.environ.get(env_key) or spec.get('baseUrl')

def qualified_model_names(providers_map):
    names = []
    for provider_id, provider in providers_map.items():
        for model in provider.get('models') or []:
            model_id = model.get('id')
            if model_id:
                names.append(f'{provider_id}/{model_id}')
    return names

managed_providers = {}
selected_models = []

for provider_id, cli_api_key in [('shuyanai', shuyanai_api_key), ('dataeyes', dataeyes_api_key)]:
    api_key = resolve_api_key(provider_id, cli_api_key)
    if not api_key:
        continue

    spec = provider_specs.get(provider_id) or {}
    base_url = resolve_base_url(provider_id, spec)
    fetched_models, endpoint, fetch_error = fetch_models(base_url, api_key)
    normalized_models = normalize_models(provider_id, fetched_models)

    if not normalized_models:
        normalized_models = existing_provider_models(provider_id)

    if not normalized_models:
        normalized_models = fallback_models.get(provider_id, [])

    managed_providers[provider_id] = {
        'baseUrl': base_url,
        'api': spec.get('api', 'openai-responses'),
        'apiKey': api_key,
        'models': normalized_models
    }

    for model in normalized_models:
        selected_models.append(f"{provider_id}/{model['id']}")

    if endpoint:
        print(f'Fetched {provider_id} models from: {endpoint}')
    elif fetch_error:
        print(f'Reused {provider_id} models ({len(normalized_models)}) because live fetch failed: {fetch_error}')
    else:
        print(f'Using fallback models for: {provider_id}')

if not managed_providers:
    raise SystemExit(
        'No provider API keys were supplied. '
        'Pass keys as arguments/env or ensure ~/.openclaw/openclaw.json already contains provider apiKey values.'
    )

providers = {
    provider_id: provider
    for provider_id, provider in existing_providers.items()
    if provider_id not in managed_provider_ids
}
providers.update(managed_providers)

all_models = qualified_model_names(providers)
if not all_models:
    raise SystemExit('No models detected from the configured providers. Please verify the API Key or network connectivity.')

cfg['models'] = {
    'mode': (tpl.get('models') or {}).get('mode') or existing_models_cfg.get('mode') or 'replace',
    'providers': providers
}

current_model = existing_defaults.get('model') or {}
current_primary = current_model.get('primary') if isinstance(current_model, dict) else current_model
primary = None

for candidate in model_candidates:
    if candidate in all_models:
        primary = candidate
        break

if primary is None and isinstance(current_primary, str) and current_primary in all_models:
    primary = current_primary

if primary is None and selected_models:
    primary = selected_models[0]

if primary is None and all_models:
    primary = all_models[0]

fallbacks = [model for model in all_models if model != primary]
defaults = cfg.setdefault('agents', {}).setdefault('defaults', {})
if primary:
    defaults['model'] = {
        'primary': primary,
        'fallbacks': fallbacks[:8]
    }

existing_default_models = existing_defaults.get('models') if isinstance(existing_defaults.get('models'), dict) else {}
defaults['models'] = {model: existing_default_models.get(model, {}) for model in all_models}
cfg.setdefault('gateway', {})['mode'] = 'local'

with open(cfg_path, 'w', encoding='utf-8') as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
    f.write('\n')

print('Injected providers:', ', '.join(sorted(providers.keys())))
print('Detected models:', len(all_models))
print('Default model:', primary or '')
PY

chmod 600 "$CFG" || true
echo "DataEyes setup done: $CFG"
