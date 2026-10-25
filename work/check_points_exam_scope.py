"""Audit the chapter boundary; a metadata correction leaves every rendered beat unchanged."""
import json
import hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
path=root/'机械制图学习/模型/points_learning.json'
c=json.loads(path.read_text(encoding='utf-8'))
before=json.dumps({k:v for k,v in c.items() if k!='knowledge_scope'},ensure_ascii=False,sort_keys=True)
if 't02-q02' not in c['knowledge_scope']['line_questions_excluded']:
    c['knowledge_scope']['line_questions_excluded'].insert(1,'t02-q02')
c['knowledge_scope']['plane_questions_excluded']=[q for q in c['knowledge_scope']['plane_questions_excluded'] if q!='t02-q02']
after=json.dumps({k:v for k,v in c.items() if k!='knowledge_scope'},ensure_ascii=False,sort_keys=True)
assert before==after
index=json.loads((root/'学习资料/题集识别/题集索引.json').read_text(encoding='utf-8'))
line_ids=[q['id'] for q in index['questions'] if '直线' in q['task']]
assert set(line_ids)<=set(c['knowledge_scope']['line_questions_excluded'])
assert all(set(b['source_questions'])<=set(['t01-q01','t08-q01']) for g in c['concept'] for b in g['beats'])
path.write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
report={'rendered_content_unchanged':True,'rendered_content_sha256':hashlib.sha256(after.encode('utf-8')).hexdigest(),'every_straight_line_question_excluded':True,'straight_line_question_ids':line_ids,'source_after_metadata_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(root/'机械制图学习/qa/points-exam-scope-check.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
