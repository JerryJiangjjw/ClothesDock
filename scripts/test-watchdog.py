#!/usr/bin/env python3
"""Exercise the real watchdog flow with mocked system commands."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).parent / 'dock-watchdog.sh').read_text()
with tempfile.TemporaryDirectory(prefix='clothesdock-watchdog-') as directory:
    root = Path(directory)
    log = root / 'calls.jsonl'
    mock = root / 'mock.py'
    mock.write_text('''#!/usr/bin/env python3
import json, os, sys
with open(os.environ['WATCHDOG_LOG'], 'a') as file:
    file.write(json.dumps(sys.argv[1:]) + '\\n')
if '-bool' in sys.argv and sys.argv[-1] not in ('true', 'false'):
    sys.exit(255)
if os.environ.get('FAIL_WRITE') and 'write' in sys.argv:
    sys.exit(1)
''')
    mock.chmod(0o755)
    script = root / 'watchdog.sh'
    script.write_text(source.replace('/usr/bin/defaults', str(mock)).replace('/usr/bin/killall', str(mock)))
    backup = root / 'backup.json'
    env = {**os.environ, 'WATCHDOG_LOG': str(log)}
    def exercise(values, failure=False):
        owner = subprocess.Popen(['/bin/sleep', '0.2'])
        watchdog = subprocess.Popen(['/bin/sh', str(script), str(owner.pid), str(backup), *values], env={**env, **({'FAIL_WRITE': '1'} if failure else {})})
        owner.wait()
        return watchdog.wait(timeout=8)
    backup.write_text('{}')
    assert exercise(['1', '__absent__', '0.25']) == 0
    calls = [json.loads(line) for line in log.read_text().splitlines()]
    assert calls == [
        ['write', 'com.apple.dock', 'autohide', '-bool', 'true'],
        ['delete', 'com.apple.dock', 'autohide-delay'],
        ['write', 'com.apple.dock', 'autohide-time-modifier', '-float', '0.25'],
        ['Dock'],
    ], calls
    assert not backup.exists()
    log.unlink()
    backup.write_text('{}')
    assert exercise(['0', '2', '0.5'], failure=True) != 0
    assert backup.exists(), 'Failed restoration must retain recovery data'
    backup.unlink()
    log.unlink()
    assert exercise(['0', '2', '0.5']) == 0
    assert not log.exists(), 'Missing backup must not change preferences'
print('PASS: owner exit restores exact values, failures preserve backup, missing backup is a no-op')
