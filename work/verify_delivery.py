from pathlib import Path
import json,hashlib,struct
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'学习资料/题集识别'
APP=ROOT/'机械制图学习'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
d=read(BASE/'题集索引.json');checks=[]
def check(name,passed,detail=None):checks.append({'check':name,'passed':bool(passed),'detail':detail})
check('source_hash',hashlib.sha256((BASE/d['source']['local_copy']).read_bytes()).hexdigest()==d['source']['sha256'])
check('43_pages_8_papers_69_questions',len(d['pages'])==43 and len(d['sets'])==8 and len(d['questions'])==69)
for p in d['pages']:
 check('cache_page_'+str(p['page']),all((BASE/p[k]).is_file() for k in ['page_image','text','positions','ocr']))
for q in d['questions']:
 check('trace_'+q['id'],q['total_points'] is not None and all((BASE/r['image']).is_file() and r['page'] in q['pages'] for r in q['regions']))
cat=read(APP/'assets/catalog.json')
for e in cat:
 data=read(APP/e['data'])
 check('source_'+e['id'],data['source']['pdf_sha256']==d['source']['sha256'] and (APP/data['source']['image']).is_file())
 check('editable_'+e['id'],(APP/'模型'/f"{e['id']}.blend").is_file())
 raw=(APP/e['model']).read_bytes()
 magic,ver,length=struct.unpack_from('<III',raw)
 check('glb_'+e['id'],magic==0x46546c67 and ver==2 and length==len(raw))
 glbjson=read(APP/e['data'])
 check('projection_identity_'+e['id'],all(abs(s['a'][0]-s['world_a'][0])<1e-5 and abs(s['a'][1]-s['world_a'][2])<1e-5 for s in data['views']['front']['segments']))
models=read(APP/'qa/saved-model-check.json')
for m in models:
 check('saved_geometry_'+m['id'],all(v is True for k,v in m.items() if isinstance(v,bool)) and all(c['passed'] for c in m.get('void_checks',[])) and all(v['open_edges']==0 or (m['id']=='plane' and v['name']=='ABCD' and v['open_edges']==4) for v in m['meshes']))
for n in range(1,9):check('exam_total_'+str(n),sum(q['total_points'] for q in d['questions'] if q['paper']==n)==(90 if n==7 else 100),sum(q['total_points'] for q in d['questions'] if q['paper']==n))
(APP/'qa/delivery-check.json').write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'checks':len(checks),'failed':[c for c in checks if not c['passed']]},ensure_ascii=False))
