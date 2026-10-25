"""Final verification, serial app instances, immutable production sources."""
from pathlib import Path
import hashlib,json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1];APP=ROOT/'机械制图学习'
def digest():
    files=[*APP.glob('*.gd'),*APP.glob('*.gdshader'),APP/'project.godot',APP/'开始学习.cmd',*APP.glob('模型/**/*.json'),*APP.glob('assets/course_scenes/*.json'),APP/'assets/knowledge_map.json']
    return {str(p.relative_to(APP)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
before=digest();started=time.time();completed=[]
legacy_args=[]
legacy_reuse=None
if '--reuse-legacy' in sys.argv:
    prior=json.loads((APP/'qa/course-final-run.json').read_text(encoding='utf8'))
    changes=[k for k in before.keys()|prior['source_after'].keys() if before.get(k)!=prior['source_after'].get(k)]
    allowed={'assets/course_scenes/'+name+'.json' for name in ['fastener_bolt','fastener_stud','fastener_stud_task','fastener_bolt_error']}
    assert prior['unchanged'] and len(prior['completed'])==6
    assert {k.replace('\\','/') for k in changes}<=allowed,changes
    legacy_args=['--resume']
    legacy_reuse={'previous_finished':prior['finished'],'only_changed_sources':changes,'reason':'Only four new fastener scene layouts changed; existing point/line/plane source and runtime remain identical.'}
try:
    for script,args in [('check_exam_course.py',[]),('run_course_legacy_qa.py',legacy_args),('run_course_qa.py',[]),('run_course_qa.py',['--minimum']),('run_course_state_qa.py',[]),('run_course_visual_qa.py',[])]:
        subprocess.run([sys.executable,str(ROOT/'work'/script),*args],cwd=ROOT,check=True,creationflags=0x08000000)
        completed.append({'script':script,'args':args});print('Completed',script,*args,flush=True)
    assert before==digest(),'Production source changed during final verification'
finally:
    (APP/'qa/course-final-run.json').write_text(json.dumps(dict(started=started,finished=time.time(),completed=completed,source_before=before,source_after=digest(),unchanged=before==digest(),legacy_reuse=legacy_reuse),ensure_ascii=False,indent=2),encoding='utf8')
