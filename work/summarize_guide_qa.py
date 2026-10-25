import json
from pathlib import Path
APP=Path(__file__).resolve().parents[1]/'机械制图学习'
def read(name):return json.loads((APP/'qa'/name).read_text(encoding='utf-8'))
def tally(name):
    items=read(name)
    assert all(c['passed'] for c in items),name
    return {'total':len(items),'passed':sum(c['passed'] for c in items)}
report=read('最终核验.json')
guide={
    'interaction_and_regression':tally('guide-interaction-check.json'),
    'saved_geometry_and_asset_versions':tally('guide-model-check.json'),
    'reopen':read('guide-reopen.json'),
    'test_processes':read('guide-process-check.json'),
    'system_cursor_calls':0,
}
for row in guide['test_processes']:assert row['normal_exit'] and not row['remaining']
assert guide['reopen']['free_mode'] and guide['reopen']['guide_hidden']
assert guide['reopen']['qa_no_focus'] and guide['reopen']['qa_window_offscreen']
for folder in [APP,APP.parent/'work']:
    for p in folder.rglob('*'):
        if p.suffix not in ['.gd','.py','.ps1']:continue
        if p.resolve()==Path(__file__).resolve():continue
        text=p.read_text(encoding='utf-8-sig')
        assert not any(term in text for term in ['warp_mouse','SetCursorPos','SendInput','pyautogui']),str(p)
report['guide']=guide
report['section_geometry']=tally('section-saved-check.json')
report['delivery']=tally('delivery-check.json')
(APP/'qa/最终核验.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in guide.items() if k not in ['test_processes','reopen']},ensure_ascii=False))
