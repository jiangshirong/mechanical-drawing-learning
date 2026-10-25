"""Apply the latest concise point copy after any historical lesson author script."""
import json
from pathlib import Path
path = Path(__file__).resolve().parents[1] / '机械制图学习/模型/points_learning.json'
c = json.loads(path.read_text(encoding='utf-8'))
copy = {'solution': {'a-front:z': 'A 距 H 面 {A_z} mm。', 'a-front:x': 'A 距 W 面 {A_x} mm。', 'a-front:point': '标出a′。', 'a-top:depth': 'A 距 V 面 {A_y} mm。', 'a-top:point': '标出a。', 'a-top:erase': '擦去临时虚线。', 'a-side:transfer': '从 a 水平引线至 45°线。', 'a-side:turn': '过交点作竖线。', 'a-side:height': '过 a′ 作水平线。', 'a-side:point': '标出a″。', 'a-side:erase': '擦去临时虚线。', 'b-distance:x': 'B 在 A 左方 {dx} mm。', 'b-front:z': 'B 在 A 上方 {dz} mm。', 'b-front:point': '标出b′。', 'b-top:depth': 'B 在 A 后方 {dy} mm。', 'b-top:point': '标出b。', 'b-top:erase': '擦去临时虚线。', 'b-side:transfer': '从 b 水平引线至 45°线。', 'b-side:turn': '过交点作竖线。', 'b-side:height': '过 b′ 作水平线。', 'b-side:point': '标出b″。', 'b-side:erase': '擦去临时虚线。', 'check:complete': 'A、B 的三面投影完成。'}, 'concept': {'planes:H': 'H 是水平面。', 'planes:V': 'V 是正面。', 'planes:W': 'W 是侧面。', 'planes:A': 'A 在 H 面上方、V 面前方、W 面左方。', 'planes:X': 'V 与 H 的交线是 X 轴；展开后用它分开正面和水平投影。', 'planes:Y': 'H 与 W 的交线是 Y 轴。展开后分成向下的 Y_H 和向右的 Y_W。', 'planes:Z': 'V 与 W 的交线是 Z 轴，三条轴交于 O。', 'planes:names': '空间点用大写 A；水平、正面、侧面投影分别记作 a、a′、a″。', 'distances:coordinates': '左右、前后、高度，分别由距 W、V、H 的距离确定。', 'distances:H': '距 H 是高度：{A_z} mm。', 'distances:V': '距 V 表达前后：{A_y} mm。', 'distances:W': '距 W 表达左右：{A_x} mm。', 'feet:V': '向 V 面作垂线，垂足是 a′。', 'feet:V-keep': '正面投影反映左右和高度，不能反映前后。', 'feet:H': '向 H 面作垂线，垂足是 a。', 'feet:H-keep': '水平投影反映左右和前后。', 'feet:W': '向 W 面作垂线，垂足是 a″。', 'feet:W-keep': '侧面投影反映前后和高度。', 'unfold:V': '固定 V 面。', 'unfold:H': 'H 面绕 X 轴向下展开。', 'unfold:W': 'W 面绕 Z 轴向右展开。', 'unfold:distance': '展开只转动投影面，点到交线的垂直距离保持不变。', 'alignment:vertical': '正面、水平投影的左右位置相同，连线垂直 X。', 'alignment:height': '正面、侧面投影的高度相同，连线水平。', 'alignment:depth': 'a 到 X、a″ 到 Z 的距离，都等于 A 距 V 的距离。', 'alignment:given': '已知 a、a′，求 a″。', 'alignment:transfer': '从 a 水平引线至 45°线。', 'alignment:45-distance': '45°线上的点到两轴等距，可把前后距离转到侧面。', 'alignment:turn': '过交点作竖线。', 'alignment:level': '过 a′ 作水平线。', 'alignment:point': '交点就是 a″。', 'alignment:summary': '两个投影给出左右、前后和高度，可确定第三个投影。', 'relative:left': 'B 在 A 左方 {dx} mm。', 'relative:up': 'B 在 A 上方 {dz} mm。', 'relative:back': 'B 在 A 后方 {dy} mm。', 'relative:read': '从同名投影的间距，读出两点的相对位置。', 'relative8:given': '从 A 的同名投影量取相对距离，定位 B。', 'relative8:left': 'B 在 A 左方 20 mm。', 'relative8:up': 'B 在 A 上方 16 mm。', 'relative8:front': 'B 在 A 前方 18 mm。'}}
label_focus = {'planes:X': ['X'], 'planes:Y': ['Y'], 'planes:Z': ['Z', 'O'], 'planes:names': ['A', 'a', 'a′', 'a″']}

