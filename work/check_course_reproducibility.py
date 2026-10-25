"""Rebuild author outputs and prove identical content, separately from QA."""
from pathlib import Path
import hashlib,json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1];APP=ROOT/'机械制图学习'
def snapshot():
    files=[*APP.glob('模型/course/*.json'),APP/'模型/course_registry.json',APP/'模型/course_coverage.json',APP/'模型/course_source_audit.json',APP/'assets/knowledge_map.json',*APP.glob('assets/course_scenes/*.json'),*APP.glob('assets/course_sources/*.png')]
    return {str(p.relative_to(APP)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
before=snapshot();started=time.time()
with (APP/'qa/course-rebuild.log').open('w',encoding='utf8') as log:
    subprocess.run([sys.executable,str(ROOT/'work/build_exam_course.py')],cwd=ROOT,stdout=log,stderr=log,creationflags=0x08000000,check=True)
after=snapshot();differences=[k for k in before.keys()|after.keys() if before.get(k)!=after.get(k)]
(APP/'qa/course-reproducibility.json').write_text(json.dumps({'started':started,'finished':time.time(),'matches':not differences,'differences':differences,'outputs':after},ensure_ascii=False,indent=2),encoding='utf8')
assert not differences,differences
print('Reproducible outputs:',len(after))
