"""Record final evidence, production hashes and exact test-process cleanup."""
import hashlib,json,subprocess,sys
from pathlib import Path
import run_map_qa as qa

def read(path):return json.loads((qa.APP/path).read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def count(path):
    rows=read('qa/'+path)
    assert rows and all(row['passed'] for row in rows),path
    return len(rows)

lesson=read('模型/line_learning.json')
beats=[b for group in lesson['concept'] for b in group['beats']]
assert len(lesson['concept'])==6 and len(beats)==50
assert len([b for b in beats if b.get('callout_kind')=='problem'])==6
assert len(lesson['knowledge_scope']['direct_questions'])==9
assert not any(b['id'].startswith('point_on_line:V-') for b in beats)
assert 'distance_V' in lesson['scenes']
ids={b['id'] for b in beats}
assert all(value in ids for value in lesson['knowledge_resume_aliases'].values())
full=read('qa/line-learning-process-check.json')
assert full['source_before']==full['source_after']
# The final rotation harness chooses an exposed model region. Its edit does
# not change any production source or the full traversal's action checks.
production={name:value for name,value in full['source_after'].items() if not name.endswith('_check.gd')}
assert production=={name:sha(qa.APP/name) for name in production}
assets=full['assets']
assert assets=={name:sha(qa.APP/name) for name in assets}
baseline=read('qa/line-connect-delivery.json')
assert assets==baseline['assets']
processes=[]
for report in ['line-problem-cards-process-check.json','line-learning-process-check.json','lesson-refine-process-check.json']:
    data=read('qa/'+report)
    processes.extend(data['processes'] if isinstance(data,dict) else data)
assert len(processes)==6 and all(row['normal_exit'] and not row['remaining'] for row in processes)
owned={pid for row in processes for pid in row['owned_processes']}
assert not [row for row in qa.snapshot() if row['ProcessId'] in owned]
source_path=qa.ROOT/'work/build_line_learning.py'
source_hash=sha(source_path)
data_hash=sha(qa.APP/'模型/line_learning.json')
subprocess.run(['python',str(source_path)],cwd=qa.ROOT,check=True)
assert data_hash==sha(qa.APP/'模型/line_learning.json')
report=dict(groups=6,beats=50,problem_entries=[b['id'] for b in beats if b.get('callout_kind')=='problem'],
    checks=dict(line=count('line-learning-check.json'),reopen=count('line-learning-reopen.json'),
                cards_normal=count('line-problem-cards-normal.json'),cards_minimum=count('line-problem-cards-minimum.json'),
                regression_normal=count('lesson-refine-normal.json'),regression_minimum=count('lesson-refine-minimum.json')),
    processes=processes,production_source=production,author_source=source_hash,
    qa_source=sha(qa.APP/'line_learning_check.gd'),assets=assets,
    observations=dict(isolated_saves=True,viewport_input_only=True,system_mouse_moved=False,
                      native_fullscreen_verified=False,native_drag_feel_verified=False,
                      screenshot_phases=['before','moving','result'],window_sizes=['normal','1060x720']))
sync_mode='--sync' in sys.argv
conditions_mode='--conditions' in sys.argv
report['observations']['preparation_timing']='with_question_typing' if sync_mode or conditions_mode else 'after_next_input'
if conditions_mode:
    report['observations']['condition_rows']=dict(fill='94b2ca',border='688fa8',native_selectable_text=True)
filename='line-problem-conditions-delivery.json' if conditions_mode else ('line-problem-sync-delivery.json' if sync_mode else 'line-problem-cards-delivery.json')
(qa.APP/'qa'/filename).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(groups=6,beats=50,checks=report['checks'],test_processes_exited=len(processes),production_and_assets_match=True),ensure_ascii=False))
