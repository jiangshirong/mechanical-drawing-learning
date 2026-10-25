import json,hashlib,subprocess,sys
from pathlib import Path
import run_map_qa as qa
def read(name):return json.loads((qa.APP/'qa'/name).read_text(encoding='utf-8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def count(name):
 rows=read(name);assert rows and all(r['passed'] for r in rows),name
 return len(rows)
source=read('line-practice-source-check.json')
assert source=={name:sha(qa.APP/name) for name in source}
assets=read('line-learning-process-check.json')['assets']
assert assets=={name:sha(qa.APP/name) for name in assets}
assert assets==read('line-problem-conditions-delivery.json')['assets']
processes=[]
for name in ['line-practice-process-check.json','line-learning-process-check.json','points-beats-process-check.json','point-naming-process.json','line-practice-guide-regression-process.json']:
 rows=read(name);processes.extend(rows['processes'] if isinstance(rows,dict) else rows)
assert len(processes)==11 and all(p['normal_exit'] and not p['remaining'] for p in processes)
owned={i for p in processes for i in p['owned_processes']}
assert not any(r['ProcessId'] in owned for r in qa.snapshot())
lesson=qa.APP/'模型/line_practice.json';digest=sha(lesson)
subprocess.run([sys.executable,str(qa.ROOT/'work/build_line_practice.py')],cwd=qa.ROOT,check=True)
assert sha(lesson)==digest
report=dict(tasks=7,beats=95,checks={n:count(n) for n in ['line-practice-check-normal.json','line-practice-check-minimum.json','line-practice-reopen.json','line-practice-geometry.json','line-learning-check.json','line-learning-reopen.json','points-beats-check.json','points-beats-reopen.json','point-naming-check.json','point-naming-reopen.json','guide-interaction-check.json']},processes=processes,assets=assets,production_source=source,author_source=sha(qa.ROOT/'work/build_line_practice.py'),guide_reopen=read('guide-reopen.json'),isolated_saves=True,viewport_input_only=True,system_mouse_moved=False,native_fullscreen_verified=False,native_drag_feel_verified=False)
(qa.APP/'qa/line-practice-delivery.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(tasks=7,beats=95,checks=report['checks'],test_processes_exited=11,model_assets_unchanged=True),ensure_ascii=False))
