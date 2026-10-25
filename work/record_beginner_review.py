"""Archive manually inspected captures without conflating capture and review counts."""
from pathlib import Path
import datetime,hashlib,json,shutil
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
QA=ROOT/'机械制图学习/qa'
manifest=json.loads((ROOT/'work/beginner_review_manifest.json').read_text(encoding='utf8'))
archive=QA/'beginner-reviewed';archive.mkdir(exist_ok=True)
rows=[]
for item in manifest:
    source=QA/item.get('archive',item['file'])
    digest=hashlib.sha256(source.read_bytes()).hexdigest()
    target=archive/(digest[:12]+'-'+Path(item['file']).name)
    if not target.exists():shutil.copy2(source,target)
    assert hashlib.sha256(target.read_bytes()).hexdigest()==digest
    with Image.open(target) as picture:dimensions=list(picture.size)
    rows.append(dict(item,archive=str(target.relative_to(QA)).replace('\\','/'),sha256=digest,pixels=dimensions))
record={
    'date':datetime.date.today().isoformat(),
    'method':'人工查看 Godot 实际截图；拼版只排列缩放原截图，关键步骤另展开原尺寸图。',
    'content_scope':'16章原413段逐段读文案和动作；当前403段。全部16章各节入口/结果查看实际截图拼版，关键步骤另展开原尺寸图。',
    'captures_reviewed':rows,
    'review_count':len(rows),
    'not_a_capture_count_claim':'自动截图数量不等于人工审查数量。所有被实际查看的图按哈希另存，随后自动重跑不覆盖这些证据。',
    'findings_fixed':['圆锥母线经过所选表面点','半剖真实移去四分之一并看清内部','相贯线先显示可见的真实公共点','螺纹使用理想螺旋牙形','轴承尺寸有对应轮廓及界线','清除旧读图高亮','纠错图线等待D构造','过渡段不提前圈出未来B点','点章节两处括号改量a到X及a″到Z的实际距离'],
    'boundaries':{'native_fullscreen_verified':False,'system_drag_feel_verified':False,'learner_study_performed':False,'system_mouse_moved':False,'manufacturing_cad_accuracy_claimed':False}
}
(QA/'course-beginner-visual-review.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
(ROOT/'work/beginner_review_manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'reviewed':len(rows),'original_resolution':sum(r['inspection']=='原尺寸截图' for r in rows)},ensure_ascii=False))
