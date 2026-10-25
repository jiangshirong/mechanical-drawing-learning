import json,time,subprocess
from run_map_qa import APP,launch,report,RECORDS
started=time.time()
try:
    with (APP/'qa/course-state-import.log').open('w',encoding='utf8') as log:
        p=subprocess.Popen([str(APP/'runtime/godot.exe'),'--headless','--editor','--path',str(APP),'--import','--quit'],stdout=log,stderr=log,creationflags=0x08000000)
        code=p.wait(timeout=60);RECORDS.append({'flag':'import','owned_processes':[p.pid],'normal_exit':code==0,'remaining':[]})
    log=(APP/'qa/course-state-import.log').read_text(encoding='utf8');assert code==0 and 'SCRIPT ERROR' not in log,log
    for stage in ['write','reopen']:
        launch('--qa-course',timeout=180,extra=('--state-'+stage,))
        log=(APP/'runtime/latest-run.log').read_text(encoding='utf8');(APP/f'qa/course-state-{stage}.log').write_text(log,encoding='utf8')
        assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log
        print(stage,report('course-state-'+stage+'.json',started),flush=True)
finally:(APP/'qa/course-state-process.json').write_text(json.dumps(RECORDS,indent=2),encoding='utf8')
