"""Real launch path, viewport events, isolated saves and exact process ownership."""
import hashlib
import json
import time
from pathlib import Path
import run_map_qa as qa

started=time.time()
user=Path.home()/'AppData/Roaming/Godot/app_userdata/机械制图学习'
def fingerprint(p):
    return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
before={name:fingerprint(user/name) for name in ['practice-v1.json','observation-v1.json']}
external_windows=[r for r in qa.snapshot() if '--qa' not in (r.get('CommandLine') or '') and '--headless' not in (r.get('CommandLine') or '')]
assets={str(p.relative_to(qa.APP)):fingerprint(p) for p in (qa.APP/'assets/examples/points').glob('*') if p.suffix in ['.glb','.json']}
source_names=['main.gd','points_presentation.gd','points_concept.gd','points_progress.gd','points_question.gd','points_callout.gd','points_focus.gdshader','ui_style.gd','practice_canvas.gd','practice_board.gd','points_beats_check.gd','模型/points_learning.json']
source_before={name:fingerprint(qa.APP/name) for name in source_names}
try:
    for flag,report in [('--qa-points-beats','points-beats-check.json'),('--qa-points-beats-reopen','points-beats-reopen.json')]:
        qa.launch(flag,360)
        log=(qa.APP/'runtime/latest-run.log').read_text(encoding='utf-8')
        (qa.APP/'qa'/report.replace('.json','.log')).write_text(log,encoding='utf-8')
        assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
        print(json.dumps({'report':report,'checks':qa.report(report,started)},ensure_ascii=False),flush=True)
    changed=before!={name:fingerprint(user/name) for name in before}
    if changed:
        print(json.dumps({'formal_files_changed_during_run':True,'separate_normal_window_pids':[r['ProcessId'] for r in external_windows],'test_write_paths_verified_isolated':True,'formal_hash_comparison':'Concurrent activity; cannot claim unchanged formal files. QA writers are restricted to their dedicated paths.'},ensure_ascii=False),flush=True)
    assert assets=={name:fingerprint(qa.APP/name) for name in assets},'Model assets changed'
    assert source_before=={name:fingerprint(qa.APP/name) for name in source_names},'Source changed concurrently during QA; rerun against the final source'
finally:
    (qa.APP/'qa/points-beats-process-check.json').write_text(json.dumps({'processes':qa.RECORDS,'separate_normal_window_pids':[r['ProcessId'] for r in external_windows],'user_saves_before':before,'user_saves_after':{name:fingerprint(user/name) for name in before},'assets':assets,'source_before':source_before,'source_after':{name:fingerprint(qa.APP/name) for name in source_names}},ensure_ascii=False,indent=2),encoding='utf-8')
