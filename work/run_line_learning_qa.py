"""Real launcher, internal input, independent saves and only owned processes."""
import hashlib,json,time
from pathlib import Path
import run_map_qa as qa
started=time.time()
user=Path.home()/'AppData/Roaming/Godot/app_userdata/机械制图学习'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
saves={name:sha(user/name) for name in ['practice-v1.json','observation-v1.json']}
assets={str(p.relative_to(qa.APP)):sha(p) for p in (qa.APP/'assets/examples').glob('*/*') if p.suffix in ['.glb','.json']}
names=['main.gd','practice_board.gd','line_geometry.gd','line_presentation.gd','line_paper.gd','line_callout.gd','line_condition_rows.gd','line_learning_check.gd','模型/line_learning.json','points_callout.gd','points_presentation.gd','模型/points_learning.json']
source={name:sha(qa.APP/name) for name in names}
try:
    for flag,report in [('--qa-line-learning','line-learning-check.json'),('--qa-line-reopen','line-learning-reopen.json')]:
        qa.launch(flag,240)
        log=(qa.APP/'runtime/latest-run.log').read_text(encoding='utf-8')
        (qa.APP/'qa'/report.replace('.json','.log')).write_text(log,encoding='utf-8')
        assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
        print(json.dumps({'report':report,'checks':qa.report(report,started)},ensure_ascii=False),flush=True)
    assert source=={name:sha(qa.APP/name) for name in names},'Source changed during QA'
    assert assets=={name:sha(qa.APP/name) for name in assets},'Observation geometry assets changed'
finally:
    (qa.APP/'qa/line-learning-process-check.json').write_text(json.dumps(dict(processes=qa.RECORDS,saves_before=saves,saves_after={name:sha(user/name) for name in saves},source_before=source,source_after={name:sha(qa.APP/name) for name in names},assets=assets),ensure_ascii=False,indent=2),encoding='utf-8')
