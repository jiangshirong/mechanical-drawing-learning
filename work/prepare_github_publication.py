"""Prepare public source without changing the working editor configuration."""
from pathlib import Path
import shutil, json, re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'work/github-publication'
EXCLUDE_PARTS = {'.godot', '__pycache__', 'runtime', 'addons', 'course_deps',
                 'tools', 'course-backup-20261023', 'github-publication',
                 'surface-lighting-baseline'}
EXCLUDE_WORK = {'fix_godot_runtime.py', 'verify_godot_runtime.py',
                'archive_learning_package_reference.py', 'build_learning_design_package.py',
                'write_learning_package_docs.py'}

def allowed(p, base):
    rel = p.relative_to(base)
    if any(x in EXCLUDE_PARTS for x in rel.parts):
        return False
    if p.suffix in {'.pyc', '.log', '.import', '.blend1', '.exe', '.dll', '.pyd', '.ttc', '.ttf', '.otf'}:
        return False
    if 'qa' in rel.parts and p.suffix not in {'.gd', '.uid'}:
        return False
    if base.name == 'work' and (p.name in EXCLUDE_WORK or 'figma' in p.name.lower()):
        return False
    return True

def copy(p, relative):
    q = OUT / relative
    q.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(p, q)

if __name__ == '__main__':
    assert OUT.resolve().is_relative_to((ROOT / 'work').resolve())
    assert not OUT.exists(), 'Use a fresh destination, not an existing Git checkout.'
    OUT.mkdir()
    for folder in ['机械制图学习', '学习资料', 'work']:
        base = ROOT / folder
        for p in list(base.rglob('*')):
            if p.is_file() and allowed(p, base):
                copy(p, p.relative_to(ROOT))
    for folder in ['docs', 'tools']:
        for p in (ROOT / folder).rglob('*'):
            if p.is_file():
                copy(p, p.relative_to(ROOT))
    for name in ['README.md', 'README.en.md', '.gitignore', '.gitattributes',
                 'requirements-authoring.txt', '机械制图学习模型开发经验与迁移手册.md']:
        copy(ROOT / name, name)
    project = OUT / '机械制图学习/project.godot'
    s = project.read_text(encoding='utf8')
    for section in ['autoload', 'editor_plugins']:
        s = re.sub(r'(?ms)^\[' + section + r'\]\s*.*?(?=^\[|\Z)', '', s)
    project.write_text(s, encoding='utf8')
    (OUT / '机械制图学习/qa').mkdir(exist_ok=True)
    (OUT / '机械制图学习/qa/.gitkeep').write_text('', encoding='utf8')
    (OUT / '机械制图学习/assets/fonts').mkdir(exist_ok=True)
    (OUT / '机械制图学习/assets/fonts/README.md').write_text(
        'System fonts are not distributed. Run tools/prepare_windows.ps1 at the repository root.\n', encoding='utf8')
    original = json.loads((ROOT / '机械制图学习/qa/course-final-integrity.json').read_text(encoding='utf8'))
    report = {'date': '2026-10-25', 'source_validation': {
        k: original[k] for k in ['formal_saves_unchanged', 'original_models_unchanged',
        'production_changed_after_final_run', 'content_review', 'boundaries']},
        'publication_changes': [
            'Local Godot AI autoload/editor plugin disabled in the public project only.',
            'Engines, system font, caches, installers, personal saves and QA images/logs excluded.',
            'Six actual application screenshots copied unchanged for both READMEs.'],
        'public_snapshot_smoke_test': 'pending'}
    (OUT / 'docs/verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    (OUT / 'docs/verification.md').write_text('''# 验证摘要 / Verification summary

原始工作构建已完成16章内容审查、几何与表达核对、正常/1060×720窗口内部操作、自然动画中间态人工查看、恢复/取消/退出及作者源可复现性检查。当前420个讲解小段，65个题目入口、61个去重任务。

The working build was checked for lesson content, geometry and drawing conventions, normal/minimum-window behavior, natural animation intermediate states, restoration/cancellation, and deterministic authoring. It contains 420 explanation beats and 65 entries for 61 distinct tasks.

- 正式存档未改、原始7例GLB/data未改；测试进程正常退出。
- Formal saves and original model assets were unchanged; owned test processes exited normally.
- 公开版只关闭本机AI编辑器集成；课程与几何资产沿用已核验构建。
- The public snapshot disables only the local AI editor integration and retains verified lesson and geometry data.
- 不宣称原生全屏、系统鼠标拖选手感、加工级CAD精度或真实学习效果通过。
- Native fullscreen, system text-selection feel, manufacturing CAD precision and learner outcomes are not claimed as verified.

See `verification.json` for public-snapshot smoke tests. Historical local QA artifacts are not all distributed. Generate new outputs with isolated saves:

```powershell
python work/check_exam_course.py
python work/check_method_derivations.py
python work/run_method_review_qa.py
python work/run_method_review_qa.py --minimum
python work/run_course_final_qa.py
```

Tests use offscreen windows and internal Godot input. Do not move the system mouse or reuse student save files.
''', encoding='utf8')
    files = [p for p in OUT.rglob('*') if p.is_file()]
    print(json.dumps({'directory': str(OUT), 'files': len(files),
                      'bytes': sum(p.stat().st_size for p in files),
                      'large_files': [str(p.relative_to(OUT)) for p in files if p.stat().st_size > 50_000_000]}, ensure_ascii=False))
