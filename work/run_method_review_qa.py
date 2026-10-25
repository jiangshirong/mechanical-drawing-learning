"""Real render/input capture for prerequisite fixes; isolated saves and owned PIDs."""
import sys,time,json,hashlib
from pathlib import Path
from run_map_qa import APP,launch,RECORDS
started=time.time();suffix='minimum' if '--minimum' in sys.argv else 'normal'
user=Path.home()/'AppData/Roaming/Godot/app_userdata/机械制图学习'
def formal():return {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in user.glob('*.json') if not p.name.startswith('qa')}
before=formal()
try:
 launch('--qa-beginner',240,('--method-review',)+ (('--minimum',) if suffix=='minimum' else ()))
 log=(APP/'runtime/latest-run.log').read_text(encoding='utf8');(APP/f'qa/course-method-{suffix}.log').write_text(log,encoding='utf8')
 assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
 report=APP/f'qa/course-method-{suffix}.json';assert report.stat().st_mtime>=started
 data=json.loads(report.read_text(encoding='utf8'));bad=[c for c in data['checks'] if not c['passed']]
 print(json.dumps({'checks':len(data['checks']),'pictures':len(data['pictures']),'failures':bad},ensure_ascii=False),flush=True);assert not bad,bad
finally:
 (APP/f'qa/course-method-process-{suffix}.json').write_text(json.dumps(RECORDS,indent=2),encoding='utf8')
 after=formal();(APP/f'qa/course-method-formal-{suffix}.json').write_text(json.dumps({'before':before,'after':after,'unchanged':before==after},ensure_ascii=False,indent=2),encoding='utf8');assert before==after
