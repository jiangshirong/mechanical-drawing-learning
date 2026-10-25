"""Close the current delivery ledger without launching or terminating applications."""
from pathlib import Path
import hashlib,json
from run_map_qa import snapshot

ROOT=Path(__file__).resolve().parents[1];APP=ROOT/'机械制图学习';QA=APP/'qa'
def load(p):return json.loads(p.read_text(encoding='utf8'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
delivery=load(QA/'course-delivery.json');run=load(QA/'course-final-run.json')
assert run['unchanged'] and len(run['completed'])==6
changed=[k for k,v in run['source_after'].items() if sha(APP/k)!=v]
if changed:
 followup=load(QA/'course-points-brace-followup.json')
 assert followup['full_run_sha256']==sha(QA/'course-final-run.json')
 assert set(changed)==set(followup['source_changes_from_full_run']),changed
 assert all(sha(APP/k)==v for k,v in followup['source_changes_from_full_run'].items())
assert delivery['counts']['chapters']==16
assert delivery['formal_saves_unchanged'] and delivery['original_models_unchanged']
assert all(load(QA/f'course-beginner-formal-{s}.json')['unchanged'] for s in ['normal','minimum'])
owned={p for record in delivery['processes'] for p in record['owned_processes']}
live=[p for p in snapshot() if p['ProcessId'] in owned]
assert not live,live
visual=load(QA/'course-beginner-visual-review.json')
assert all(sha(QA/r['archive'])==r['sha256'] for r in visual['captures_reviewed'])
method_visual=load(QA/'course-method-visual-review.json')
assert all(sha(QA/r['archive'])==r['sha256'] for r in method_visual['reviewed'])
assert all(load(QA/f'course-method-formal-{s}.json')['unchanged'] for s in ['normal','minimum'])
record={
 'registered_processes':len(owned),'remaining_registered_processes':live,
 'production_changed_after_final_run':changed,'formal_saves_unchanged':True,
 'production_changes_verified_by':'qa/course-points-brace-followup.json' if changed else 'qa/course-final-run.json',
 'original_models_unchanged':True,'delivery_sha256':sha(QA/'course-delivery.json'),
 'reviewed_capture_archives':len(visual['captures_reviewed']),
 'method_reviewed_capture_archives':len(method_visual['reviewed']),
 'content_review':'16 chapters; current '+str(delivery['counts']['concept_beats'])+' beats',
 'boundaries':visual['boundaries']
}
(QA/'course-final-integrity.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps(record,ensure_ascii=False))
