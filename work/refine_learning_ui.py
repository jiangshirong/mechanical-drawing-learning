"""Apply the reviewed desktop UI changes without changing geometry or assets."""
import json
from pathlib import Path

APP = Path(__file__).resolve().parents[1] / '机械制图学习'
# One-time migration record. Refuse a second run before touching any files.
assert 'const UI = preload("res://ui_style.gd")' not in (APP / 'main.gd').read_text(encoding='utf-8'), 'UI migration already applied; edit the current sources directly.'

def edit(name, before, after):
    path = APP / name
    text = path.read_text(encoding='utf-8')
    assert before in text, (name, before[:80])
    path.write_text(text.replace(before, after, 1), encoding='utf-8')

path = APP / 'assets/knowledge_map.json'
graph = json.loads(path.read_text(encoding='utf-8'))
for node in graph['nodes']:
    if node['id'] in ('slope', 'base'): node['position'][1] = 594
    if node['id'] == 'bracket': node['position'][1] = 710
    if node['id'] == 'dimensions': node['position'] = [224, 50]
    if node['id'] == 'requirements': node['position'] = [224, 170]
for edge in graph['edges']:
    if edge['from'] == 'points' and edge['to'] == 'dimensions': edge.pop('route')
    if edge['from'] == 'requirements': edge['route'] = [[119,170],[16,170],[16,1288],[664,1288],[664,1266]]
    if edge['from'] == 'basic_solids' and edge['to'] == 'slope': edge['route'][-2:] = [[400,594],[405,594]]
    if edge['from'] == 'basic_solids' and edge['to'] == 'base': edge['route'][-1] = [816,548]
    if edge['from'] == 'bracket' and edge.get('route'): edge['route'][0][1] = edge['route'][1][1] = 710
path.write_text(json.dumps(graph, ensure_ascii=False, indent=2), encoding='utf-8')

edit('main.gd', 'const PanZoom = preload("res://pan_zoom.gd")', 'const PanZoom = preload("res://pan_zoom.gd")\nconst UI = preload("res://ui_style.gd")')
edit('main.gd', 'var source_mode := "question"', 'var source_mode := "question"\nvar source_key := ""\nvar source_views: Dictionary = {}')
edit('main.gd', 'var guide_copy: Label', 'var guide_copy: Label\nvar guide_reason: Label\nvar guide_detail: Label')
path = APP / 'main.gd'
text = path.read_text(encoding='utf-8')
start = text.index('\tvar t := Theme.new()')
end = text.index('\tcatalog = JSON.parse_string', start)
text = text[:start] + '\ttheme = UI.make_theme()\n' + text[end:]
path.write_text(text, encoding='utf-8')
edit('main.gd', 'func label(text: String, fs := 18)', 'func label(text: String, fs := UI.BODY)')
edit('main.gd', '\tguide_heading = label("",20)\n\tguide_panel.add_child(guide_heading)\n\tguide_copy = label("",18)\n\tguide_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART\n\tguide_copy.custom_minimum_size.y = 56\n\tguide_panel.add_child(guide_copy)', '''\tguide_panel.add_theme_constant_override("separation", 7)
\tguide_heading = label("", UI.CAPTION)
\tguide_heading.add_theme_color_override("font_color", UI.MUTED)
\tguide_panel.add_child(guide_heading)
\tguide_copy = label("", UI.CONCLUSION)
\tguide_reason = label("", UI.BODY)
\tguide_reason.add_theme_color_override("font_color", UI.EMPHASIS)
\tguide_detail = label("", UI.CAPTION)
\tguide_detail.add_theme_color_override("font_color", UI.MUTED)
\tfor line in [guide_copy, guide_reason, guide_detail]:
\t\tline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
\t\tguide_panel.add_child(line)''')
edit('main.gd', '\tnavigation.add_child(leave)\n\tguide_prev', '\tnavigation.add_child(leave)\n\tvar navigation_space := Control.new()\n\tnavigation_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL\n\tnavigation.add_child(navigation_space)\n\tguide_prev')
edit('main.gd', '\tsource_window.close_requested.connect(func(): source_window.hide())', '\tsource_window.close_requested.connect(hide_source)')
edit('main.gd', '\tsource_image.texture = load(path)\n\tsource_window.popup_centered()\n\tsource_view.reset_content(source_image.texture.get_size())', '''\tremember_source_view()
\tsource_key = str(data.id) + ":" + mode + ":" + path
\tsource_image.texture = load(path)
\tsource_window.popup_centered()
\tsource_view.reset_content(source_image.texture.get_size())
\tif source_views.has(source_key): source_view.restore_view_state(source_views[source_key])

func remember_source_view() -> void:
\tif not source_key.is_empty() and not source_view.needs_fit:
\t\tsource_views[source_key] = source_view.get_view_state()

func hide_source() -> void:
\tremember_source_view()
\tsource_window.hide()''')
# Other transitions also preserve source exploration rather than implicitly dropping it.
edit('main.gd', '\tsource_window.hide()\n\tvar focus', '\thide_source()\n\tvar focus')

