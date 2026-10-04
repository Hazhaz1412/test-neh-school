"""Private desktop configuration, kept outside the Godot project/export."""
import json
import os
from pathlib import Path

def read_settings():
    path = Path(os.getenv('SOUL_AI_CONFIG', str(Path.home() / '.config/neh-school/ai.json')))
    try:
        value = json.loads(path.read_text())
        return value if isinstance(value, dict) else {}
    except (OSError, ValueError):
        return {}


def api_key_for(provider, settings):
    """Resolve only this provider's credentials; never forward another key."""
    if provider == 'gemini':
        key = os.getenv('GOOGLE_API_KEY') or os.getenv('GEMINI_API_KEY') or settings.get('gemini_api_key')
    elif provider in ('opencode', 'opencode-go'):
        key = os.getenv('OPENCODE_API_KEY') or settings.get('opencode_api_key')
    elif provider == 'openai':
        key = os.getenv('OPENAI_API_KEY')
    else:
        return ''
    if not key and provider == settings.get('provider'):
        key = settings.get('api_key', '')
    return key.strip() if isinstance(key, str) else ''
