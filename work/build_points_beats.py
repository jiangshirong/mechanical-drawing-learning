"""Author the lesson source; geometry references are resolved from the model at runtime."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / '机械制图学习/模型/points_learning.json'
config = json.loads(path.read_text(encoding='utf-8'))
if config.get('schema_version', 1) >= 2:
    raise SystemExit('Version 2 already exists; edit the lesson source directly. This initial migration will not overwrite it.')
config['schema_version'] = 2
config['presentation'] = {'characters_per_second': 16, 'punctuation_pause': 0.18}

def beat(group, suffix, text, action, cue, refs, **extra):
    return dict(id=f'{group}:{suffix}', text=text, action=action,
                anchor=refs, indicators=[cue], focus=refs, **extra)

concept = []
def c(group, suffix, text, type='focus', plane='', cue='highlight', refs=None):
    concept.append(beat(group,suffix,text,dict(type=type,plane=plane),cue,refs or [plane]))

for p, name in [('H','水平面'),('V','正面'),('W','侧面')]:
    c('planes',p,f'{p} 是{name}。',plane=p)
c('planes','A','A 在 H 面上方、V 面前方、W 面左方。',refs=['A'])
for p, t in [('H','距 H 是高度：{A_z} mm。'),('V','距 V 表达前后：{A_y} mm。'),('W','距 W 表达左右：{A_x} mm。')]:
    c('distances',p,t,'ray',p,'brace',['A','foot_'+p])
for p,n,t in [('V','a′','保留左右和高度；前后距离不直接显示。'),('H','a','保留左右和前后；高度不直接显示。'),('W','a″','保留前后和高度；左右距离不直接显示。')]:
    c('feet',p,'向 '+p+' 面作垂线，垂足是 '+n+'。','foot',p,'arrow',['A','foot_'+p])
    c('feet',p+'-keep',n+' '+t,plane=p,refs=['foot_'+p,p])
c('unfold','V','固定 V 面。',plane='V')
c('unfold','H','H 面绕 X 轴向下展开。','unfold','H','arc',['H'])
c('unfold','W','W 面绕 Z 轴向右展开。','unfold','W','arc',['W'])
c('unfold','distance','展开不改变投影点到坐标轴的距离。',refs=['H_origin','foot_H','W_origin','foot_W'],cue='equal')
for suffix,text,cue,refs in [
    ('vertical','a 与 a′ 左右对正。','arrow',['A_top','A_front']),
    ('height','a′ 与 a″ 高度相等。','arrow',['A_front','A_left']),
    ('depth','a 与 a″ 的前后距离相等。','equal',['A_depth0','A_top_axis','O','A_side_axis']),
    ('transfer','沿水平线把距离送到 45°线。','arrow',['A_top','A_turn']),
    ('turn','从 45°交点向上，转成向右的同样距离。','arrow',['A_turn','A_left']),
    ('summary','三组对应关系共同确定三个投影的位置。','highlight',['A_front','A_top','A_left'])]:
    b=beat('alignment',suffix,text,{'type':'focus'},cue,refs,show_sheet=True)
    concept.append(b)

for g in config['concept']:
    g['beats']=[b for b in concept if b['id'].split(':')[0]==g['id']]

solution=[]
def s(group,suffix,text,type='focus',refs=None,cue='arrow',**extra):
    solution.append(beat(group,suffix,text,dict(type=type,**extra),cue,refs or ['O']))

for suffix,text,refs in [
    ('A-z','A 距 H：高度 {A_z} mm。',['O','A_height']),
    ('A-y','A 距 V：前后距离 {A_y} mm。',['O','A_top_axis']),
    ('A-x','A 距 W：左右距离 {A_x} mm。',['O','A_x']),
    ('B-x','B 在 A 左方 {dx} mm。',['A_x','B_x']),
    ('B-y','B 在 A 后方 {dy} mm，即更靠近 V 面。',['A_top_axis','B_top_axis']),
    ('B-z','B 在 A 上方 {dz} mm。',['A_height','B_height'])]:
    s('read',suffix,text,refs=refs,cue='brace')

def draw_point(key):
    lower=key.lower()
    s(lower+'-front','x',f'沿 X 轴向左量 {{{key}_x}} mm。','line',['O',key+'_x'],'brace',a='O',b=key+'_x')
    s(lower+'-front','z','从这里向上量 {'+key+'_z} mm。','line',[key+'_x',key+'_front'],'brace',a=key+'_x',b=key+'_front')
    s(lower+'-front','point','标出正面投影 '+lower+'′。','point',[key+'_front'],'highlight',p=key+'_front',name=lower+'′')
    s(lower+'-top','align','从 '+lower+'′ 向下，保持左右对正。','line',[key+'_front',key+'_x'],a=key+'_front',b=key+'_x')
    s(lower+'-top','depth','从 X 轴向下量 {'+key+'_y} mm。','line',[key+'_x',key+'_top'],'brace',a=key+'_x',b=key+'_top')
    s(lower+'-top','cross','与 Y_H 轴上的距离位置水平对齐。','line',[key+'_top_axis',key+'_top'],a=key+'_top_axis',b=key+'_top')
    s(lower+'-top','point','标出水平投影 '+lower+'。','point',[key+'_top'],'highlight',p=key+'_top',name=lower)
    s(lower+'-side','transfer','从 '+lower+' 水平送到 45°线。','line',[key+'_top',key+'_turn'],a=key+'_top',b=key+'_turn')
    s(lower+'-side','turn','从 45°交点转向上。','line',[key+'_turn',key+'_left'],a=key+'_turn',b=key+'_left')
    s(lower+'-side','height','从 '+lower+'′ 引出等高的水平线。','line',[key+'_front',key+'_left'],a=key+'_front',b=key+'_left')
    s(lower+'-side','point','两条线相交，标出 '+lower+'″。','point',[key+'_left'],'highlight',p=key+'_left',name=lower+'″')

draw_point('A')
s('b-distance','x','向左：{A_x}＋{dx}＝{B_x} mm。',refs=['O','B_x'],cue='brace')
s('b-distance','y','向后靠近 V：{A_y}－{dy}＝{B_y} mm。',refs=['A_top_axis','B_top_axis'],cue='brace')
s('b-distance','z','向上：{A_z}＋{dz}＝{B_z} mm。',refs=['O','B_height'],cue='brace')
draw_point('B')
for key in ['A','B']:
    n=key.lower()
    s('check',key+'-vertical',n+' 与 '+n+'′ 左右对正。',refs=[key+'_top',key+'_front'])
    s('check',key+'-height',n+'′ 与 '+n+'″ 高度相等。',refs=[key+'_front',key+'_left'])
    s('check',key+'-depth',n+' 与 '+n+'″ 前后距离相等。',refs=['O',key+'_top_axis','O',key+'_side_axis'],cue='equal')
s('check','complete','六个点构成完整参考作图。',refs=['A_front','A_top','A_left','B_front','B_top','B_left'],cue='highlight')
for g in config['solution']:
    g['beats']=[b for b in solution if b['id'].split(':')[0]==g['id']]

config['design_reference']='https://www.figma.com/design/adCrPAUZLtg0EjhtK6gGWZ'
path.write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'concept':len(concept),'solution':len(solution),'source':str(path)},ensure_ascii=False))
