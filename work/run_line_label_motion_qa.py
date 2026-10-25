import json,time
import run_map_qa as qa
started=time.time()
try:
    for extra in [('--qa-label-motion',),('--qa-label-motion','--qa-label-minimum')]:
        qa.launch('--qa-line-learning',90,extra)
        log=(qa.APP/'runtime/latest-run.log').read_text(encoding='utf-8')
        assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
        count=qa.report('line-label-motion-check.json',started)
        suffix='minimum' if len(extra)>1 else 'normal'
        (qa.APP/('qa/line-label-motion-'+suffix+'.json')).write_text((qa.APP/'qa/line-label-motion-check.json').read_text(encoding='utf-8'),encoding='utf-8')
        print(suffix,count,'checks passed',flush=True)
finally:
    (qa.APP/'qa/line-label-motion-process-check.json').write_text(json.dumps(qa.RECORDS,indent=2),encoding='utf-8')
