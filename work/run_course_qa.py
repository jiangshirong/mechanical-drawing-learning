import json,subprocess,time,sys
from run_map_qa import APP,launch,report,RECORDS

def main():
    started=time.time()
    try:
        with (APP/'qa/course-import.log').open('w',encoding='utf8') as log:
            p=subprocess.Popen([str(APP/'runtime/godot.exe'),'--headless','--editor','--path',str(APP),'--import','--quit'],stdout=log,stderr=log,creationflags=0x08000000)
            code=p.wait(timeout=55);RECORDS.append(dict(flag='import',owned_processes=[p.pid],normal_exit=code==0,remaining=[]))
        text=(APP/'qa/course-import.log').read_text(encoding='utf8')
        assert code==0 and 'SCRIPT ERROR' not in text,text[-5000:]
        extras=tuple(x for x in ['--minimum','--smoke'] if x in sys.argv)
        launch('--qa-course',timeout=600,extra=extras)
        print('Checks:',report('course-check-'+('minimum' if '--minimum' in sys.argv else 'normal')+'.json',started))
    finally:
        (APP/'qa/course-process.json').write_text(json.dumps(RECORDS,indent=2),encoding='utf8')
        (APP/('qa/course-process-'+('minimum' if '--minimum' in sys.argv else 'normal')+'.json')).write_text(json.dumps(RECORDS,indent=2),encoding='utf8')
if __name__=='__main__':main()
