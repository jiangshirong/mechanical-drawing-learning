"""Apply the requested concise teaching copy without changing construction actions."""
import json
from pathlib import Path

path = Path(__file__).resolve().parents[1] / '机械制图学习/模型/points_learning.json'
config = json.loads(path.read_text(encoding='utf-8'))
config['solution'] = [group for group in config['solution'] if group['id'] != 'read']
copy = {
    'a-front:z': 'A 距 H 面 {A_z} mm。',
    'a-front:x': 'A 距 W 面 {A_x} mm。',
    'a-top:depth': 'A 距 V 面 {A_y} mm。',
    'b-distance:x': 'B 在 A 左方 {dx} mm：{A_x}＋{dx}＝{B_x} mm。',
    'b-front:z': 'B 在 A 上方 {dz} mm：{A_z}＋{dz}＝{B_z} mm。',
    'b-top:depth': 'B 在 A 后方 {dy} mm，距 V 减小：{A_y}－{dy}＝{B_y} mm。',
    'check:complete': 'A、B 的三面投影完成。',
}
for group in config['solution']:
    for beat in group['beats']:
        id = beat['id']
        if id in copy:
            beat['text'] = copy[id]
        elif beat['action']['type'] == 'erase':
            beat['text'] = '擦去临时虚线。'
        elif beat['action']['type'] == 'point':
            beat['text'] = '标出' + beat['action']['name'] + '。'
        elif id.endswith(':transfer'):
            beat['text'] = '水平引到 45° 线。'
        elif id.endswith(':turn'):
            beat['text'] = '从交点向上引线。'
        elif id.endswith(':height'):
            beat['text'] = '从 ' + ('a′' if id.startswith('a-') else 'b′') + ' 引等高线。'
    group['text'] = ''.join(beat['text'] for beat in group['beats'])
config['presentation']['busy_navigation'] = 'complete_current_then_wait'
config['presentation']['chapter_navigation'] = 'restore_first_beat_before_action'
config['construction_note'] = '教学从A的第一项条件开始，完整题干保留在悬浮题按钮中。先完成A，再画B；临时定位线顺次擦除。条件和必要算式配合真实位置高亮，不重复描述图中已显示的位置。'
path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

# Apply the latest user copy policy last.
import runpy
runpy.run_path(str(Path(__file__).resolve().parent / "refine_points_copy.py"))
