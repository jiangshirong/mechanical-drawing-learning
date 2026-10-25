import json,time,hashlib,subprocess
from pathlib import Path
import run_map_qa as qa
started=time.time();counts={}
paths=[qa.APP/'main.gd',*qa.APP.glob('plane*.gd'),qa.APP/'模型/plane_learning.json',qa.APP/'模型/plane_questions.json']
def sha():return {str(p.relative_to(qa.APP)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
before=sha()
try:
 for flag,extras,report in [('--qa-plane-lessons',(),'plane-normal.json'),('--qa-plane-lessons',('--qa-plane-minimum',),'plane-minimum.json'),('--qa-plane-reopen',(),'plane-reopen.json'),('--qa-chapter-lessons',('--qa-navigation-dev',),'navigation-dev-normal.json'),('--qa-chapter-lessons',('--qa-lessons-minimum',),'chapter-lessons-minimum.json'),('--qa-line-practice',('--qa-line-lessons',),'line-lessons-normal.json')]:
  qa.launch(flag,240,extras)
  log=(qa.APP/'runtime/latest-run.log').read_text(encoding='utf-8')
  assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
  counts[report]=qa.report(report,started);print(report,counts[report],flush=True)
 assert before==sha(),'sources changed during final verification'
 old=json.loads((qa.APP/'qa/navigation-dev-delivery.json').read_text(encoding='utf-8'))['assets']
 assert all(hashlib.sha256((qa.APP/k).read_bytes()).hexdigest()==v for k,v in old.items()),'observation assets changed'
 (qa.APP/'qa/plane-lessons-delivery.json').write_text(json.dumps(dict(checks=counts,geometry_checks=306,processes=qa.RECORDS,source=sha(),assets=old,native_fullscreen_verified=False,system_mouse_moved=False,native_drag_feel_verified=False),ensure_ascii=False,indent=2),encoding='utf-8')
finally:
 (qa.APP/'qa/plane-final-process-check.json').write_text(json.dumps(qa.RECORDS,indent=2),encoding='utf-8')
