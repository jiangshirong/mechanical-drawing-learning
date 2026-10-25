"""Regression through the current legacy entrypoints; no historical section routing."""
import hashlib,json,subprocess,time,sys
from run_map_qa import APP,launch,report,RECORDS
started=time.time();counts={}
user=__import__('pathlib').Path.home()/'AppData/Roaming/Godot/app_userdata/机械制图学习'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
formal={p.name:sha(p) for p in user.glob('*.json') if not p.name.startswith('qa')}
assets={str(p.relative_to(APP)):sha(p) for p in (APP/'assets/examples').glob('*/*') if p.suffix in ['.glb','.json']}
if '--resume' in sys.argv:
    old=json.loads((APP/'qa/course-legacy-regression.json').read_text(encoding='utf8'))
    counts.update(old['checks']);RECORDS.extend(old['processes']);formal=old['formal_before']
try:
    for flag,extra,name in [
        ('--qa-points-beats',(),'points-beats-check.json'),
        ('--qa-points-beats-reopen',(),'points-beats-reopen.json'),
        ('--qa-line-learning',(),'line-learning-check.json'),
        ('--qa-line-reopen',(),'line-learning-reopen.json'),
        ('--qa-plane-lessons',(),'plane-normal.json'),
        ('--qa-plane-lessons',('--qa-plane-minimum',),'plane-minimum.json'),
        ('--qa-plane-reopen',(),'plane-reopen.json'),
        ('--qa-line-practice',('--qa-line-lessons',),'line-lessons-normal.json'),
        ('--qa-line-practice',('--qa-line-lessons','--qa-lessons-minimum'),'line-lessons-minimum.json')]:
        if name in counts:continue
        launch(flag,360,extra)
        log=(APP/'runtime/latest-run.log').read_text(encoding='utf8');(APP/'qa'/('course-legacy-'+name.replace('.json','.log'))).write_text(log,encoding='utf8')
        assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
        counts[name]=report(name,started);print(name,counts[name],flush=True)
    assert all(sha(APP/k)==v for k,v in assets.items()),'Original models changed'
finally:
    (APP/'qa/course-legacy-regression.json').write_text(json.dumps(dict(checks=counts,processes=RECORDS,assets=assets,formal_before=formal,formal_after={k:sha(user/k) for k in formal}),ensure_ascii=False,indent=2),encoding='utf8')
