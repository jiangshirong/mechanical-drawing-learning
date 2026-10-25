"""Freeze only captures actually opened for manual review."""
from pathlib import Path
import json,hashlib,shutil,datetime
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];QA=ROOT/'机械制图学习/qa';manifest=ROOT/'work/method_visual_manifest.json'
items=json.loads(manifest.read_text(encoding='utf8'));archive=QA/'method-reviewed';archive.mkdir(exist_ok=True);rows=[]
for item in items:
 p=QA/item.get('archive',item['file']);h=hashlib.sha256(p.read_bytes()).hexdigest();q=archive/(h[:12]+'-'+Path(item['file']).name)
 if not q.exists():shutil.copy2(p,q)
 assert hashlib.sha256(q.read_bytes()).hexdigest()==h
 rows.append(dict(item,archive=str(q.relative_to(QA)).replace('\\','/'),sha256=h,pixels=list(Image.open(q).size)))
manifest.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
record=dict(date=datetime.date.today().isoformat(),scope='方法前置、输入条件及推导的重点修订；其他章节的逐章判断另记内容报告。',reviewed=rows,
    findings_fixed=['H面垂足被文字覆盖：改用稳定顶部位置','投影虚线过暗：改为清晰的暖色虚线','逐面先投顶点后连边','球面给定前半球条件','空间等分先于投影等分','首次反向45°先求a','先求c再逐条平行线求b'],
    boundaries=dict(native_fullscreen_verified=False,system_mouse_moved=False,native_drag_feel_verified=False,learner_study_performed=False),
    note='自动截图数量不等于人工查看数量。诊断图标明superseded；最终图与拼版按实际查看分别归档。')
(QA/'course-method-visual-review.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
print(json.dumps({'reviewed':len(rows),'diagnostic':sum(r.get('superseded',False) for r in rows)},ensure_ascii=False))
