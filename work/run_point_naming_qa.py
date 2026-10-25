import hashlib,json,time
from pathlib import Path
import run_map_qa as qa
started=time.time()
user=Path.home()/'AppData/Roaming/Godot/app_userdata/机械制图学习'
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
original={n:digest(user/n) for n in ['practice-v1.json','observation-v1.json']}
for n in ['qa-point-naming.json','qa-point-naming-observation.json']: (user/n).unlink(missing_ok=True)
try:
    counts={}
    for flag,f in [('--qa-point-naming','point-naming-check.json'),('--qa-point-naming-reopen','point-naming-reopen.json')]:
        qa.launch(flag,60)
        log=(qa.APP/'runtime/latest-run.log').read_text(encoding='utf-8')
        (qa.APP/'qa'/f.replace('.json','.log')).write_text(log,encoding='utf-8')
        assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
        counts[f]=qa.report(f,started)
    assert original=={n:digest(user/n) for n in original}
    print(json.dumps({'checks':counts,'user_saves_unchanged':True,'processes':qa.RECORDS},ensure_ascii=False))
finally:
    (qa.APP/'qa/point-naming-process.json').write_text(json.dumps(qa.RECORDS,ensure_ascii=False,indent=2),encoding='utf-8')
