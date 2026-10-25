"""Reorder point teaching around real construction, preserving model parameters."""
import json
from pathlib import Path

path = Path(__file__).resolve().parents[1] / '机械制图学习/模型/points_learning.json'
config = json.loads(path.read_text(encoding='utf-8'))

def beat(id, text, action, anchor, indicator='highlight', focus=None):
    return {'id': id, 'text': text, 'action': action, 'anchor': anchor,
            'indicators': [indicator], 'focus': focus or anchor}

def guide(id, text, key, dimension, from_ref, to_ref):
    return beat(id, text, {'type': 'line', 'id': key, 'a': from_ref, 'b': to_ref,
                          'dashed': True}, dimension, 'brace', [from_ref, to_ref])

def point(key, view, label):
    return beat(f'{key.lower()}-{view}:point', f'两条定位虚线相交，标出 {label}。',
                {'type': 'point', 'p': key+'_'+view, 'name': label}, [key+'_'+view])

def erase(key, side=False):
    prefix = key.lower() + ('-side' if side else '-top')
    targets = [key+'_transfer',key+'_turn_line',key+'_level'] if side else [key+'_height_guide',key+'_x_guide',key+'_depth_guide']
    return beat(prefix+':erase', '用橡皮擦去临时定位虚线，保留已标出的投影点。',
                {'type':'erase','targets':targets}, [key+'_front',key+'_top',key+'_left'] if side else [key+'_front',key+'_top'])

def side(key, label):
    prefix=key.lower()+'-side'
    items=[]
    for suffix,text,a,b,gid in [
        ('transfer',f'从 {key.lower()} 画水平虚线，到 45° 转移线。',key+'_top',key+'_turn',key+'_transfer'),
        ('turn','由这个交点向上画竖直虚线，把前后距离转到侧面。',key+'_turn',key+'_side_upper',key+'_turn_line'),
        ('height',f'从 {key.lower()}′ 向右画等高虚线。',key+'_front',key+'_level_end',key+'_level')]:
        items.append(beat(prefix+':'+suffix,text,{'type':'line','id':gid,'a':a,'b':b,'dashed':True},[a,b]))
    items.append(beat(prefix+':point',f'竖直虚线与等高虚线相交，标出 {label}。',{'type':'point','p':key+'_left','name':label},[key+'_left']))
    items.append(erase(key,True))
    return items

groups={g['id']:g for g in config['solution']}
groups['read']['beats']=[beat('read:question',config['statement'],{'type':'focus'},['O'])]
groups['a-front']['beats']=[
    guide('a-front:z','A 距 H 面 {A_z} mm：a′ 可能在 X 轴上方 {A_z} mm 的水平虚线上。','A_height_guide',['O','A_height'],'A_height_start','A_height'),
    guide('a-front:x','A 距 W 面 {A_x} mm：在 X 轴左方 {A_x} mm 画竖直定位虚线。','A_x_guide',['O','A_x'],'A_x_upper','A_x_lower'),
    point('A','front','a′')]
groups['a-top']['beats']=[
    guide('a-top:depth','A 距 V 面 {A_y} mm：在 X 轴下方 {A_y} mm 画水平虚线。','A_depth_guide',['O','A_top_axis'],'A_depth_start','A_top_axis'),
    point('A','top','a'),erase('A')]
groups['a-side']['beats']=side('A','a″')
groups['b-distance']['title']='由 A 定位 B 的左右'
groups['b-distance']['beats']=[guide('b-distance:x','B 在 A 左方 {dx} mm：{A_x}＋{dx}＝{B_x} mm，画竖直定位虚线。','B_x_guide',['A_x','B_x'],'B_x_upper','B_x_lower')]
groups['b-front']['beats']=[
    guide('b-front:z','B 在 A 上方 {dz} mm：{A_z}＋{dz}＝{B_z} mm，画等高的水平虚线。','B_height_guide',['A_height','B_height'],'B_height_start','B_height'),
    point('B','front','b′')]
groups['b-top']['beats']=[
    guide('b-top:depth','B 在 A 后方 {dy} mm，更靠近 V 面：{A_y}－{dy}＝{B_y} mm，画水平定位虚线。','B_depth_guide',['A_top_axis','B_top_axis'],'B_depth_start','B_top_axis'),
    point('B','top','b'),erase('B')]
groups['b-side']['beats']=side('B','b″')

for mode in ['concept','solution']:
    for group in config[mode]:
        for b in group['beats']:
            if b['indicators']==['arrow'] and b['id'] not in ['alignment:transfer','alignment:turn']:
                b['indicators']=['highlight']

for g in config['solution']:
    g['text']=''.join(b['text'] for b in g['beats'])
config['construction_note']='先完成A的三个投影，再逐项换算并绘制B；定位虚线为临时作图线，橡皮擦动画只清理教学副本。'
path.write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

# Apply the latest user copy policy last.
import runpy
runpy.run_path(str(Path(__file__).resolve().parent / "refine_points_copy.py"))
