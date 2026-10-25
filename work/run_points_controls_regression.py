"""Check existing student shortcuts without confusing concurrent user edits with QA writes."""
import hashlib
import json
import time
from pathlib import Path
import run_map_qa as qa

started = time.time()
user = Path.home() / 'AppData/Roaming/Godot/app_userdata/机械制图学习'

def hashes():
    return {name: hashlib.sha256((user / name).read_bytes()).hexdigest()
            if (user / name).exists() else None
            for name in ['practice-v1.json', 'observation-v1.json']}

before = hashes()
for name in ['qa-point-naming.json', 'qa-point-naming-observation.json']:
    (user / name).unlink(missing_ok=True)
counts = {}
try:
    for flag, report in [('--qa-point-naming', 'point-naming-check.json'),
                         ('--qa-point-naming-reopen', 'point-naming-reopen.json')]:
        qa.launch(flag, 60)
        log = (qa.APP / 'runtime/latest-run.log').read_text(encoding='utf-8')
        (qa.APP / 'qa' / report.replace('.json', '.log')).write_text(log, encoding='utf-8')
        assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log, log
        counts[report] = qa.report(report, started)
    print(json.dumps({'checks': counts, 'formal_hashes_equal': before == hashes()}, ensure_ascii=False))
finally:
    (qa.APP / 'qa/points-controls-regression-process.json').write_text(
        json.dumps({'processes': qa.RECORDS, 'user_saves_before': before,
                    'user_saves_after': hashes(), 'counts': counts}, ensure_ascii=False, indent=2), encoding='utf-8')
