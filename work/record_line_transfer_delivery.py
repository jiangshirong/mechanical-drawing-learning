"""Record fresh, scoped evidence for the continuous third-projection animation."""
import hashlib, json, subprocess, sys
import run_map_qa as qa

def read(name):
    return json.loads((qa.APP / 'qa' / name).read_text(encoding='utf-8'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def count(name):
    rows = read(name)
    assert rows and all(row['passed'] for row in rows), name
    return len(rows)

source = read('line-practice-source-check.json')
source.pop('line_learning_check.gd') # Timing QA was updated after the practice run; runtime files are unchanged.
assert source == {name: sha(qa.APP / name) for name in source}
previous = read('line-practice-delivery.json')['production_source']
for name in previous:
    if name.startswith('points_') or name in ['practice_canvas.gd', 'practice_board.gd', '模型/points_learning.json']:
        assert sha(qa.APP / name) == previous[name], name
assets = read('line-learning-process-check.json')['assets']
assert assets == {name: sha(qa.APP / name) for name in assets}
assert assets == read('line-practice-delivery.json')['assets']
processes = []
for name in ['line-practice-process-check.json', 'line-learning-process-check.json', 'line-side-projection-process-check.json']:
    rows = read(name)
    processes.extend(rows['processes'] if isinstance(rows, dict) else rows)
assert len(processes) == 7 and all(p['normal_exit'] and not p['remaining'] for p in processes)
owned = {pid for p in processes for pid in p['owned_processes']}
assert not any(p['ProcessId'] in owned for p in qa.snapshot())
for stem in ['line_practice', 'line_learning']:
    path = qa.APP / '模型' / (stem + '.json')
    digest = sha(path)
    subprocess.run([sys.executable, str(qa.ROOT / 'work' / ('build_' + stem + '.py'))], cwd=qa.ROOT, check=True)
    assert sha(path) == digest
practice = json.loads((qa.APP / '模型/line_practice.json').read_text(encoding='utf-8'))
beats = [b for t in practice['tasks'] for g in t['groups'] for b in g['beats']]
assert len(beats) == 71 and sum(b['action']['type'] == 'side_point' for b in beats) == 6
report = dict(teaching_beats=71, knowledge_beats=50, composite_transfers=6,
    checks={name: count(name) for name in ['line-practice-check-normal.json', 'line-practice-check-minimum.json', 'line-practice-reopen.json', 'line-practice-geometry.json', 'line-learning-check.json', 'line-learning-reopen.json', 'line-side-projection-normal.json', 'line-side-projection-minimum.json']},
    source=source, assets=assets, processes=processes,
    authors={name: sha(qa.ROOT / 'work' / name) for name in ['build_line_practice.py', 'build_line_learning.py']},
    transfer_qa_source=sha(qa.APP / 'line_learning_check.gd'),
    viewport_input_only=True, offscreen_no_focus=True, native_fullscreen_verified=False)
(qa.APP / 'qa/line-transfer-delivery.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(dict(checks=report['checks'], processes_exited=len(processes)), ensure_ascii=False))
