"""Focused follow-up after manual review found two wrong distance-brace endpoints."""
from pathlib import Path
import hashlib,json,time
from run_map_qa import APP,launch,report,RECORDS

ROOT=APP.parent;QA=APP/'qa';started=time.time()
def load(p):return json.loads(p.read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
full=load(QA/'course-final-run.json');assert full['unchanged'] and len(full['completed'])==6
changes={k:sha(APP/k) for k,v in full['source_after'].items() if sha(APP/k)!=v}
allowed={'模型/points_learning.json','模型/course_authoring_records.json','points_beats_check.gd'}
assert {k.replace('\\','/') for k in changes}==allowed,changes
before=load(ROOT/'work/points-before-brace-followup.json');after=load(APP/'模型/points_learning.json')
def beats(c):return {b['id']:b for g in c['concept'] for b in g['beats']}
old,new=beats(before),beats(after)
assert old.keys()==new.keys()
assert {id for id in old if old[id]!=new[id]}=={'unfold:distance','alignment:depth'}
assert before['solution']==after['solution']
user=Path.home()/'AppData/Roaming/Godot/app_userdata/机械制图学习'
def formal():return {p.name:sha(p) for p in user.glob('*.json') if not p.name.startswith('qa')}
formal_before=formal();checks={}
try:
 for flag,name in [('--qa-points-beats','points-beats-check.json'),('--qa-points-beats-reopen','points-beats-reopen.json')]:
  launch(flag,360)
  log=(APP/'runtime/latest-run.log').read_text(encoding='utf8')
  (QA/('points-brace-'+name.replace('.json','.log'))).write_text(log,encoding='utf8')
  assert 'SCRIPT ERROR' not in log and 'ERROR:' not in log
  checks[name]=report(name,started);print(name,checks[name],flush=True)
 assert all(sha(APP/k)==v for k,v in changes.items())
 assert all(sha(APP/k)==v for k,v in full['source_after'].items() if k not in changes)
 assert formal_before==formal()
finally:
 record=dict(reason='人工复看发现两处括号连接了错误端点；只重跑受影响的点章节，其他章节使用源码未变的完整回归。',
  full_run_sha256=sha(QA/'course-final-run.json'),source_changes_from_full_run=changes,changed_beats=['unfold:distance','alignment:depth'],
  checks=checks,processes=RECORDS,formal_before=formal_before,formal_after=formal(),started=started,finished=time.time())
 (QA/'course-points-brace-followup.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
