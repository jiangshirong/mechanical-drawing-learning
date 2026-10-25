"""Capture actual teaching flow; no system pointer, no production save writes."""
import json,time,sys,hashlib
from pathlib import Path
from run_map_qa import APP,launch,RECORDS
started=time.time();suffix='minimum' if '--minimum' in sys.argv else 'normal'
extra=['--minimum'] if suffix=='minimum' else []
if '--legacy-only' in sys.argv:extra.append('--legacy-only');suffix='legacy-'+suffix
user=Path.home()/'AppData/Roaming/Godot/app_userdata/机械制图学习'
def formal_saves():return {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in user.glob('*.json') if not p.name.startswith('qa')}
before=formal_saves()
try:
    launch('--qa-beginner',600,tuple(extra))
    log=(APP/'runtime/latest-run.log').read_text(encoding='utf8')
    (APP/f'qa/course-beginner-{suffix}.log').write_text(log,encoding='utf8')
    assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log[-4000:]
    path=APP/f'qa/course-beginner-{suffix}.json';assert path.stat().st_mtime>=started
    data=json.loads(path.read_text(encoding='utf8'));bad=[c for c in data['checks'] if not c['passed']]
    print(json.dumps({'checks':len(data['checks']),'pictures':len(data['pictures']),'failures':bad},ensure_ascii=False),flush=True)
    assert not bad
finally:
    (APP/f'qa/course-beginner-process-{suffix}.json').write_text(json.dumps(RECORDS,indent=2),encoding='utf8')
    after=formal_saves()
    (APP/f'qa/course-beginner-formal-{suffix}.json').write_text(json.dumps({'before':before,'after':after,'unchanged':before==after},ensure_ascii=False,indent=2),encoding='utf8')
    assert before==after,'Formal save files changed during the isolated visual review'
