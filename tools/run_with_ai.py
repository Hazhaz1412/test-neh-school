#!/usr/bin/env python3
"""Start the loopback grader and optionally Godot. API key entered invisibly;
never written into the project. --ai-only supports running F5 in the editor.
"""
import argparse
import getpass
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
from urllib.request import urlopen
from soul_ai_config import read_settings, api_key_for
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--model', help='Exact model ID, e.g. gemini-3.8-flash')
parser.add_argument('--provider', choices=['gemini', 'opencode', 'opencode-go'], default=None)
parser.add_argument('--ai-only', action='store_true')
args = parser.parse_args()
settings = read_settings()
provider = args.provider or settings.get('provider', 'gemini')
default_model = 'gemini-3.8-flash' if provider == 'gemini' else 'mimo-v2.6-flash-free'
model = (args.model or (settings.get('model') if settings.get('provider') == provider else None) or default_model).split('/')[-1]
if provider == 'gemini' and model != 'gemini-3.8-flash':
    parser.error('Use gemini-3.8-flash for this demo.')
if provider != 'gemini' and not (model.endswith('-free') or model == 'big-pickle'):
    parser.error('This demo is configured for free models only; choose an explicit free model ID.')
env = os.environ.copy()
env['SOUL_AI_PROVIDER'] = provider
env['SOUL_AI_MODEL'] = model
key_variable = 'GOOGLE_API_KEY' if provider == 'gemini' else 'OPENCODE_API_KEY'
env[key_variable] = api_key_for(provider, settings)
if not env[key_variable]:
    env[key_variable] = getpass.getpass('%s API key (hidden; not saved): ' % provider).strip()
if not env[key_variable]:
    parser.error('An API key is required by this provider.')
root = Path(__file__).resolve().parents[1]
bridge = subprocess.Popen([sys.executable, str(root / 'tools/soul_ai_server.py')], cwd=root, env=env)
try:
    for _ in range(30):
        if bridge.poll() is not None:
            raise RuntimeError('Bridge could not start; port 8765 may already be in use.')
        try:
            with urlopen('http://127.0.0.1:8765/health', timeout=.3):
                break
        except OSError:
            time.sleep(.1)
    if args.ai_only:
        print('AI bridge ready. You can run F5 in Godot. Ctrl+C stops the bridge.')
        bridge.wait()
    else:
        godot = shutil.which('godot') or shutil.which('godot4')
        if not godot:
            raise RuntimeError('Godot not found. Use --ai-only and run the editor manually.')
        subprocess.run([godot, '--path', str(root)], cwd=root)
except KeyboardInterrupt:
    pass
finally:
    bridge.terminate()
    try:
        bridge.wait(timeout=3)
    except subprocess.TimeoutExpired:
        bridge.kill()
