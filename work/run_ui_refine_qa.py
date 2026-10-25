"""Real-launcher QA with owned process tracking and internal viewport input."""
import json
import subprocess
import sys
import time
import run_map_qa as qa

APP = qa.APP
started = time.time()
try:
    with (APP / 'qa/ui-refine-import.log').open('w', encoding='utf-8') as log:
        process = subprocess.Popen([str(APP / 'runtime/godot.exe'), '--headless', '--editor', '--path', str(APP), '--import', '--quit'], stdout=log, stderr=log, creationflags=0x08000000)
        code = process.wait(timeout=40)
        qa.RECORDS.append({'flag': 'ui-refine-import', 'owned_processes': [process.pid], 'normal_exit': code == 0, 'remaining': []})
    contents = (APP / 'qa/ui-refine-import.log').read_text(encoding='utf-8')
    assert code == 0 and 'SCRIPT ERROR' not in contents, contents
    counts = {}
    scenarios = [
        ('--qa-ui-refine-check', 'ui-refine-check.json', 120),
        ('--qa-canvas-check', 'canvas-interaction-check.json', 120),
        ('--qa-map-check', 'knowledge-map-check.json', 120),
        ('--qa-map-reopen', 'knowledge-map-reopen.json', 35),
        ('--qa-guide-check', 'guide-interaction-check.json', 180),
    ]
    if '--focused' in sys.argv: scenarios = scenarios[:2]
    for flag, report, timeout in scenarios:
        qa.launch(flag, timeout)
        counts[report] = qa.report(report, started)
        log = (APP / 'runtime/latest-run.log').read_text(encoding='utf-8')
        assert 'SCRIPT ERROR' not in log, log
        print(json.dumps({'completed': flag, 'checks': counts[report]}, ensure_ascii=False), flush=True)
    print(json.dumps({'total_checks': sum(counts.values()), 'checks': counts, 'processes': qa.RECORDS}, ensure_ascii=False), flush=True)
finally:
    record = APP / 'qa/ui-refine-process-check.json'
    previous = json.loads(record.read_text(encoding='utf-8')) if '--focused' in sys.argv and record.exists() else []
    record.write_text(json.dumps(previous + qa.RECORDS, ensure_ascii=False, indent=2), encoding='utf-8')
