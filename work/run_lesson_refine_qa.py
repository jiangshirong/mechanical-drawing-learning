import json,time
import run_map_qa as qa
started=time.time()
try:
    for extra in [('--qa-refine-only',),('--qa-refine-only','--qa-refine-minimum')]:
        qa.launch('--qa-line-learning',90,extra)
        log=(qa.APP/'runtime/latest-run.log').read_text(encoding='utf-8')
        assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
        count=qa.report('lesson-refine-check.json',started)
        suffix='minimum' if len(extra)>1 else 'normal'
        (qa.APP/('qa/lesson-refine-'+suffix+'.json')).write_text((qa.APP/'qa/lesson-refine-check.json').read_text(encoding='utf-8'),encoding='utf-8')
        print(suffix,count,'checks passed',flush=True)
finally:
    (qa.APP/'qa/lesson-refine-process-check.json').write_text(json.dumps(qa.RECORDS,indent=2),encoding='utf-8')
