import json,time
from run_map_qa import APP,launch,report,RECORDS
started=time.time()
try:
    for suffix,extra in [('normal',()),('minimum',('--minimum',))]:
        launch('--qa-extra',180,extra)
        log=(APP/'runtime/latest-run.log').read_text(encoding='utf8')
        (APP/f'qa/course-extra-{suffix}.log').write_text(log,encoding='utf8')
        assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
        path=APP/f'qa/course-extra-{suffix}.json';assert path.stat().st_mtime>=started
        data=json.loads(path.read_text(encoding='utf8'));assert all(x['passed'] for x in data['checks']),[x for x in data['checks'] if not x['passed']]
        print(suffix,len(data['checks']),data['window_size'],data['viewport_size'],flush=True)
finally:(APP/'qa/course-extra-process.json').write_text(json.dumps(RECORDS,indent=2),encoding='utf8')
