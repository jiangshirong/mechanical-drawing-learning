import json,time,sys,hashlib,subprocess
import run_map_qa as qa
started=time.time()
paths=[p for p in qa.APP.glob('*.gd')]+[qa.APP/'模型/line_practice.json',qa.APP/'模型/points_learning.json',qa.APP/'模型/line_learning.json']
sources={str(p.relative_to(qa.APP)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
try:
 for flag,extra,report in [(' --qa-line-practice'.strip(),(), 'line-practice-check-normal.json'),('--qa-line-practice',('--qa-line-practice-minimum',),'line-practice-check-minimum.json'),('--qa-line-practice-reopen',(),'line-practice-reopen.json')]:
  qa.launch(flag,240,extra)
  log=(qa.APP/'runtime/latest-run.log').read_text(encoding='utf-8')
  assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log[-8000:]
  print(report,qa.report(report,started),'passed',flush=True)
 assert sources=={str(p.relative_to(qa.APP)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},'Source changed during checks'
 subprocess.run([sys.executable,str(qa.ROOT/'work/check_line_practice_geometry.py')],check=True)
 (qa.APP/'qa/line-practice-source-check.json').write_text(json.dumps(sources,ensure_ascii=False,indent=2),encoding='utf-8')
finally:
 (qa.APP/'qa/line-practice-process-check.json').write_text(json.dumps(qa.RECORDS,indent=2),encoding='utf-8')
