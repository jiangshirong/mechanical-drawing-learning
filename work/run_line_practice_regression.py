"""Sequential existing regressions: each runner uses separate saves/windows."""
import subprocess,sys,json,time
import run_map_qa as qa
for runner in ['run_points_beats_qa.py','run_point_naming_qa.py']:
 subprocess.run([sys.executable,str(qa.ROOT/'work'/runner)],cwd=qa.ROOT,check=True)
started=time.time()
try:
 qa.launch('--qa-guide-check',180)
 log=(qa.APP/'runtime/latest-run.log').read_text(encoding='utf-8');assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log[-5000:]
 print('guide',qa.report('guide-interaction-check.json',started),'passed',flush=True)
 qa.launch('--qa-guide-reopen',60)
 report=json.loads((qa.APP/'qa/guide-reopen.json').read_text(encoding='utf-8'))
 assert report['guide_hidden'] and report['free_mode'] and report['guide_step']=='rib_convention' and report['qa_window_offscreen'] and report['qa_no_focus'],report
 print('guide reopen passed',flush=True)
finally:
 (qa.APP/'qa/line-practice-guide-regression-process.json').write_text(json.dumps(qa.RECORDS,indent=2),encoding='utf-8')