for kind in ['solution', 'concept']:
    for group in c[kind]:
        if kind == 'solution' and group['id'] == 'check':
            group['beats'] = [b for b in group['beats'] if b['id'] == 'check:complete']
        if kind == 'concept' and group['id'] == 'relative': group['title'] = '两点的相对位置'
        if kind == 'concept' and group['id'] == 'relative8': group['title'] = '从已知投影定位'
        for beat in group['beats']:
            if beat['id'] in copy[kind]: beat['text'] = copy[kind][beat['id']]
            if kind == 'concept' and beat['id'] in label_focus: beat['label_focus'] = label_focus[beat['id']]
        group['text'] = ''.join(b['text'] for b in group['beats'])
solution = {b['id']: b for g in c['solution'] for b in g['beats']}
for key, origin, target in [('b-distance:x', 'A_front', 'B_left_offset'), ('b-front:z', 'B_left_offset', 'B_front'), ('b-top:depth', 'A_top', 'B_back_offset')]:
    solution[key]['anchor'] = [origin, target]
    solution[key]['action'].update(measure_from=origin, measure_to=target)
c['construction_note'] = '先完成A的三个投影，再从A的投影量取B的相对距离；不显示坐标算式。临时作图线只在教学副本中绘制和擦除。'
relative = next(g for g in c['concept'] if g['id'] == 'relative')
front = next(b for g in c['concept'] for b in g['beats'] if b['id'] == 'relative8:front')
front['action'].update(to=['B.x', 'shift:A.y:-18', 'B.z'], show_point=True)
front['source_questions'] = ['t08-q01']
front['setup'] = dict(A=['A.x', 'A.y', 'A.z'], B=['B.x', 'A.y', 'B.z'], B_visible=True, unfolded=True)
read = next(b for b in relative['beats'] if b['id'] == 'relative:read')
read.update(scene='relative8', show_space=False, paper_extent=[760,760])
relative['beats'] = [b for b in relative['beats'] if b['id'] not in ['relative:read', 'relative8:front']] + [front, read]
for b in relative['beats']:
    if b['id'] in ['relative:left', 'relative:up', 'relative:read']: b['source_questions'] = ['t01-q01', 't08-q01']
relative['text'] = ''.join(b['text'] for b in relative['beats'])
c['concept'] = [g for g in c['concept'] if g['id'] != 'relative8']
c['knowledge_resume_aliases'] = {key: 'relative:left' for key in ['relative8', 'relative8:given', 'relative8:left', 'relative8:up']}
c['knowledge_scope']['examples'] = '知识按方法合并：左右与上下只演示一次，后方和前方分别演示。前方示意沿用原模型A/B的左右及高度，只以18毫米改变前后距离；原题20/16/18仍在来源事实中保留。不新增练习或评分。'
path.write_text(json.dumps(c, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
# Whole-exam integration: identify the solve-a-problem entry without adding a beat.
for g in c['concept']:
    for b in g['beats']:
        if b['id']=='alignment:given':b['callout_kind']='problem'
from review_legacy_concepts import revise
revise(c,'points')
path.write_text(json.dumps(c, ensure_ascii=False, indent=2)+'\n',encoding='utf-8')
