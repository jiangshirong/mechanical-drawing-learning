"""Check continuous geometry through real lesson input, with isolated saves."""
import json,time
import run_map_qa as qa
started=time.time()
try:
    for extra in [('--qa-line-morph',),('--qa-line-morph','--qa-morph-minimum')]:
        qa.launch('--qa-line-learning',150,extra)
        log=(qa.APP/'runtime/latest-run.log').read_text(encoding='utf-8')
        assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
        count=qa.report('line-morph-check.json',started)
        suffix='minimum' if len(extra)>1 else 'normal'
        (qa.APP/('qa/line-morph-'+suffix+'.json')).write_text((qa.APP/'qa/line-morph-check.json').read_text(encoding='utf-8'),encoding='utf-8')
        print(suffix,count,'checks passed',flush=True)
finally:
    (qa.APP/'qa/line-morph-process-check.json').write_text(json.dumps(qa.RECORDS,indent=2),encoding='utf-8')