edit('observer.gd', 'const Stroke = preload("res://stroke_3d.gd")', 'const Stroke = preload("res://stroke_3d.gd")\nconst UI = preload("res://ui_style.gd")')
edit('observer.gd', 'env.background_color = Color("101d29")', 'env.background_color = UI.BACKGROUND')
edit('observer.gd', '\tlabel.pixel_size = 0.0001', '\tlabel.pixel_size = 0.000065\n\tlabel.outline_size = 2\n\tlabel.outline_modulate = UI.BACKGROUND')
edit('observer.gd', '\tlabel.no_depth_test = false\n\tlabel.billboard', '\tlabel.no_depth_test = false\n\tlabel.outline_size = 0\n\tlabel.pixel_size = 0.00006\n\tlabel.billboard')
edit('observer.gd', 'g(f.points[0]) + Vector3(0.002, 0.003, 0)', 'g(f.points[0]) + Vector3(0.0018, 0.0022, 0)')

# Separate visible teaching roles; the original text remains an authoring fallback.
path = APP / '模型/section_guide.json'
guide = json.loads(path.read_text(encoding='utf-8'))
copy = [
 ('剖视图帮助我们看清内部孔和台阶。', '外壳遮住内部结构，普通主视图只能用虚线表达。', ''),
 ('假想的剖切平面通过两个孔的轴线。', '这样能同时看清两个孔和右侧台阶；箭头表示从前向后的观察方向。', '全剖不要求总从中间对称线切开。'),
 ('移走观察者与剖切面之间的部分，留下后面的半体。', '挡住内部的部分移开后，孔壁和台阶就露出来了。', '这是假想的表达方法，不是把零件实际加工成半个。'),
 ('普通材料切面画剖面线，孔洞不填。', '切到材料会形成切面；穿过孔洞时没有材料。', '露出的孔壁是孔的内表面，不等于材料切面。'),
 ('将剖开后剩余的部分沿主视方向投影，得到全剖视图。', '图中包含材料切面和后方可见轮廓，不只画切口。', '俯、左视图仍表示原完整零件。'),
 ('肋板纵向剖切时，按规定不画剖面线。', '原因：容易把肋板和底座、凸台看成一整块厚实材料。', '它有材料，也确实被切到了；留白不代表孔洞，用粗实线区分相邻部分。\n横向切断肋板时则要画剖面线。')
]
for step, (conclusion, reason, detail) in zip(guide['steps'], copy):
    step.update(conclusion=conclusion, reason=reason, detail=detail)
    step['text'] = '\n'.join(value for value in (conclusion, reason, detail) if value)
path.write_text(json.dumps(guide, ensure_ascii=False, indent=2), encoding='utf-8')
edit('section_guide.gd', '\tr.guide_copy.text = lesson.text', '''\tr.guide_copy.text = lesson.get("conclusion", lesson.text)
\tr.guide_reason.text = lesson.get("reason", "")
\tr.guide_detail.text = lesson.get("detail", "")
\tr.guide_reason.visible = not r.guide_reason.text.is_empty()
\tr.guide_detail.visible = not r.guide_detail.text.is_empty()''')
edit('section_guide.gd', 'func exit() -> void:', '''func lesson_text() -> String:
\treturn "\\n".join([r.guide_copy.text, r.guide_reason.text, r.guide_detail.text])

func exit() -> void:''')
edit('section_guide.gd', '\tr.source_window.hide()', '\tr.hide_source()')
path = APP / 'guide_check.gd'
text = path.read_text(encoding='utf-8').replace('r.guide_copy.text.contains(', 'r.guide.lesson_text().contains(')
path.write_text(text, encoding='utf-8')
print('UI source and guide authoring updated; geometry untouched.')
