"""Rendered acceptance in the real app with isolated logs, saves and internal input."""
import hashlib,json,subprocess,sys,time
from run_map_qa import APP,request_close

stage='before' if '--before' in sys.argv else 'after'
suffix='minimum' if '--minimum' in sys.argv else 'normal'
if stage=='before':
    baseline=APP.parent/'work/surface-lighting-baseline/course_space.gd'
    assert (APP/'course_space.gd').read_bytes()==baseline.read_bytes(),'Before images require the original renderer in an isolated project copy.'
files=[*APP.glob('assets/course_scenes/*.json'),*APP.glob('assets/examples/**/*.glb'),*APP.glob('assets/examples/**/data.json'),*APP.glob('模型/**/*.json')]
def hashes(): return {str(p.relative_to(APP)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
before=hashes();started=time.time()
records=[]
log_path=APP/f'qa/surface-lighting-{stage}-{suffix}.log'
try:
    extra=tuple(a for a in sys.argv[1:] if a in ('--before','--minimum'))
    # Same executable, project and QA flags as the launcher; a private log prevents
    # simultaneous QA in another chat from overwriting this run's evidence.
    with (APP/f'qa/surface-lighting-{stage}-{suffix}-stdout.log').open('w',encoding='utf8') as output:
        process=subprocess.Popen([str(APP/'runtime/godot.exe'),'--path',str(APP),'--audio-driver','Dummy','--position','-6000,-6000','--log-file',str(log_path),'--','--qa','--qa-surface-lighting',*extra],cwd=APP,stdout=output,stderr=output,creationflags=0x08000000)
        record={'owned_processes':[process.pid],'entry':'project main scene with launcher QA arguments','normal_exit':False}
        records.append(record)
        try:
            code=process.wait(timeout=180)
            record.update(normal_exit=code==0,exit_code=code,remaining=[])
            assert code==0,record
        except subprocess.TimeoutExpired:
            record['close_requested']=True;request_close(process.pid)
            try:process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill();process.wait();record['forced_cleanup']=[process.pid]
            record['remaining']=[]
            raise
    log=log_path.read_text(encoding='utf8')
    assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log,log[-5000:]
    path=APP/f'qa/surface-lighting-{stage}-{suffix}.json';assert path.stat().st_mtime>=started
    data=json.loads(path.read_text(encoding='utf8'));bad=[c for c in data['checks'] if not c['passed']]
    assert not bad,bad
    assert before==hashes(),'Model or lesson source changed during lighting QA'
    print(json.dumps({'stage':stage,'size':suffix,'checks':len(data['checks']),'images':len(data['screenshots']),'engine':data['engine'],'renderer':data['renderer']},ensure_ascii=False),flush=True)
finally:
    (APP/f'qa/surface-lighting-{stage}-{suffix}-process.json').write_text(json.dumps({'processes':records,'assets_unchanged':before==hashes(),'asset_hashes':before},ensure_ascii=False,indent=2),encoding='utf8')
