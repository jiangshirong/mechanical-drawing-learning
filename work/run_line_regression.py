"""Regression of the final source, with normal-exit process ownership."""
import hashlib,json,subprocess,sys,time
from pathlib import Path
import run_map_qa as qa
started=time.time()
names=['main.gd','practice_board.gd','line_presentation.gd','line_geometry.gd','line_paper.gd','line_callout.gd','模型/line_learning.json','points_presentation.gd','points_callout.gd','points_concept.gd','模型/points_learning.json']
def sha(name):return hashlib.sha256((qa.APP/name).read_bytes()).hexdigest()
source={name:sha(name) for name in names}
try:
    subprocess.run([sys.executable,str(Path(__file__).with_name('run_points_beats_qa.py'))],check=True,timeout=420)
    qa.launch('--qa-guide-check',180,extra=('--qa-guide-only',))
    log=(qa.APP/'runtime/latest-run.log').read_text(encoding='utf-8')
    (qa.APP/'qa/line-guide-regression.log').write_text(log,encoding='utf-8')
    assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
    print(json.dumps({'guide_checks':qa.report('guide-interaction-check.json',started)},ensure_ascii=False),flush=True)
    qa.launch('--qa-guide-reopen',40)
    reopened=json.loads((qa.APP/'qa/guide-reopen.json').read_text(encoding='utf-8'))
    assert reopened['free_mode'] and reopened['guide_hidden'] and reopened['id']=='section' and reopened['guide_step']=='rib_convention',reopened
    assert reopened['qa_window_offscreen'] and reopened['qa_no_focus'],reopened
    assert source=={name:sha(name) for name in names},'Source changed during regression'
    print(json.dumps({'guide_reopen':reopened,'source_stable':True,'processes':qa.RECORDS},ensure_ascii=False),flush=True)
finally:
    (qa.APP/'qa/line-regression-process-check.json').write_text(json.dumps(dict(source_before=source,source_after={name:sha(name) for name in names},processes=qa.RECORDS),ensure_ascii=False,indent=2),encoding='utf-8')
