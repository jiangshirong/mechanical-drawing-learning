import json,time
import run_map_qa as qa
started=time.time()
try:
    for suffix,extra in [('normal',()),('minimum',('--qa-lessons-minimum',))]:
        qa.launch('--qa-chapter-lessons',120,('--qa-navigation-dev',*extra))
        log=(qa.APP/'runtime/latest-run.log').read_text(encoding='utf-8')
        assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
        print(suffix,qa.report('navigation-dev-'+suffix+'.json',started),'passed',flush=True)
finally:
    (qa.APP/'qa/navigation-dev-process-check.json').write_text(json.dumps(qa.RECORDS,indent=2),encoding='utf-8')
